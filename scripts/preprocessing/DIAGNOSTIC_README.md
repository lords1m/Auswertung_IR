# Diagnostik: Positive dBFS-Werte - Anleitung

## 🎯 Zweck

Das Script `diagnose_dbfs_energy.m` findet die **exakte Ursache** für positive dBFS-Werte durch reine Energie-Analyse (ohne dB-Umwandlung).

## 📋 Was das Script macht

### Phase 1: FS_global Bestimmung
- Lädt alle Rohdaten aus `dataraw/`
- Findet `FS_global = max(|ir|)` über alle Dateien
- Zeigt, welche Datei `FS_global` bestimmt
- Berechnet `FS_global²` (Referenz-Energie)

### Phase 2: Verletzungs-Suche
- Für jede Datei:
  1. Extract IR
  2. Truncate (exakt wie in step1_process_data.m)
  3. FFT + Luftdämpfungskorrektur
  4. Berechne **Energie** in jedem Terzband: `band_energy = sum(|X|²/N)`
  5. **Prüfe**: Ist `band_energy > FS_global²`?
  6. Falls JA: Speichere Verletzung mit Details

### Phase 3: Zusammenfassung
- Anzahl Verletzungen
- Statistik: Welche Frequenzen? Welche Varianten?
- Maximale Verletzung finden
- Muster erkennen

### Phase 4: Detaillierte Analyse
- Nimmt eine Beispiel-Verletzung
- Zeigt detaillierte Energie-Verteilung
- Analysiert: Wo kommt die Energie her?
- Top 5 FFT-Bins im betroffenen Band

## 🚀 Ausführung

```matlab
cd /path/to/Auswertung_IR
run('scripts/preprocessing/diagnose_dbfs_energy.m')
```

## 📊 Erwartete Ausgabe

### Fall A: Keine Verletzungen

```
=== ZUSAMMENFASSUNG ===

✓ KEINE Verletzungen gefunden!
  Alle band_energy ≤ FS_global²
  Es sollten KEINE positiven dBFS auftreten.
```

**Bedeutung:** Entweder:
- Es gibt wirklich keine positiven dBFS (false alarm)
- Problem liegt woanders (z.B. bei der Anzeige/Visualisierung)

---

### Fall B: Verletzungen gefunden

```
=== ZUSAMMENFASSUNG ===

⚠️  15 VERLETZUNGEN gefunden!

Verletzungen pro Frequenzband:
Frequenz     | Anzahl
-------------------------
40.0 kHz     | 3
50.0 kHz     | 7
63.0 kHz     | 5

--- Maximale Verletzung ---
Datei:     Variante_3_Pos12.mat
Variante:  Variante_3
Position:  12
Distanz:   1.73 m
Frequenz:  50.0 kHz
band_energy / FS_global² = 1.2458
→ dBFS = +0.95 dB

--- Analyse der Muster ---
Betroffene Varianten: Variante_2, Variante_3
Distanz-Bereich: 0.60 - 2.00 m (Mittel: 1.35 m)
Alle Dateien betroffen? NEIN
```

**Bedeutung:**
- **Wo:** Hohe Frequenzen (40-63 kHz)
- **Wer:** Spezifische Varianten/Positionen
- **Wie viel:** Bis zu +0.95 dB über FS_global

---

## 🔍 Interpretation der Ergebnisse

### Wenn Verletzungen bei hohen Frequenzen (40-63 kHz):

**Mögliche Ursachen:**

#### 1. **Resonanzen im Raum**
Bei bestimmten Frequenzen kann der Raum resonieren:
- Stehende Wellen zwischen Wänden
- Verstärkung bei spezifischen Frequenzen
- Hochfrequente Komponenten werden verstärkt

**Prüfen:**
```matlab
% Sind Verletzungen bei bestimmten Positionen gehäuft?
% → Geometrische Resonanzen (z.B. Ecken, bestimmte Abstände)
```

#### 2. **Spektrale Konzentration**
Signal hat sehr schmalbandige, hochenergetische Komponente:
- Im Zeitbereich: `max(|ir|)` ist durch niederfrequente Komponente bestimmt
- Im Frequenzbereich: Schmales Band bei hoher Frequenz hat viel Energie

**Beispiel:**
```
Zeitbereich: max = 100 (bei 10 kHz Komponente)
FFT bei 50 kHz: Schmales, sehr starkes Band
→ band_energy_50kHz > 100² trotz max_time = 100
```

#### 3. **FFT-Artefakte / Leckage**
- Fensterung kann Energie verschieben
- FFT-Leakage in benachbarte Bins
- Energie wird in bestimmten Bändern konzentriert

#### 4. **Messfehler / Clipping**
- Rohdaten bereits geclippt?
- Verstärkung in Messelektronik frequenzabhängig?
- Kalibrierung nicht korrekt?

### Wenn Verletzungen über alle Frequenzen:

**Mögliche Ursachen:**

#### 1. **Falsche FS_global Berechnung**
- Wird FS_global aus anderen Daten berechnet als genutzt?
- Normalisierung vor FS_global?
- Unterschiedliche IR-Versionen?

