# Szenario B: Implementierung für Receiver-Only Setup

Erstellt: 2026-01-19

## Situation

**Bestätigt**: Es gibt **keine Quell-Dateien** in diesem Projekt.
- Alle Messungen sind Receiver-Positionen (Pos_1 bis Pos_15)
- Keine Dateien mit "Quelle" im Namen
- Geometrie definiert nur Positionen 1-15

→ **Szenario B** aus `DC_OFFSET_AND_SOURCE_EXPLAINED.md`

---

## ✅ Implementierte Änderungen

### 1. Phase 1: FS_global Berechnung vereinfacht

**Vorher:**
```matlab
FS_global = 0;
source_count = 0;
receiver_count = 0;

for i = 1:length(files)
    if strcmp(meta.type, 'Source')
        source_count = source_count + 1;
        % Quelle NICHT in FS_global einbeziehen
    else
        receiver_count = receiver_count + 1;
        FS_global = max(FS_global, max(abs(ir)));
    end
end
```

**Nachher:**
```matlab
FS_global = 0;
valid_count = 0;
skipped_files = 0;

for i = 1:length(files)
    if ~isempty(ir)
        % Alle Messungen sind Receiver (Szenario B: Keine Quelle)
        valid_count = valid_count + 1;
        FS_global = max(FS_global, max(abs(ir)));
    else
        skipped_files = skipped_files + 1;
    end
end
```

**Vorteil:**
- Einfacher, klarer Code
- Keine unnötigen Unterscheidungen zwischen Source/Receiver
- Alle Messungen fließen gleichberechtigt in FS_global ein

---

### 2. Phase 3: Distanzberechnung mit Warnungen

**Vorher:**
```matlab
dist = 0;
if strcmp(meta.type, 'Receiver')
    posNum = str2double(meta.position);
    if ~isnan(posNum)
        idx = find([geo.pos] == posNum);
        if ~isempty(idx)
            dist = geo(idx).distance;
        else
            fprintf('  - Distanz zur Quelle: Unbekannt (Position nicht in Geometrie)\n');
        end
    end
else
    fprintf('  - Distanz zur Quelle: 0 m (Quellmessung)\n');
end
```

**Nachher:**
```matlab
dist = 0;
posNum = str2double(meta.position);
if ~isnan(posNum)
    idx = find([geo.pos] == posNum);
    if ~isempty(idx)
        dist = geo(idx).distance;
        fprintf('  - Distanz zur Quelle: %.2f m\n', dist);
    else
        warning('Position %d nicht in Geometrie gefunden! Verfügbare Positionen: %s. dist=0 gesetzt (keine Luftdämpfung).', ...
            posNum, mat2str([geo.pos]));
        fprintf('  - Distanz zur Quelle: 0 m [!] Position nicht in Geometrie\n');
    end
else
    warning('Position "%s" ist nicht numerisch! dist=0 gesetzt.', meta.position);
    fprintf('  - Distanz zur Quelle: 0 m [!] Position nicht numerisch\n');
end
```

**Vorteil:**
- **Explizite Warnungen** wenn Position nicht gefunden wird
- Zeigt verfügbare Positionen in Fehlermeldung
- Hilft beim Debuggen von `dist=0` Problemen
- Erkennt nicht-numerische Positionen (z.B. "Q1", "Unknown")

---

### 3. load_and_parse_file: Source-Erkennung entfernt

**Vorher:**
```matlab
tokens = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once');
if ~isempty(tokens)
    meta.type = 'Receiver';
else
    tokens = regexp(fname, '^(.*?)[_,]Quelle', 'tokens', 'once');
    if ~isempty(tokens)
        meta.type = 'Source';
        meta.position = 'Q1';
    else
        meta.type = 'Unknown';
        meta.position = '0';
    end
end
```

**Nachher:**
```matlab
% Erwartetes Format: Variante_X_Pos_Y.mat
tokens = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once', 'ignorecase');
if ~isempty(tokens)
    meta.variante = tokens{1};
    meta.position = tokens{2};  % z.B. "1", "10", "15"
    meta.type = 'Receiver';
else
    meta.variante = 'Unknown';
    meta.position = '0';
    meta.type = 'Unknown';
    warning('Dateiname "%s" passt nicht zum erwarteten Format (Variante_X_Pos_Y.mat)', fname);
end
```

**Vorteil:**
- Keine "Quelle"-Erkennung mehr (wird nicht benötigt)
- Klarere Fehlermeldung bei falschem Dateinamen-Format
- Einfacherer Code-Flow

---

## 🔍 Was wird jetzt erkannt?

### Erwartete Warnungen

Wenn Sie `step1_process_data.m` ausführen, sollten Sie jetzt **klare Warnungen** sehen, falls:

#### Warnung 1: Position nicht in Geometrie
```
Warning: Position 16 nicht in Geometrie gefunden! Verfügbare Positionen: [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15].
dist=0 gesetzt (keine Luftdämpfung).
```

**Bedeutung:**
- Datei hat z.B. "Pos_16" im Namen
- Aber Geometrie definiert nur Positionen 1-15
- → `dist=0` wird gesetzt (KEINE Luftdämpfungs-Korrektur!)

