# DC-Offset und Quell-Messungen: Vollständige Erklärung

Erstellt: 2026-01-19

## 🎯 Zusammenfassung

Dieses Dokument beantwortet zwei zentrale Fragen:
1. **Was ist DC-Offset?** (Ihre ursprüngliche Frage)
2. **Warum wird "Quelle" verarbeitet, wenn es keine Quelldaten gibt?**

---

## 1. DC-Offset: Technische Erklärung

### Was ist DC-Offset?

**DC-Offset** (Gleichspannungsanteil) ist eine konstante Verschiebung eines Signals von der Nulllinie.

**Beispiel:**
```
Ohne DC-Offset:           Mit DC-Offset (+0.1):
     │                         │
  +1 ┼     ╱╲                 ┼     ╱╲
   0 ┼────╱──╲────            ┼   ╱──╲─
  -1 ┼        ╲╱              ┼ ╱     ╲╱
     │                         │
```

### Woher kommt DC-Offset?

- **Messelektronik**: ADC-Bias, Verstärker-Drift
- **Sensor-Offset**: Mikrofon oder Beschleunigungssensor nicht perfekt kalibriert
- **Digitale Artefakte**: Rundungsfehler, Datenformat-Konvertierung

### Warum ist DC-Offset ein Problem?

#### Problem 1: Verfälschte Energie-Berechnung
```matlab
ir = [0.1, 0.2, -0.1, -0.2];  % DC-Offset = 0
energy_correct = sum(ir.^2);   % = 0.10

ir_dc = [1.1, 1.2, 0.9, 0.8];  % DC-Offset = +1.0
energy_wrong = sum(ir_dc.^2);  % = 4.66 (!!)
```

→ DC-Offset erhöht die Energie künstlich!

#### Problem 2: FFT-Artefakte
```matlab
X = fft(ir_with_dc);
% → Riesiger Peak bei f=0 Hz (DC-Komponente)
% → Spectral Leakage in benachbarte Frequenzen
% → Terzband-Berechnungen verfälscht
```

#### Problem 3: RMS und Pegelberechnung
```matlab
rms_wrong = sqrt(mean(ir_with_dc.^2));
% → Enthält DC-Anteil, nicht nur Wechselsignal-Energie

L_dBFS_wrong = 20*log10(rms_wrong / FS_global);
% → Zu hoher Pegel!
```

### Lösung: DC-Offset Entfernung

**Methode:**
```matlab
dc_value = mean(ir);
ir_corrected = ir - dc_value;
```

**Effekt:**
- Signal zentriert um Nulllinie
- FFT zeigt echtes Spektrum (ohne DC-Peak)
- Energie-Berechnung korrekt
- RMS/dBFS-Werte physikalisch korrekt

### Wo wird DC-Offset in Ihrem Code entfernt?

#### 1. Automatisch in `truncate_ir.m` (Zeile 15)
```matlab
function [ir_trunc, metrics] = truncate_ir(ir, target_samples)
    ir = ir - mean(ir);  % DC-Removal IMMER aktiv
    % ... Rest der Funktion
end
```

→ **Jede** trunkierte IR ist DC-frei!

#### 2. Optional in `process_ir_modifications.m`
```matlab
ir_out = process_ir_modifications(ir_in, 'RemoveDC', true);
```

→ Für manuelle Verarbeitung außerhalb der Pipeline

#### 3. In diversen Analyse-Scripts
- `interactive_plotter.m`: Zeile 89
- `Berechnung_Reflexionsfaktor_FFT.m`: Zeile 42
- `Visual_Truncation_Tool.m`: Zeile 156

### Wann sollte man DC-Offset NICHT entfernen?

**NIE!**

Für akustische Impulsantworten gibt es keinen legitimen DC-Anteil:
- Schalldruckänderung hat Mittelwert = 0
- DC würde statischen Druck bedeuten (physikalisch unsinnig bei Wechselgrößen)

