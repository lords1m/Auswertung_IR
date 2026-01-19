# Summenpegel-Berechnung: Detaillierte Erklärung

Erstellt: 2026-01-19

## 🎯 Was ist der Summenpegel?

Der **Summenpegel (L_sum)** ist der **Gesamt-Energiepegel** über alle Terzbänder (4-63 kHz) in dBFS.

---

## 📐 Berechnung in calc_terz_spectrum.m

### Schritt-für-Schritt Ablauf

#### **Schritt 1: FFT der Impulsantwort**

```matlab
% Zeile 27-30
N = length(ir);              % IR-Länge (z.B. 15000 Samples)
N_fft = 2^nextpow2(N);      % FFT-Länge (nächste 2er-Potenz)
X = fft(ir, N_fft);         % FFT berechnen
freqs = (0:N_fft-1) * (fs / N_fft);  % Frequenz-Achse
```

**Beispiel:**
- `N = 15000 Samples`
- `N_fft = 16384 = 2^14`
- `fs = 500 kHz`
- `freqs = [0, 30.5 Hz, 61.0 Hz, ..., 499969.5 Hz]`

---

#### **Schritt 2: Luftdämpfungs-Korrektur (falls dist > 0)**

```matlab
% Zeile 32-40
if dist > 0
    [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T, LF, dist);
    X = X .* A_lin(:);  // Verstärkung mit Korrekturfaktor
end
```

**Was passiert:**
- Hohe Frequenzen werden durch Luft gedämpft
- `A_lin` ist der Korrekturfaktor (linear): `A_lin = 10^(Dämpfung_dB / 20)`
- Multiplikation mit `A_lin` **kompensiert** die Dämpfung

**Beispiel bei 63 kHz, 20°C, 50% LF, 1m:**
- Dämpfung: ~1.6 dB
- `A_lin = 10^(1.6/20) = 1.20`
- Signal wird um Faktor 1.20 verstärkt (= Dämpfung rückgängig machen)

---

#### **Schritt 3: Nur positive Frequenzen nehmen**

```matlab
% Zeile 42-45
valid_idx = 1:floor(N_fft/2)+1;
X = X(valid_idx);
freqs = freqs(valid_idx);
```

**Warum:**
- FFT ist symmetrisch (negative Frequenzen = konjugiert komplex zu positiven)
- Nur positive Frequenzen 0 bis fs/2 relevant

---

#### **Schritt 4: Energie-Dichte berechnen**

```matlab
% Zeile 47-48
X_mag_sq = (abs(X).^2) / N;
```

**Formel:**
```
Energie pro Frequenz-Bin = |FFT(f)|² / N
```

**Parseval-Theorem:**
```
sum(ir²) = sum(|FFT|²) / N
```

→ Division durch `N` (ORIGINAL IR-Länge, nicht N_fft!) für korrekte Energie-Normierung

**Beispiel:**
```matlab
ir = [0.1, 0.2, -0.1, -0.2];  % N = 4
energie_zeit = sum(ir.^2) = 0.1

X = fft(ir);
energie_freq = sum(abs(X).^2) / 4 = 0.1  // Gleich! ✓
```

---

#### **Schritt 5: Terzbänder durchlaufen und Energie summieren**

```matlab
% Zeile 58-77
L_dBFS = NaN(size(f_mitten));
energy_sum = 0;  // Gesamtenergie über ALLE Bänder

for k = 1:length(f_mitten)
    fc = f_exact(k);           // Exakte Mittenfrequenz
    fl = fc * 10^(-1/20);      // Untere Grenze
    fu = fc * 10^(1/20);       // Obere Grenze

    idx = freqs >= fl & freqs <= fu;  // Frequenzen in diesem Band

    if any(idx)
        band_energy = sum(X_mag_sq(idx));      // Energie dieses Bands
        energy_sum = energy_sum + band_energy;  // Zur Gesamtsumme addieren
        L_dBFS(k) = 10 * log10(band_energy / (FS_global^2 + eps));
    end
end
```

**Was passiert:**

1. **Für jedes Terzband** (4 kHz bis 63 kHz):
   - Berechne Bandgrenzen `[fl, fu]`
   - Finde alle FFT-Bins in diesem Band
   - Summiere deren Energie: `band_energy = sum(X_mag_sq(idx))`
   - Addiere zur Gesamtenergie: `energy_sum += band_energy`

2. **Band-Pegel in dBFS:**
   ```
   L_dBFS(k) = 10 * log10(band_energy / FS_global²)
   ```

