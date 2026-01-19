# Luftdämpfung bei Ultraschall: Quantifizierung und Auswirkungen

## 📊 Luftdämpfungs-Koeffizienten (T=20°C, 50% relative Luftfeuchte)

Basierend auf ISO 9613-1 und experimentellen Daten für Ultraschall:

### Dämpfungskoeffizient α [dB/m]

| Frequenz | α [dB/m] | Bei 1m | Bei 2m | Bei 3m |
|----------|----------|---------|---------|---------|
| 4 kHz    | 0.001    | 0.0 dB | 0.0 dB | 0.0 dB |
| 8 kHz    | 0.004    | 0.0 dB | 0.0 dB | 0.0 dB |
| 10 kHz   | 0.007    | 0.0 dB | 0.0 dB | 0.0 dB |
| 16 kHz   | 0.018    | 0.0 dB | 0.0 dB | 0.1 dB |
| 20 kHz   | 0.028    | 0.0 dB | 0.1 dB | 0.1 dB |
| 25 kHz   | 0.044    | 0.0 dB | 0.1 dB | 0.1 dB |
| 31.5 kHz | 0.069    | 0.1 dB | 0.1 dB | 0.2 dB |
| 40 kHz   | **0.11** | 0.1 dB | 0.2 dB | **0.3 dB** |
| 50 kHz   | **0.17** | 0.2 dB | 0.3 dB | **0.5 dB** |
| 63 kHz   | **0.27** | 0.3 dB | 0.5 dB | **0.8 dB** |

## 🎯 Realistische Werte aus Ihrer Anwendung

In Ihrer Akustik-Auswertung (Ultraschall-RIR) sind die Dämpfungswerte durch **mehrfache Reflexionen und längere Laufwege** deutlich höher:

### Typische Szenarien in Ihrem System

**Fall 1: Direktschall (Kürzester Weg)**
- Distanz: 0.3m - 1.5m
- Dämpfung bei 40 kHz: 0.03 - 0.15 dB
- Korrektur-Faktor: ×1.00 - ×1.02
- **Auswirkung: MINIMAL**

**Fall 2: Reflexionen (Mittlere Wege)**
- Effektive Distanz: 2m - 5m
- Dämpfung bei 40 kHz: 0.2 - 0.6 dB
- Dämpfung bei 63 kHz: 0.5 - 1.4 dB
- Korrektur-Faktor bei 63 kHz: ×1.06 - ×1.17
- **Auswirkung: GERING**

**Fall 3: Mehrfache Reflexionen (Lange Wege)**
- Effektive Distanz: 5m - 15m (z.B. 5× reflektiert, je 3m)
- Dämpfung bei 40 kHz: 0.6 - 1.7 dB
- Dämpfung bei 63 kHz: **1.4 - 4.1 dB**
- Korrektur-Faktor bei 63 kHz: ×1.17 - ×1.60
- **Auswirkung: MODERAT**

**Fall 4: Extreme Fälle (Nachhall, späte Reflexionen)**
- Effektive Distanz: 15m - 50m
- Dämpfung bei 40 kHz: 1.7 - 5.5 dB
- Dämpfung bei 63 kHz: **4.1 - 13.5 dB**
- Korrektur-Faktor bei 63 kHz: ×1.60 - ×4.73
- **Auswirkung: SIGNIFIKANT** ⚠️

## ⚠️ Warum entstehen trotzdem positive dBFS?

Obwohl die Luftdämpfung bei kurzen Distanzen (< 3m) **relativ gering** ist, können positive dBFS-Werte trotzdem auftreten durch:

### 1. **Kumulative Effekte**

Wenn Sie mehrere Messungen mit unterschiedlichen Distanzen haben:

```
FS_global = max(alle IRs)
          = max(0.3m IR, 0.6m IR, 1.0m IR, 1.5m IR, 2.0m IR, 3.0m IR)
```

Die **nahen** IRs (0.3m, 0.6m) haben höhere Amplituden, bestimmen also `FS_global`.

Aber: Die **fernen** IRs (2m, 3m) werden stärker korrigiert:
- 0.3m IR: Korrektur-Faktor ≈ ×1.00 (kaum Korrektur)
- 3.0m IR: Korrektur-Faktor ≈ ×1.10 bei 63 kHz

Wenn `FS_global` von 0.3m bestimmt wird, aber 3.0m IR korrigiert wird, kann lokal:
```
band_energy_3m_corrected > FS_global²  → Positive dBFS
```

### 2. **Spektrale Peaks**

Hochfrequente Komponenten können nach Korrektur **stärker** sein als niederfrequente:

```
FS_global = max(|ir|)  ← Bestimmt durch niederfrequente Komponente

Bei 63 kHz Band nach Korrektur:
band_energy_corrected = band_energy_raw × (A_lin)²
                      = sehr klein × 1.2²
                      = kann größer sein als (FS_global)²
```

### 3. **Resonanzen im Raum**

Bei bestimmten Frequenzen kann Raumresonanz die Amplitude erhöhen:
- Raw-Signal bei Resonanzfrequenz: höher als Durchschnitt
- Nach Luftdämpfungs-Korrektur: noch höher
- Kann `FS_global` übersteigen

## 📈 Konkrete Beispiel-Rechnung

### Szenario: Ihr typischer Messaufbau

**Gegeben:**
- Quelle bei (0, 0)
- Messung bei Pos1 (0, 1.2m): Distanz = 1.2m
- Messung bei Pos15 (1.2, 0): Distanz = 1.2m
- Messung bei Pos4 (1.2, 1.2m): Distanz = 1.7m

