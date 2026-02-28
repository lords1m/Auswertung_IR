# Positive dBFS-Werte: Ursache und Lösungen

##  Das Problem

In manchen Plots erscheinen **positive dBFS-Werte** (z.B. +2 dBFS, +5 dBFS), obwohl `FS_global` als das globale Maximum aller Impulsantworten definiert ist. Per Definition sollte dBFS (decibels relative to Full Scale) **niemals positiv** sein.

## ️ Ursache

### Schritt 1: FS_global wird berechnet (step1_process_data.m)

```matlab
FS_global = 0;
for i = 1:length(files)
    ir = extract_ir(S);
    FS_global = max(FS_global, max(abs(ir)));  // ← Maximum der RAW IRs
end
```

**Ergebnis:** `FS_global` = Maximum aller **unkorrigierten** Impulsantworten


### Schritt 2: Terzspektrum-Berechnung (calc_terz_spectrum.m)

```matlab
% Luftdämpfungskorrektur anwenden
if dist > 0
    [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T, LF, dist);
    X = X .* A_lin(:);  // ← VERSTÄRKT das Signal!
end

% ...später...
band_energy = sum(X_mag_sq(idx));
L_dBFS(k) = 10 * log10(band_energy / (FS_global^2 + eps));
```

**Problem:**
- `A_lin` ist die Luftdämpfungs-**Korrektur**: `A_lin = 10^(A_dB/20)`
- Für gedämpfte Frequenzen (Hochfrequenz) ist `A_dB > 0`, also `A_lin > 1`
- Das Signal wird **verstärkt**, um die Dämpfung zu kompensieren
- Nach der Verstärkung kann `band_energy > FS_global^2` sein
- Dann wird `log10(band_energy / FS_global^2) > 0` → **Positive dBFS!**


##  Beispiel

```
Gegeben:
- FS_global = 0.8 (Maximum aller RAW IRs)
- IR bei 3m Distanz, 40 kHz Band
- Luftdämpfung bei 40 kHz: ~15 dB

Luftdämpfungskorrektur:
- A_dB = 15 dB
- A_lin = 10^(15/20) ≈ 5.62
- X_corrected = X * 5.62  ← Verstärkung um Faktor 5.62!

Nach Korrektur:
- band_energy_corrected = 0.7²  (Beispiel)
- FS_global² = 0.8² = 0.64

dBFS-Berechnung:
- L_dBFS = 10 * log10(0.7²/0.64)
         = 10 * log10(0.49/0.64)
         = 10 * log10(0.765)
         = -1.16 dB   Negativ

ABER: Wenn band_energy_corrected = 0.85² = 0.7225 (nach starker Korrektur):
- L_dBFS = 10 * log10(0.7225/0.64)
         = 10 * log10(1.129)
         = +0.53 dB   POSITIV!
```


##  Lösungen

### **Lösung 1: FS_global aus korrigierten IRs berechnen**  EMPFOHLEN

**Konzept:** Berechne `FS_global` aus den **luftdämpfungs-korrigierten** IRs.

**Vorteile:**
-  Physikalisch korrekt
-  dBFS-Werte bleiben ≤ 0 dB
-  Referenz ist das "verstärkte" Signal

**Nachteile:**
- ️ Erfordert Änderung in step1_process_data.m
- ️ FS_global wird größer (mehr Verstärkung)

**Implementation:**

Ändere `step1_process_data.m` um auch die Luftdämpfungskorrektur anzuwenden:

```matlab
% Phase 1: Globaler Referenzpegel (mit Korrektur)
FS_global = 0;
for i = 1:length(files)
    ir = extract_ir(S);

    % Distanz ermitteln
    dist = get_distance_for_file(meta, geo);

    if dist > 0
        % FFT + Luftdämpfungskorrektur
        N_fft = 2^nextpow2(length(ir));
        X = fft(ir, N_fft);
        [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T, LF, dist);
        X_corrected = X .* A_lin(:);
        ir_corrected = real(ifft(X_corrected));
        ir_corrected = ir_corrected(1:length(ir));

        FS_global = max(FS_global, max(abs(ir_corrected)));
    else
        FS_global = max(FS_global, max(abs(ir)));
    end
end
```

**Test:** Führe `scripts/02_qc_diagnostics/fix_dbfs_issue.m` aus, um den korrekten Wert zu ermitteln.


### **Lösung 2: Keine Luftdämpfungskorrektur in calc_terz_spectrum**

**Konzept:** Entferne die Luftdämpfungskorrektur komplett.

