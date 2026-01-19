# Geometrie-Korrektur: Source Position Offset

Erstellt: 2026-01-19

## 🎯 Problem

Die Messpositionen starten **0.3m seitlich und 0.3m höher** als die Quelle.
Die bisherige Annahme (Quelle bei 0, 0) war **FALSCH**!

---

## ✅ Lösung

**Alte Quell-Position:** `(0, 0)`
**Neue Quell-Position:** `(-0.3, -0.3)`

---

## 📊 Distanz-Änderungen

### Alte Geometrie (Quelle bei 0, 0):

| Position | x [m] | y [m] | Distanz ALT [m] |
|----------|-------|-------|-----------------|
| 1        | 0.0   | 1.2   | 1.200           |
| 2        | 0.3   | 1.2   | 1.237           |
| 3        | 0.6   | 1.2   | 1.342           |
| 4        | 1.2   | 1.2   | 1.697           |
| 5        | 0.0   | 0.6   | 0.600           |
| 6        | 0.3   | 0.6   | 0.671           |
| 7        | 0.6   | 0.6   | 0.849           |
| 8        | 1.2   | 0.6   | 1.342           |
| **9**    | **0.0** | **0.3** | **0.300** ⚠️ |
| 10       | 0.3   | 0.3   | 0.424           |
| 11       | 0.6   | 0.3   | 0.671           |
| 12       | 1.2   | 0.3   | 1.237           |
| **13**   | **0.3** | **0.0** | **0.300** ⚠️ |
| 14       | 0.6   | 0.0   | 0.600           |
| 15       | 1.2   | 0.0   | 1.200           |

**Kleinste Distanz:** 0.300 m (Position 9 und 13)

---

### Neue Geometrie (Quelle bei -0.3, -0.3):

| Position | x [m] | y [m] | Distanz NEU [m] | Differenz [m] |
|----------|-------|-------|-----------------|---------------|
| 1        | 0.0   | 1.2   | **1.530**       | +0.330        |
| 2        | 0.3   | 1.2   | **1.565**       | +0.328        |
| 3        | 0.6   | 1.2   | **1.671**       | +0.329        |
| 4        | 1.2   | 1.2   | **2.027**       | +0.330        |
| 5        | 0.0   | 0.6   | **0.900**       | +0.300        |
| 6        | 0.3   | 0.6   | **1.001**       | +0.330        |
| 7        | 0.6   | 0.6   | **1.179**       | +0.330        |
| 8        | 1.2   | 0.6   | **1.671**       | +0.329        |
| **9**    | **0.0** | **0.3** | **0.671** ✅  | **+0.371**    |
| 10       | 0.3   | 0.3   | **0.849**       | +0.425        |
| 11       | 0.6   | 0.3   | **1.001**       | +0.330        |
| 12       | 1.2   | 0.3   | **1.565**       | +0.328        |
| **13**   | **0.3** | **0.0** | **0.671** ✅  | **+0.371**    |
| 14       | 0.6   | 0.0   | **0.900**       | +0.300        |
| 15       | 1.2   | 0.0   | **1.530**       | +0.330        |

**Kleinste Distanz:** 0.671 m (Position 9 und 13)

→ **+123% Erhöhung** der minimalen Distanz! (0.3m → 0.671m)

---

## 🔬 Auswirkung auf Luftdämpfungs-Korrektur

### Prinzip der Luftdämpfung

Bei höheren Frequenzen (63 kHz) wird Schall stärker gedämpft:
- **Dämpfung [dB]** = α × Distanz
- **Korrektur** = Signal × 10^(Dämpfung/20)

→ **Größere Distanz = Stärkere Korrektur!**

### Beispiel bei 63 kHz (20°C, 50% LF)

Dämpfungskoeffizient α ≈ 1.6 dB/m

| Distanz ALT [m] | Dämpfung ALT [dB] | Korrektur ALT | Distanz NEU [m] | Dämpfung NEU [dB] | Korrektur NEU | Differenz |
|-----------------|-------------------|---------------|-----------------|-------------------|---------------|-----------|
| 0.300           | 0.48              | ×1.056        | **0.671**       | **1.07**          | **×1.132**    | **+7.2%** |
| 0.424           | 0.68              | ×1.080        | **0.849**       | **1.36**          | **×1.172**    | **+8.5%** |
| 0.600           | 0.96              | ×1.115        | **0.900**       | **1.44**          | **×1.187**    | **+6.5%** |
| 1.200           | 1.92              | ×1.246        | **1.530**       | **2.45**          | **×1.322**    | **+6.1%** |