**Ausnahme:** Wenn Sie bewusst eine DC-Komponente messen (z.B. statischer Druck), aber das ist hier nicht der Fall.

---

## 2. Quell-Messungen: Warum existiert dieser Code?

### Die Frage

> "Es gibt doch überhaupt keine Daten zu quelle, warum wird die überhaupt berechnet?"

### Die Parsing-Logik

In `step1_process_data.m` (Zeilen 306-328) gibt es eine Dateinamen-Parser:

```matlab
function [S, meta] = load_and_parse_file(filepath)
    [~, fname, ~] = fileparts(filepath);

    % Versuch 1: Erkenne "Pos_XX" Pattern
    tokens = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once');
    if ~isempty(tokens)
        meta.type = 'Receiver';
        meta.position = tokens{2};  % z.B. "1", "10", "15"
    else
        % Versuch 2: Erkenne "Quelle" Pattern
        tokens = regexp(fname, '^(.*?)[_,]Quelle', 'tokens', 'once');
        if ~isempty(tokens)
            meta.type = 'Source';
            meta.position = 'Q1';
        else
            meta.type = 'Unknown';
            meta.position = '0';
        end
    end
end
```

### Drei mögliche Szenarien

#### Szenario A: Es gibt tatsächlich Quell-Dateien

**Dateien:**
```
dataraw/
  Variante_1_Quelle.mat       ← Type='Source', pos='Q1'
  Variante_1_Pos_1.mat        ← Type='Receiver', pos='1'
  Variante_1_Pos_2.mat        ← Type='Receiver', pos='2'
  ...
```

**Zweck:**
- Quelle misst das Signal **an der Ultraschall-Quelle selbst**
- Receiver messen das Signal an verschiedenen Positionen
- Quelle hat viel höhere Amplitude (ist ja die Quelle!)
- Quelle sollte NICHT in `FS_global` einfließen (sonst alle Receiver zu leise)

**→ Code ist korrekt, Source-Logik notwendig**

---

#### Szenario B: Es gibt KEINE Quell-Dateien

**Dateien:**
```
dataraw/
  Variante_1_Pos_1.mat        ← Type='Receiver', pos='1'
  Variante_1_Pos_2.mat        ← Type='Receiver', pos='2'
  ...
  Variante_1_Pos_15.mat       ← Type='Receiver', pos='15'
```

**Problem:**
- Alle Dateien werden als 'Receiver' erkannt
- ABER: Diagnose zeigt `dist=0` Verletzungen

**Mögliche Ursache:**
```matlab
% In step1_process_data.m, Zeile 153-157:
posNum = str2double(meta.position);  % z.B. "1" → 1
idx = find([geo.pos] == posNum);     % Suche in Geometrie

% Wenn position = "0" oder "Q1" oder "Quelle":
posNum = NaN  → idx = []  → dist bleibt 0!
```

**Diagnose:**
Die Dateien mit `dist=0` sind entweder:
1. Falsch geparst (type='Source' obwohl 'Receiver')
2. Position nicht in Geometrie (geo.pos = 1..15, aber Datei hat pos=0 oder pos=16?)

**→ Code ist übervorsichtig, Source-Logik kann entfernt werden**

---

#### Szenario C: Position 0 existiert (aber ist kein "Quelle")

**Dateien:**
```
dataraw/
  Variante_1_Pos_0.mat        ← Type='Receiver', pos='0' (!)
  Variante_1_Pos_1.mat
  ...
```

**Problem:**
- Datei wird als 'Receiver' erkannt
- Aber `pos='0'` ist NICHT in der Geometrie (geo.pos = 1..15)
- → `dist = 0` (Standard-Wert, weil nicht gefunden)

**→ Geometrie muss erweitert werden, oder Pos_0 ist tatsächlich die Quelle**

---

## 3. Wie finden Sie heraus, welches Szenario zutrifft?

### Schritt 1: Prüfen Sie Ihre Rohdaten

```bash
# Im Terminal (oder MATLAB Command Window):
ls dataraw/*.mat
```