#### 2. **Andere Signal-Verstärkung**
- Geometrische Korrektur (1/r)?
- Zusätzliche Filter/Entzerrung?
- Kalibrierungs-Faktoren?

## 📈 Nächste Schritte basierend auf Ergebnissen

### Szenario 1: Verletzungen bei 40-63 kHz, spezifische Positionen

**→ Raum-Resonanzen**

**Lösung:**
1. Akzeptieren als physikalisches Phänomen
2. FS_global aus korrigierten IRs berechnen (beinhaltet Resonanzen)
3. Oder: Clip dBFS auf 0 dB für Darstellung

---

### Szenario 2: Verletzungen bei allen Frequenzen

**→ Systematischer Fehler**

**Aktionen:**
1. Prüfe Rohdaten: Sind sie normalisiert?
2. Suche nach anderen Signal-Korrekturen
3. Vergleiche: `max(ir_time)` vs. `sqrt(sum(fft(ir)²))`

---

### Szenario 3: Keine Verletzungen gefunden

**→ Problem liegt woanders**

**Möglichkeiten:**
1. Positive dBFS entstehen in **anderer** Berechnung (nicht calc_terz_spectrum)
2. Visualisierungs-Fehler (Plot zeigt falsche Werte)
3. Unterschiedliche FS_global in verschiedenen Tools

---

## 🛠️ Erweiterte Diagnostik

Wenn Sie die Ursache gefunden haben, können Sie gezielt weiter analysieren:

### Analysiere spezifische Datei:

```matlab
% Lade Datei mit Verletzung
filepath = 'dataraw/Variante_3_Pos12.mat';
[S, meta] = load_and_parse_file(filepath);
ir = extract_ir(S);

% Zeitbereich
max_time = max(abs(ir));
rms_time = rms(ir);

% Frequenzbereich
X = fft(ir);
energy_fft = sum(abs(X).^2) / length(ir);
max_freq_component = max(abs(X));

fprintf('Max (Zeit):  %.6f\n', max_time);
fprintf('RMS (Zeit):  %.6f\n', rms_time);
fprintf('Max (FFT):   %.6f\n', max_freq_component);
fprintf('Energy (FFT): %.6f\n', energy_fft);
```

### Vergleiche rohe vs. prozessierte Daten:

```matlab
% Raw
ir_raw = extract_ir(S);

% Processed
[ir_trunc, ~] = truncate_ir(ir_raw, 15000);

% Vergleich
fprintf('Raw - Max: %.6f, RMS: %.6f\n', max(abs(ir_raw)), rms(ir_raw));
fprintf('Trunc - Max: %.6f, RMS: %.6f\n', max(abs(ir_trunc)), rms(ir_trunc));
```

## 📋 Checklist für manuelle Analyse

Wenn das Script läuft, prüfen Sie:

- [ ] Wie viele Verletzungen gibt es? (0, wenige, viele?)
- [ ] Bei welchen Frequenzen? (Nur hohe oder alle?)
- [ ] Bei welchen Varianten/Positionen? (Muster erkennbar?)
- [ ] Wie groß sind die Verletzungen? (< 1 dB oder > 5 dB?)
- [ ] Welche Datei bestimmt FS_global? (Nahfeld oder Fernfeld?)
- [ ] Gibt es geometrische Muster? (Ecken, bestimmte Abstände?)

## 💡 Häufige Erkenntnisse

### Typisches Muster 1: Hochfrequenz-Resonanzen
```
Verletzungen: Nur bei 40-63 kHz
Betroffene Positionen: Ecken, spezifische Abstände
Ursache: Raum-Moden, stehende Wellen
Lösung: FS_global aus korrigierten IRs
```

### Typisches Muster 2: Nahfeld-Effekt
```
Verletzungen: Bei nahen Positionen (< 0.5m)
Alle Frequenzen betroffen
Ursache: FS_global durch Fernfeld bestimmt, Nahfeld hat höhere Energie
Lösung: FS_global separat für Nahfeld/Fernfeld
```

### Typisches Muster 3: Normalisierungs-Fehler
```
Verletzungen: Überall, systematisch
Alle Dateien betroffen
Ursache: Rohdaten bereits normalisiert
Lösung: Prüfe Rohdaten, FS_global neu berechnen
```

---

## 🎯 Abschließende Empfehlung

Nach Ausführung des Scripts:

1. **Exportierte Datei ansehen:** `Plots/dBFS_Violations.xlsx`
2. **Muster erkennen:** Frequenzen? Positionen? Varianten?
3. **Physikalische Erklärung finden:** Warum gerade diese Fälle?
4. **Lösung wählen:**
   - Wenn Resonanzen: FS_global aus korrigierten IRs
   - Wenn systematisch: Ursache im Code finden und beheben
   - Wenn selten: Eventuell tolerieren oder clippen

---

*Erstellt: 2026-01-19*
*Nur Energie-basierte Analyse - keine dB-Umwandlung*