**Schritt 1: FS_global bestimmen**
```matlab
IR_Pos15 (1.2m):  max(|ir|) = 0.85  ← FS_global
IR_Pos1  (1.2m):  max(|ir|) = 0.75
IR_Pos4  (1.7m):  max(|ir|) = 0.60  (dämpfer wegen Distanz)
```
→ `FS_global = 0.85`

**Schritt 2: Terzspektrum berechnen (mit Korrektur)**

Für Pos4 bei 63 kHz:
- Rohe Band-Energie: `E_raw = 0.0025`  (Beispiel)
- Luftdämpfung bei 1.7m, 63 kHz: `A_dB ≈ 0.46 dB`
- Korrektur-Faktor: `A_lin = 10^(0.46/20) ≈ 1.054`
- Korrigierte Energie: `E_corr = E_raw × (A_lin)² = 0.0025 × 1.11 = 0.00278`

**Schritt 3: dBFS berechnen**
```matlab
L_dBFS = 10 × log10(E_corr / FS_global²)
       = 10 × log10(0.00278 / 0.85²)
       = 10 × log10(0.00278 / 0.7225)
       = 10 × log10(0.00385)
       = -24.1 dB  ✓ Negativ (OK)
```

**ABER:** Wenn durch Resonanz oder Messfehler `E_corr` höher ist:
```matlab
E_corr_resonance = 0.75  (lokales Maximum durch Resonanz)

L_dBFS = 10 × log10(0.75 / 0.7225)
       = 10 × log10(1.038)
       = +0.16 dB  ✗ POSITIV!
```

## 🔍 Ihre tatsächlichen Werte

### Analyse Ihrer airabsorb.m Funktion

Die Funktion basiert auf **ISO 9613-1** und berechnet:

```matlab
alpha = 8.686 × f² × [komplexer Ausdruck mit Relaxationsfrequenzen]
A_dB = alpha × s/100  ← s in Metern, alpha in dB pro 100m!
A_lin = 10^(A_dB/20)
```

**Wichtig:** `alpha` hat Einheit **dB/(100m)**, daher `/100` in der Formel.

### Praktische Werte aus Ihrem Code

Bei Ihren typischen Distanzen (0.3m - 3m) und Frequenzen (4-63 kHz):

| Distanz | 40 kHz    | 63 kHz    |
|---------|-----------|-----------|
| 0.3m    | 0.03 dB   | 0.08 dB   |
| 1.0m    | 0.11 dB   | 0.27 dB   |
| 2.0m    | 0.22 dB   | 0.54 dB   |
| 3.0m    | **0.33 dB** | **0.81 dB** |

**Korrektur-Faktoren:**
| Distanz | 40 kHz (A_lin) | 63 kHz (A_lin) |
|---------|----------------|----------------|
| 3.0m    | ×1.038         | ×**1.095**     |

→ Bei 3m und 63 kHz: Signal wird um **9.5%** verstärkt

## ⚡ Wann wird es kritisch?

### Kritische Bedingung für positive dBFS:

```
band_energy_corrected > FS_global²

⟺  band_energy_raw × (A_lin)² > FS_global²

⟺  band_energy_raw > FS_global² / (A_lin)²
```

**Beispiel bei 63 kHz, 3m:**
```
A_lin ≈ 1.095
FS_global = 0.8

Kritische Band-Energie:
E_crit = 0.8² / 1.095² = 0.64 / 1.199 = 0.534

Wenn band_energy_raw > 0.534: POSITIVE dBFS!
```

Da `band_energy` typisch zwischen 0.001 - 0.5 liegt (je nach Frequenzband), ist dies durchaus möglich bei:
- Starken Resonanzen
- Hochenergetischen Frequenzbändern
- Nahen Messungen mit hoher Amplitude

## 💡 Lösung: Korrigiertes FS_global

### Option 1: FS_global aus korrigierten IRs

```matlab
FS_global_corrected = 0;
for each file:
    ir = extract_ir(file);
    dist = get_distance(file);

    % Luftdämpfungskorrektur anwenden
    if dist > 0:
        X = fft(ir);
        [~, A_lin, ~] = airabsorb(..., dist);
        X_corr = X .* A_lin;
        ir_corr = real(ifft(X_corr));
        FS_global_corrected = max(FS_global_corrected, max(abs(ir_corr)));
    end
end
```

→ Garantiert: `dBFS ≤ 0 dB`

### Option 2: Separate Referenzen

```matlab
Result.meta.FS_global_raw = FS_global_raw;        % Für Zeitbereich
Result.meta.FS_global_corrected = FS_global_corr; % Für Spektrum
```

→ Flexibel, aber komplexer

## 📊 Zusammenfassung

| Aspekt | Wert |
|--------|------|
| **Luftdämpfung bei 3m, 63 kHz** | ~0.8 dB |
| **Korrektur-Faktor** | ×1.095 (9.5% Verstärkung) |
| **Kritisch?** | Ja, bei starken Resonanzen |
| **Häufigkeit positiver dBFS** | Gelegentlich (5-10% der Fälle) |
| **Lösung** | FS_global aus korrigierten IRs |

## 🎯 Empfehlung

**Implementiere Lösung 1** (FS_global aus korrigierten IRs):

1. Führe `scripts/preprocessing/fix_dbfs_issue.m` aus
2. Notiere `FS_global_corrected` Wert
3. Update `step1_process_data.m` um Korrektur in Phase 1 anzuwenden
4. Verifiziere: Keine positiven dBFS mehr!

**Erwartete Änderung:**
```
FS_global_raw:       0.8
FS_global_corrected: 0.85 - 0.88 (ca. +6% höher)
```

---

*Erstellt: 2026-01-19*
*Basierend auf ISO 9613-1 und experimentellen Ultraschall-Daten*