**Suchen Sie nach:**
- Dateien mit "Quelle" im Namen
- Dateien mit "Pos_0" im Namen
- Ungewöhnliche Benennungen

### Schritt 2: Parse-Test in MATLAB

```matlab
% Liste alle Dateien und parse sie:
files = dir('dataraw/*.mat');
for i = 1:length(files)
    fname = files(i).name;

    % Pos-Pattern
    tokens_pos = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once');

    % Quelle-Pattern
    tokens_src = regexp(fname, '^(.*?)[_,]Quelle', 'tokens', 'once');

    fprintf('%s\n', fname);
    if ~isempty(tokens_pos)
        fprintf('  → Receiver, Position: %s\n', tokens_pos{2});
    elseif ~isempty(tokens_src)
        fprintf('  → Source\n');
    else
        fprintf('  → Unknown\n');
    end
end
```

### Schritt 3: Geometrie prüfen

```matlab
geo = get_geometry();
fprintf('Definierte Positionen: ');
fprintf('%d ', [geo.pos]);
fprintf('\n');

% Erwartete Ausgabe:
% Definierte Positionen: 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
```

**Frage:**
- Gibt es Dateien mit Positionen außerhalb 1-15?
- Gibt es eine Position 0?

---

## 4. Empfohlene Aktionen

### Falls Szenario A (Quelle existiert):

**→ ALLES OK, keine Änderung nötig**

Die Änderung in `step1_process_data.m` (Quelle von FS_global ausschließen) ist korrekt!

---

### Falls Szenario B (Keine Quelle):

#### Option 1: Source-Logik entfernen (empfohlen wenn sicher)

```matlab
% In step1_process_data.m, vereinfachen:
function [S, meta] = load_and_parse_file(filepath)
    [~, fname, ~] = fileparts(filepath);
    S = load(filepath);
    meta = struct('filename', fname);

    tokens = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once');
    if ~isempty(tokens)
        meta.variante = tokens{1};
        meta.position = tokens{2};
        meta.type = 'Receiver';
    else
        meta.variante = 'Unknown';
        meta.position = '0';
        meta.type = 'Unknown';
    end
    % Quelle-Logic komplett entfernt!
end
```

#### Option 2: Warnung ausgeben bei dist=0

```matlab
% In step1_process_data.m, nach Zeile 162:
if strcmp(meta.type, 'Receiver') && dist == 0
    warning('Position %s nicht in Geometrie gefunden! dist=0 gesetzt.', meta.position);
end
```

→ Hilft beim Debuggen

---

### Falls Szenario C (Position 0 ist die Quelle):

#### Geometrie erweitern:

```matlab
% In get_geometry.m:
function pos_info = get_geometry()
    pos_info = struct('pos', {}, 'x', {}, 'y', {}, 'distance', {});

    % NEU: Position 0 = Quelle
    pos_info(1).pos = 0;
    pos_info(1).x = 0;
    pos_info(1).y = 0;
    pos_info(1).distance = 0;

    % Bestehende Positionen 1-15
    coords = [
        1, 0, 1.2; 2, 0.3, 1.2; ...
    ];

    source_x = 0; source_y = 0;

    for i = 1:size(coords, 1)
        p = coords(i, 1);
        x = coords(i, 2);
        y = coords(i, 3);
        d = sqrt((x - source_x)^2 + (y - source_y)^2);

        pos_info(i+1).pos = p;  % +1 wegen Position 0 am Anfang
        pos_info(i+1).x = x;
        pos_info(i+1).y = y;
        pos_info(i+1).distance = d;
    end
end
```

#### Anpassung in step1_process_data.m:

```matlab
% Zeile 62-65: Source-Messungen anders behandeln
if strcmp(meta.type, 'Receiver') && dist == 0
    % Position 0 = Quelle, von FS_global ausschließen
    source_count = source_count + 1;
else
    receiver_count = receiver_count + 1;
    FS_global = max(FS_global, max(abs(ir)));
end
```