**Beispiel Terzband 10 kHz:**
```
fc = 10000 Hz
fl = 10000 * 10^(-1/20) = 8913 Hz
fu = 10000 * 10^(1/20) = 11220 Hz

Frequenz-Bins in [8913, 11220]:
  Bin 292: 8910 Hz  → energie = 0.001
  Bin 293: 8940 Hz  → energie = 0.002
  ...
  Bin 368: 11220 Hz → energie = 0.001

band_energy = sum(alle energien) = 0.156

L_dBFS(10kHz) = 10 * log10(0.156 / 1.0²) = -8.07 dB FS
```

---

#### **Schritt 6: Summenpegel berechnen**

```matlab
% Zeile 79-84
if energy_sum <= 0
    L_sum = -Inf;
else
    L_sum = 10 * log10(energy_sum / (FS_global^2 + eps));
end
```

**Formel:**
```
L_sum = 10 * log10(Σ(band_energies) / FS_global²)
```

**In Worten:**
- **energy_sum**: Summe der Energien ALLER Terzbänder (4-63 kHz)
- **FS_global²**: Referenzenergie (globales Maximum der verarbeiteten IRs)
- **L_sum**: Gesamt-Pegel in dB relativ zu FS_global

---

## 🔬 Mathematische Herleitung

### Energie-Beziehung

**Zeit-Domäne:**
```
E_total = sum(ir²)  // Gesamt-Energie der IR
```

**Frequenz-Domäne (Parseval):**
```
E_total = sum(|FFT|²) / N
        = sum(X_mag_sq)  // Über ALLE Frequenzen
```

**Terzband-Energie:**
```
E_terz = sum(X_mag_sq(idx_band))  // Nur Frequenzen im Band
```

**Summenpegel-Energie:**
```
E_sum = Σ(E_terz_k) für k = 1..13 (alle Terzbänder)
```

**dBFS-Umrechnung:**
```
L_sum [dBFS] = 10 * log10(E_sum / FS_global²)
```

---

### Warum FS_global²?

**FS_global** ist die maximale **Amplitude** (linear):
```
FS_global = max(abs(ir_trunc))  // z.B. 1.0
```

**Referenz-ENERGIE:**
```
E_ref = FS_global² = 1.0²  // Energie eines Dauer-Signals mit Amplitude FS_global
```

**dBFS-Definition:**
```
0 dBFS = Pegel eines Signals, dessen Energie = FS_global²
```

→ Wenn `E_sum = FS_global²`, dann `L_sum = 0 dB FS` ✓

---

## 📊 Beispiel-Rechnung

### Gegeben:

- **IR**: 15000 Samples, verarbeitet (DC-removed, truncated)
- **FS_global**: 1.0 (max Amplitude nach Verarbeitung)
- **Distanz**: 1.0 m
- **Terzbänder**: 13 Bänder (4-63 kHz)

### Berechnung:

#### 1. FFT und Energie-Dichte

```matlab
X = fft(ir, 16384);
X_mag_sq = abs(X).^2 / 15000;
```

#### 2. Luftdämpfungs-Korrektur (bei 1m)

```matlab
A_lin = airabsorb(...);  // z.B. Faktor 1.05 bei 10 kHz, 1.20 bei 63 kHz
X = X .* A_lin;
X_mag_sq = abs(X).^2 / 15000;  // Neu berechnen nach Korrektur
```

#### 3. Terzbänder

| Band | Energie | Energie (korr.) | L_dBFS |
|------|---------|-----------------|--------|
| 4 kHz   | 0.010 | 0.010 | -20.0 dB |
| 5 kHz   | 0.015 | 0.016 | -18.0 dB |
| 6.3 kHz | 0.020 | 0.021 | -16.8 dB |
| 8 kHz   | 0.025 | 0.027 | -15.7 dB |
| 10 kHz  | 0.050 | 0.055 | -12.6 dB |
| 12.5 kHz| 0.040 | 0.045 | -13.5 dB |
| 16 kHz  | 0.030 | 0.035 | -14.6 dB |
| 20 kHz  | 0.025 | 0.030 | -15.2 dB |
| 25 kHz  | 0.020 | 0.025 | -16.0 dB |
| 31.5 kHz| 0.015 | 0.020 | -17.0 dB |
| 40 kHz  | 0.010 | 0.015 | -18.2 dB |
| 50 kHz  | 0.008 | 0.013 | -18.9 dB |
| 63 kHz  | 0.005 | 0.010 | -20.0 dB |
| **Summe** | **0.273** | **0.322** | |

#### 4. Summenpegel

```matlab
energy_sum = 0.322  // Nach Luftdämpfungs-Korrektur
L_sum = 10 * log10(0.322 / 1.0²)
      = 10 * log10(0.322)
      = 10 * (-0.492)
      = -4.92 dB FS
```