**Vorteile:**
-  Einfach
-  FS_global bleibt gültig
-  dBFS-Werte bleiben ≤ 0 dB

**Nachteile:**
- ️ Spektrum zeigt gedämpfte Werte (nicht korrigiert)
- ️ Physikalisch weniger aussagekräftig

**Implementation:**

Entferne in `calc_terz_spectrum.m` die Zeilen 33-40:

```matlab
% --- Luftdämpfungskorrektur --- (ENTFERNT)
% if dist > 0
%     [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T, LF, dist);
%     X = X .* A_lin(:);
% end
```


### **Lösung 3: Clip dBFS-Werte auf 0 dB**

**Konzept:** Begrenze alle dBFS-Werte auf maximal 0 dB.

**Vorteile:**
-  Sehr einfach
-  Keine Änderungen am Workflow

**Nachteile:**
- ️ Versteckt das Problem nur
- ️ Informationsverlust (echte Werte werden abgeschnitten)
- ️ Physikalisch nicht korrekt

**Implementation:**

Ändere `calc_terz_spectrum.m:73`:

```matlab
L_dBFS(k) = min(0, 10 * log10(band_energy / (FS_global^2 + eps)));
%              ↑ Clip auf 0 dB
```

**Nicht empfohlen**, da es das Problem nur versteckt.


### **Lösung 4: Separate Referenz für korrigierte Spektren**

**Konzept:** Verwende zwei Referenzen:
- `FS_global_raw` für unkorrigierte IRs
- `FS_global_corrected` für korrigierte Spektren

**Vorteile:**
-  Beide Referenzen verfügbar
-  Flexibel

**Nachteile:**
- ️ Komplexer
- ️ Mehr Variablen zu verwalten

**Implementation:**

```matlab
% In step1_process_data.m
FS_global_raw = 0;
FS_global_corrected = 0;

for i = 1:length(files)
    % Raw
    FS_global_raw = max(FS_global_raw, max(abs(ir)));

    % Corrected
    if dist > 0
        ir_corr = apply_air_absorption_correction(ir, dist, fs, T, LF);
        FS_global_corrected = max(FS_global_corrected, max(abs(ir_corr)));
    else
        FS_global_corrected = max(FS_global_corrected, max(abs(ir)));
    end
end

% In calc_terz_spectrum: Verwende FS_global_corrected
```


##  Empfehlung

**Verwende Lösung 1: FS_global aus korrigierten IRs berechnen**

**Begründung:**
1.  **Physikalisch korrekt**: FS_global repräsentiert das tatsächlich verwendete Maximum
2.  **Keine Informationsverlust**: Alle Werte bleiben korrekt
3.  **Konsistent**: dBFS-Werte sind immer ≤ 0 dB
4.  **Transparent**: Nutzer versteht die Referenz

**Nächster Schritt:**
```bash
# 1. Teste aktuelles Problem
run('scripts/02_qc_diagnostics/fix_dbfs_issue.m')

# 2. Notiere FS_global_corrected Wert
# 3. Update step1_process_data.m mit Lösung 1
```


##  Hintergrund: Was ist dBFS?

**dBFS = decibels relative to Full Scale**

- Referenz: Maximum des digitalen Systems (Full Scale)
- Per Definition: **dBFS ≤ 0 dB**
  - 0 dBFS = Full Scale (Maximum)
  - -6 dBFS = Halbe Amplitude
  - -∞ dBFS = Null

**Warum niemals positiv?**
- Positive Werte würden "über Full Scale" bedeuten
- Im digitalen System würde das Clipping verursachen
- dBFS > 0 ist ein konzeptioneller Fehler


##  Weiterführende Informationen

### Luftdämpfung bei Ultraschall (40 kHz, 3m Distanz)

| Temperatur | Luftfeuchte | Dämpfung (dB) |
|------------|-------------|---------------|
| 20°C       | 50%         | ~15 dB        |
| 20°C       | 30%         | ~20 dB        |
| 25°C       | 50%         | ~13 dB        |

→ Hochfrequenzen werden stark gedämpft!
→ Korrektur verstärkt diese Frequenzen entsprechend

### Warum ist die Korrektur wichtig?

- Ohne Korrektur: Hochfrequenz-Spektrum zeigt zu niedrige Werte
- Mit Korrektur: Spektrum zeigt "was an der Quelle war"
- Wichtig für physikalische Analysen (Reflexion, Absorption, etc.)


*Erstellt: 2026-01-19*
*Autor: IR Processing Documentation*