→ **Stärkere Korrektur** → Höhere band_energy nach Korrektur!

---

## 🚨 Auswirkung auf dBFS-Problem

### Vorher (falsche Distanzen):

**Position 9** bei 0.3m:
```
Signal (roh):       niedrig (weit von Quelle)
Luftdämpfung:       -0.48 dB
Korrektur:          ×1.056 (schwach)
Signal (korr):      niedrig × 1.056 = immer noch niedrig
band_energy:        niedrig
dBFS:               negativ ✓
```

### Nachher (korrekte Distanzen):

**Position 9** bei 0.671m:
```
Signal (roh):       GLEICH niedrig (weit von Quelle)
Luftdämpfung:       -1.07 dB
Korrektur:          ×1.132 (STÄRKER!)
Signal (korr):      niedrig × 1.132 = HÖHER
band_energy:        HÖHER (+7.2%)
dBFS:               KANN positiv werden! ⚠️
```

**ABER:** Wenn FS_global ebenfalls mit den **neuen Distanzen** berechnet wird, sollte es konsistent sein!

---

## 🔍 Warum war das ein Problem?

### Hypothese 1: Inkonsistente Distanzen

**Mögliches Szenario:**
- Einige Dateien wurden mit alten Distanzen (0.3m) verarbeitet
- Andere mit neuen Distanzen (0.671m)
- FS_global basiert auf Dateien mit alten Distanzen (höher)
- Aber Analyse verwendet neue Distanzen (stärkere Korrektur)
- → Positive dBFS!

### Hypothese 2: Position 0 existierte

**Mögliches Szenario:**
- Es gab Dateien "Pos_0" oder ähnlich
- Diese wurden OHNE Luftdämpfungs-Korrektur verarbeitet (dist=0)
- Nach Korrektur haben alle anderen Positionen höhere Distanzen
- Aber Pos_0 hatte die ursprünglichen (unkorrigierten) hohen Werte
- → Positive dBFS bei diesen Dateien!

---

## 🎯 Was ändert sich jetzt?

### In get_geometry.m

```matlab
% ALT:
source_x = 0; source_y = 0;

% NEU:
source_x = -0.3; source_y = -0.3;
```

### Distanz-Berechnung

Bleibt gleich:
```matlab
d = sqrt((x - source_x)^2 + (y - source_y)^2);
```

Aber mit neuen source_x, source_y Werten!

### Luftdämpfungs-Korrektur

In `calc_terz_spectrum.m`:
```matlab
if dist > 0
    [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T, LF, dist);
    X = X .* A_lin(:);  % Verstärkung mit A_lin
end
```

Jetzt mit **korrekten Distanzen**:
- Position 9: dist=0.671m statt 0.300m
- Position 13: dist=0.671m statt 0.300m
- → **Mehr Korrektur** bei allen Positionen!

---

## 🧪 Nächste Schritte

### 1. Daten neu verarbeiten

```matlab
run('scripts/preprocessing/step1_process_data.m')
```

**Erwartung:**
- Alle Distanzen sind jetzt größer
- Mehr Luftdämpfungs-Korrektur wird angewendet
- FS_global wird mit neuen Distanzen berechnet

### 2. Diagnostik ausführen

```matlab
run('scripts/preprocessing/diagnose_dbfs_energy.m')
```

**Erwartung:**

#### Falls konsistent:
→ **KEINE Verletzungen** mehr!
→ Problem gelöst ✅

#### Falls inkonsistent:
→ Verletzungen bleiben oder verschlimmern sich
→ Weitere Analyse nötig (z.B. alte Dateien mit falschen Distanzen)

### 3. Vergleich ALT vs. NEU

Führen Sie die Verarbeitung einmal mit alten Distanzen und einmal mit neuen aus:

```matlab
% Sichern Sie die alten Ergebnisse:
copyfile('processed/Summary.xlsx', 'processed/Summary_ALT.xlsx');

% Verarbeiten Sie neu mit korrigierten Distanzen:
run('scripts/preprocessing/step1_process_data.m')

% Vergleichen Sie:
old = readtable('processed/Summary_ALT.xlsx');
new = readtable('processed/Summary.xlsx');
```