**Lösung:**
- Option A: Datei umbenennen (z.B. Pos_16 → Pos_15)
- Option B: Geometrie erweitern (`get_geometry.m`)
- Option C: Datei ist tatsächlich die Quelle (siehe Szenario C)

---

#### Warnung 2: Position nicht numerisch
```
Warning: Position "Q1" ist nicht numerisch! dist=0 gesetzt.
```

**Bedeutung:**
- Dateinamen-Parsing hat einen nicht-numerischen Wert extrahiert
- Beispiel: "Variante_1_Pos_Q1.mat" → position = "Q1"
- `str2double("Q1")` → `NaN`

**Lösung:**
- Datei prüfen und ggf. umbenennen
- Oder ist das tatsächlich eine Quell-Datei? (→ Szenario A oder C)

---

#### Warnung 3: Dateiname passt nicht zum Format
```
Warning: Dateiname "test.mat" passt nicht zum erwarteten Format (Variante_X_Pos_Y.mat)
```

**Bedeutung:**
- Datei hat nicht das erwartete Format "Variante_X_Pos_Y.mat"
- Wird als 'Unknown' markiert, position='0'

**Lösung:**
- Datei umbenennen oder aus `dataraw/` entfernen
- Oder Parsing-Logik anpassen falls anders benannt

---

## 🧪 Nächster Test: Diagnostik ausführen

### Schritt 1: Führen Sie step1_process_data.m aus

```matlab
run('scripts/preprocessing/step1_process_data.m')
```

**Achten Sie auf:**
- Konsolen-Ausgabe: "Berechnet aus: X Messungen"
- ALLE Dateien sollten Receiver sein
- Warnungen für Positionen außerhalb 1-15?

---

### Schritt 2: Führen Sie die Diagnostik aus

```matlab
run('scripts/preprocessing/diagnose_dbfs_energy.m')
```

**Erwartung für Szenario B:**

#### Falls KEINE Warnungen in Schritt 1:
→ **KEINE Verletzungen** sollten gefunden werden
→ Problem gelöst! ✅

#### Falls Warnungen "Position X nicht in Geometrie":
→ Verletzungen bei **genau diesen Positionen** mit `dist=0`
→ **Ursache gefunden!** Die Position ist nicht in der Geometrie

#### Falls Verletzungen TROTZ korrekter Positionen:
→ Anderes Problem (z.B. Resonanzen, Messfehler)
→ Weitere Analyse nötig

---

## 📊 Beispiel: Was könnte passiert sein?

### Hypothese: Position 0 existierte

**Mögliches Szenario:**
- Früher gab es Dateien: `Variante_1_Pos_0.mat`, `Variante_2_Pos_0.mat`, ...
- Diese wurden als 'Receiver' geparst (Position = "0")
- Aber Position 0 ist NICHT in der Geometrie (nur 1-15)
- → `idx = []` → `dist = 0` (keine Korrektur)
- → Keine Luftdämpfung angewendet
- → `band_energy` höher als erwartet → positive dBFS

**Ohne Warnungen war das unsichtbar!**

Jetzt zeigt der Code:
```
Warning: Position 0 nicht in Geometrie gefunden! Verfügbare Positionen: [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15].
dist=0 gesetzt (keine Luftdämpfung).
```

→ **Sofort erkennbar** wo das Problem ist!

---

## 🎯 Zusammenfassung: Szenario B Lösung

### Was wurde geändert?

1. ✅ **Source-Logik entfernt** aus FS_global-Berechnung
2. ✅ **Vereinfachte Distanzberechnung** (alle sind Receiver)
3. ✅ **Explizite Warnungen** bei `dist=0` Problemen
4. ✅ **load_and_parse_file vereinfacht** (keine Quelle-Erkennung)

### Was ist jetzt besser?

- 🔍 **Debugging**: Warnungen zeigen sofort wo `dist=0` herkommt
- 📝 **Klarheit**: Code spiegelt tatsächliche Datenstruktur (nur Receiver)
- 🐛 **Fehlererkennung**: Positionen außerhalb 1-15 werden erkannt
- ⚡ **Effizienz**: Weniger unnötige if-else Verzweigungen

### Was müssen Sie tun?

1. **Führen Sie step1_process_data.m aus**
   - Prüfen Sie die Konsolen-Ausgabe
   - Notieren Sie alle Warnungen

2. **Führen Sie diagnose_dbfs_energy.m aus**
   - Prüfen Sie ob noch Verletzungen existieren
   - Falls ja: Vergleichen Sie mit den Warnungen aus Schritt 1

3. **Beheben Sie erkannte Probleme**
   - Positionen umbenennen (falls falsch benannt)
   - Oder Geometrie erweitern (falls Position legitim)
   - Oder Dateien entfernen (falls Testdaten)

---

## 🔗 Weitere Dokumentation

- `DC_OFFSET_AND_SOURCE_EXPLAINED.md` - Vollständige Erklärung aller Szenarien
- `DBFS_SOLUTION.md` - Ursprüngliche Analyse des dBFS-Problems
- `IR_PROCESSING_OVERVIEW.md` - Pipeline-Dokumentation
- `DIAGNOSTIC_README.md` - Anleitung für diagnose_dbfs_energy.m

---

*Implementiert: 2026-01-19*
*Szenario B: Keine Quell-Dateien, nur Receiver-Messungen*