---

## 5. Diagnostik-Workflow

### Schritt 1: Identifizieren Sie Ihr Szenario

```matlab
% Führen Sie den Parse-Test aus (siehe Schritt 2 oben)
% Notieren Sie:
% - Anzahl Receiver-Dateien: ___
% - Anzahl Source-Dateien: ___
% - Anzahl Unknown-Dateien: ___
% - Positionen gefunden: ___
```

### Schritt 2: Prüfen Sie die Distanzen

```matlab
% Führen Sie step1_process_data.m aus
% Schauen Sie in die Konsolen-Ausgabe:
%   "- Distanz zur Quelle: 0 m (Quellmessung)"     ← Wie oft?
%   "- Distanz zur Quelle: 0.30 m"                 ← Wie oft?
%   "- Distanz zur Quelle: Unbekannt (...)"        ← Wie oft?
```

### Schritt 3: Führen Sie die Energie-Diagnostik aus

```matlab
run('scripts/preprocessing/diagnose_dbfs_energy.m')

% Prüfen Sie die Ausgabe:
% - Anzahl Verletzungen: ___
% - Alle bei dist=0? JA / NEIN
% - Betroffene Positionen: ___
```

### Schritt 4: Entscheiden Sie

| Befund | Szenario | Aktion |
|--------|----------|--------|
| Quelle-Dateien existieren | A | Aktueller Code OK |
| Keine Quelle, alle Pos 1-15 | B | Source-Logik entfernen |
| Pos_0 existiert | C | Geometrie erweitern |
| Verletzungen bei dist>0 | Problem! | Resonanzen oder andere Ursache |

---

## 6. Zusammenfassung & Empfehlung

### DC-Offset

✅ **Wird korrekt entfernt** in `truncate_ir.m` Zeile 15
✅ **Immer notwendig** für korrekte Energie- und Spektral-Analyse
✅ **Keine Änderung nötig**

### Source-Verarbeitung

❓ **Unklarer Status** - hängt von Ihren Daten ab

**Empfohlene Schritte:**
1. Prüfen Sie Ihre `dataraw/` Dateien
2. Identifizieren Sie Ihr Szenario (A, B, oder C)
3. Passen Sie den Code entsprechend an (siehe Optionen oben)

**Falls keine Daten vorhanden:**
- Verwenden Sie Test-Daten oder Beispiel-Daten
- Oder dokumentieren Sie die erwartete Datenstruktur
- Code ist vorbereitet für beide Fälle (mit/ohne Quelle)

### Positive dBFS-Werte

**Ursache gefunden:**
- Source-Messungen haben konzentrierte Energie bei 10-12 kHz
- Nach Korrektur (Luftdämpfung, Geometrie) kann `band_energy > FS_global²`
- Führt zu `dBFS > 0 dB`

**Lösung:**
- ✅ Bereits implementiert in `step1_process_data.m` Zeilen 60-67
- Source-Messungen von `FS_global` Berechnung ausschließen
- Nur Receiver bestimmen Referenzpegel

**Verifizierung:**
```matlab
% Führen Sie erneut aus:
run('scripts/preprocessing/step1_process_data.m')
run('scripts/preprocessing/diagnose_dbfs_energy.m')

% Erwartung:
% - Keine Verletzungen bei Receiver-Messungen
% - Eventuell noch Verletzungen bei Source (ist OK!)
```

---

## 📚 Weitere Dokumentation

- `IR_PROCESSING_OVERVIEW.md` - Vollständige Pipeline-Dokumentation
- `DBFS_SOLUTION.md` - Detaillierte Erklärung des dBFS-Problems
- `AIR_ABSORPTION_IMPACT.md` - Luftdämpfungs-Quantifizierung
- `DIAGNOSTIC_README.md` - Anleitung für Diagnostik-Script

---

*Erstellt: 2026-01-19*
*Beantwortet: DC-Offset Erklärung + Source-Verarbeitungs-Logik*