---

## 📐 Visualisierung

### ALT (Quelle bei 0, 0):

```
y ^
  |
1.2  [ 1]     [ 2]     [ 3]     [ 4]
0.6  [ 5]     [ 6]     [ 7]     [ 8]
0.3  [ 9]     [10]     [11]     [12]
0.0  SOURCE   [13]     [14]     [15]
     -------------------------------------> x
     0.0      0.3      0.6      1.2
```

**Nächste Position:** Pos_9 bei (0, 0.3) → **0.300m**

---

### NEU (Quelle bei -0.3, -0.3):

```
y ^
  |
1.2  [ 1]     [ 2]     [ 3]     [ 4]
0.6  [ 5]     [ 6]     [ 7]     [ 8]
0.3  [ 9]     [10]     [11]     [12]
0.0           [13]     [14]     [15]
     -------------------------------------> x
     0.0      0.3      0.6      1.2

-0.3  SOURCE
     -0.3
```

**Nächste Position:** Pos_9 bei (0, 0.3) → **0.671m**

→ Die Quelle ist jetzt "links-unten" von allen Messpositionen!

---

## 🔢 Mathematische Verifikation

**Position 9: (0, 0.3)**

```
ALT:
d = sqrt((0 - 0)² + (0.3 - 0)²)
  = sqrt(0 + 0.09)
  = 0.300 m

NEU:
d = sqrt((0 - (-0.3))² + (0.3 - (-0.3))²)
  = sqrt(0.3² + 0.6²)
  = sqrt(0.09 + 0.36)
  = sqrt(0.45)
  = 0.671 m ✓
```

**Position 10: (0.3, 0.3)**

```
ALT:
d = sqrt(0.3² + 0.3²)
  = sqrt(0.18)
  = 0.424 m

NEU:
d = sqrt((0.3 + 0.3)² + (0.3 + 0.3)²)
  = sqrt(0.6² + 0.6²)
  = sqrt(0.72)
  = 0.849 m ✓
```

**Position 4: (1.2, 1.2)** (weiteste Position)

```
ALT:
d = sqrt(1.2² + 1.2²)
  = sqrt(2.88)
  = 1.697 m

NEU:
d = sqrt(1.5² + 1.5²)
  = sqrt(4.5)
  = 2.121 m ✓
```

→ **Alle Distanzen** werden größer (ca. +0.3 bis +0.42 m)!

---

## 📊 Erwartete Änderungen in den Ergebnissen

### Terzband-Spektren

**Erwartung:**
- Höhere Pegel bei allen Positionen (mehr Korrektur)
- Besonders bei hohen Frequenzen (63 kHz)
- Geringere Unterschiede zwischen nahen und fernen Positionen

### dBFS-Werte

**Erwartung:**
- Falls vorher positiv bei einigen Positionen:
  - Können sich normalisieren (falls FS_global ebenfalls steigt)
  - Oder sich verschlimmern (falls Korrektur zu stark)

### Nachhallzeit (T30)

**Erwartung:**
- Wenig Änderung (T30 ist unabhängig von absoluten Pegeln)

---

## ✅ Zusammenfassung

### Was wurde geändert?

1. ✅ **get_geometry.m**: Quell-Position von (0, 0) auf (-0.3, -0.3)
2. ✅ **Alle Distanzen**: Erhöht um ~0.3-0.42 m
3. ✅ **Luftdämpfungs-Korrektur**: Stärker bei allen Positionen

### Was muss noch getan werden?

1. 🔄 **Daten neu verarbeiten** mit step1_process_data.m
2. 🔍 **Diagnostik ausführen** mit diagnose_dbfs_energy.m
3. 📊 **Ergebnisse vergleichen** (ALT vs. NEU)

### Erwartetes Resultat?

🎯 **Falls korrekt:**
- Keine positiven dBFS-Werte mehr (oder deutlich weniger)
- Konsistente Energie-Verteilung
- Physikalisch plausible Ergebnisse

⚠️ **Falls Problem bleibt:**
- Andere Root Cause (z.B. Resonanzen, Messfehler)
- Inkonsistente alte Daten
- Weitere Analyse nötig

---

*Korrigiert: 2026-01-19*
*Quelle verschoben: (0, 0) → (-0.3, -0.3)*
*Grund: Messpositionen starten 0.3m seitlich und höher*