**Interpretation:**
- Die **Gesamt-Energie** über alle Terzbänder ist **ca. 32%** der Referenz
- Der **Summenpegel** liegt bei **-4.92 dB FS**
- Das Signal ist **deutlich unter** 0 dB FS (gut!)

---

## 🚨 Wichtige Punkte

### 1. **energy_sum vs. sum(L_dBFS)**

**FALSCH:**
```matlab
L_sum = sum(L_dBFS)  // NEIN! Das ist falsch!
```

**RICHTIG:**
```matlab
energy_sum = sum(band_energies)  // Energien addieren (linear!)
L_sum = 10 * log10(energy_sum / FS_global²)
```

**Warum:**
- dB-Werte darf man **nicht einfach addieren**!
- Man muss **Energien** (linear) addieren, dann in dB umrechnen

**Beispiel:**
```
Band 1: -10 dB → Energie = 0.1
Band 2: -10 dB → Energie = 0.1
Summe: Energie = 0.2 → -7 dB (NICHT -20 dB!)
```

---

### 2. **Luftdämpfungs-Korrektur VOR der Energie-Summierung**

```matlab
// Schritt 1: Korrektur im Frequenz-Bereich
X = X .* A_lin;

// Schritt 2: Energie berechnen (nach Korrektur!)
X_mag_sq = abs(X).^2 / N;

// Schritt 3: Terzbänder summieren
energy_sum = sum(band_energies);  // Energien nach Korrektur
```

→ Luftdämpfung wird **kompensiert** BEVOR Summenpegel berechnet wird

---

### 3. **FS_global² ist die Referenz-ENERGIE**

```matlab
L_sum = 10 * log10(energy_sum / FS_global²)
                              ^^^^^^^^
                              Energie, nicht Amplitude!
```

**Wenn FS_global aus ROHEN IRs berechnet würde:**
- `FS_global = 1.05` (mit DC-Offset)
- `FS_global² = 1.1025`
- `energy_sum = 0.322` (aus verarbeiteten IRs, DC entfernt)
- `L_sum = 10 * log10(0.322 / 1.1025) = -5.34 dB`

**Wenn FS_global aus VERARBEITETEN IRs berechnet wird:**
- `FS_global = 1.00` (DC entfernt)
- `FS_global² = 1.0`
- `energy_sum = 0.322`
- `L_sum = 10 * log10(0.322 / 1.0) = -4.92 dB`

→ **Konsistenz ist kritisch!**

---

## 🎯 Zusammenfassung

### Formel (kompakt):

```
L_sum = 10 * log10( Σ(E_terz_k) / FS_global² )

wobei:
  E_terz_k = sum(|FFT(ir)|²/N) über Frequenzen in Band k
  FS_global = max(abs(ir_verarbeitet))
```

### Ablauf:

1. ✅ **FFT** der verarbeiteten IR
2. ✅ **Luftdämpfungs-Korrektur** (falls dist > 0)
3. ✅ **Energie-Dichte**: `X_mag_sq = |X|² / N`
4. ✅ **Terzbänder**: Für jedes Band k: `E_k = sum(X_mag_sq in Band)`
5. ✅ **Summierung**: `E_sum = Σ(E_k)`
6. ✅ **dBFS**: `L_sum = 10 * log10(E_sum / FS_global²)`

### Warum kann L_sum > 0 dB sein?

**Mögliche Ursachen:**

1. **FS_global aus rohen IRs** (mit DC-Offset)
   → GELÖST durch 2-Pass Ansatz! ✅

2. **Luftdämpfungs-Korrektur zu stark**
   → Bei kleinen Distanzen + hohen Frequenzen
   → `A_lin` sehr groß → `X` wird stark verstärkt
   → `energy_sum` kann > `FS_global²` werden

3. **Inkonsistente Verarbeitung**
   → Einige IRs mit anderen Parametern verarbeitet
   → FS_global nicht repräsentativ

4. **Resonanzen in der Messung**
   → Tatsächlich höhere Energie bei bestimmten Frequenzen
   → Physikalisch möglich (z.B. Raummoden)

---

## 📚 Verwandte Funktionen

### calc_rt60_spectrum.m

Berechnet **T30 (Nachhallzeit)** für Terzbänder.
- Nutzt **NICHT** FS_global (T30 ist zeitbasiert)
- Filtert IR mit Butterworth-Filter pro Band
- Berechnet Abklingzeit

### Visualize_Terzband_Filter.m

Visualisiert Terzband-Filter.
- Nutzt **NICHT** FS_global
- Zeigt Frequenzgänge der Filter

### Analyse_Reflexionsgrad.m

Berechnet Reflexionsfaktor.
- Nutzt möglicherweise FS_global (überprüfen!)

---

*Erstellt: 2026-01-19*
*Erklärt: Summenpegel-Berechnung in calc_terz_spectrum.m*
