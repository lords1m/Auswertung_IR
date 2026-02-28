# IR Processing Overview - Übersicht aller IR-Verarbeitungsschritte

Dieses Dokument beschreibt alle Funktionen, die eine Impulsantwort (IR) direkt verändern, in der Reihenfolge, in der sie typischerweise angewendet werden.


##  Verarbeitungsreihenfolge

```
Rohdaten (.mat)
    ↓
[1] extract_ir()          → Extrahiert IR aus Struct
    ↓
[2] DC-Removal            → Entfernt Gleichspannungsanteil (process_ir_modifications)
    ↓
[3] Truncation            → Schneidet Start/Ende (truncate_ir)
    ↓
[4] Normalisierung        → Optional: Normalisiert Amplitude (process_ir_pipeline)
    ↓
[5] Windowing             → Optional: Fensterung für FFT (process_ir_pipeline)
    ↓
[6] Filterung             → Optional: Frequenzselektion (process_ir_pipeline)
    ↓
Verarbeitete IR
    ↓
[7] Auto-Save             → Speichert in .mat (process_ir_modifications)
```


##  Detaillierte Beschreibung der Schritte

### 1. IR-Extraktion

**Funktion:** `extract_ir(S)`

**Zweck:** Extrahiert die Impulsantwort aus einem MATLAB-Struct (aus .mat Datei)

**Parameter:**
- `S` - MATLAB Struct aus Rohdaten-Datei

**Rückgabe:**
- `ir` - Extrahierte Impulsantwort als Vektor

**Ort:** `functions/extract_ir.m`

**Verwendung:**
```matlab
S = load('dataraw/Variante_1_Pos1.mat');
ir_raw = extract_ir(S);
```

**Änderungen an IR:** Konvertiert zu double, macht Spaltenvektor


### 2. DC-Offset Entfernung

**Funktion:** `process_ir_modifications(ir, 'RemoveDC', true)`

**Zweck:** Entfernt den Gleichspannungsanteil (DC-Offset) vom Signal

**Was ist DC-Offset?**
- Konstante Verschiebung des Signals von der Null-Linie
- Mittelwert ≠ 0
- Verfälscht RMS, Energie, FFT

**Operation:** `ir_clean = ir - mean(ir)`

**Parameter:**
- `ir` - Eingabe-Impulsantwort
- `'RemoveDC'` - Boolean (default: true)
- `'AutoSave'` - Optional: Automatisch speichern
- `'FilePath'` - Optional: Pfad für Auto-Save

**Rückgabe:**
- `ir_out` - IR ohne DC-Offset

**Ort:** `functions/process_ir_modifications.m`

**Verwendung:**
```matlab
% Einfach
ir_clean = process_ir_modifications(ir_raw, 'RemoveDC', true);

% Mit Auto-Save
ir_clean = process_ir_modifications(ir_raw, ...
    'RemoveDC', true, ...
    'AutoSave', true, ...
    'FilePath', 'processed/IR_01.mat');
```

**Änderungen an IR:** Subtrahiert Mittelwert von allen Samples

**Integriert in:** `truncate_ir()` (wird automatisch aufgerufen)


### 3. Truncation (Zuschneiden)

**Funktion:** `truncate_ir(ir, fixed_length_samples)`

**Zweck:** Findet Anfang und Ende der Impulsantwort, schneidet Rauschen ab

**Algorithmus:**
1. **DC-Removal** (automatisch via `process_ir_modifications`)
2. **Start finden:** Rückwärtssuche vom Peak (2% Threshold)
3. **Pre-Roll:** 250 Samples vor Start hinzufügen
4. **Ende finden:**
   - Modus 1 (fixed_length > 0): Feste Länge mit Zero-Padding
   - Modus 2 (fixed_length = 0): Dynamisch anhand Rauschpegel

**Parameter:**
- `ir` - Eingabe-IR (Roh oder DC-entfernt)
- `fixed_length_samples` - 0 für dynamisch, >0 für feste Länge

**Rückgabe:**
- `ir_trunc` - Zugeschnittene IR
- `metrics` - Struct mit:
  - `idx_start`, `idx_end` - Start/End-Indizes
  - `snr_db` - Signal-Rausch-Verhältnis
  - `energy`, `energy_total`, `energy_share` - Energie-Metriken

**Ort:** `functions/truncate_ir.m:1-87`

**Verwendung:**
```matlab
% Dynamische Länge
[ir_trunc, metrics] = truncate_ir(ir_raw, 0);

% Feste Länge: 30ms bei 500kHz = 15000 Samples
[ir_trunc, metrics] = truncate_ir(ir_raw, 15000);
```

**Änderungen an IR:**
- Entfernt DC-Offset
- Schneidet Start/Ende
- Optional: Zero-Padding bei fester Länge


### 4. Normalisierung (Optional)

**Funktion:** `process_ir_pipeline(..., 'Normalize', true)`

**Zweck:** Skaliert IR auf definierte Maximal-Amplitude

**Operation:** `ir_norm = ir * (target / max(abs(ir)))`

**Parameter:**
- `'Normalize'` - Boolean (default: false)
- `'NormalizeTo'` - Ziel-Amplitude (default: 1.0)

**Rückgabe:**
- IR mit normalisierter Amplitude

**Ort:** `functions/process_ir_pipeline.m` (Schritt 3)

**Verwendung:**
```matlab
[ir_out, info] = process_ir_pipeline(ir_raw, ...
    'Normalize', true, ...
    'NormalizeTo', 1.0);

% Normalisierungsfaktor abrufen:
fprintf('Faktor: %.6f\n', info.normalization_factor);
```

**Änderungen an IR:** Multipliziert alle Samples mit Normalisierungsfaktor

**Wann verwenden?**
- Vergleich verschiedener IRs
- Vor FFT-Analysen
- Export für andere Software


### 5. Windowing (Optional)

**Funktionen:**
- `hanning(N)`, `hamming(N)`, `blackman(N)`, `bartlett(N)`
- `process_ir_pipeline(..., 'Window', 'hanning')`

**Zweck:** Fensterung zur Reduktion spektraler Leckage bei FFT

**Was ist Windowing?**
- Multipliziert Signal mit Fensterfunktion
- Glättet Übergänge an Start/Ende
- Verbessert Frequenzauflösung bei FFT

**Fenstertypen:**
- **Hanning:** Standard, gute Balance (verwendet für Reflexionsfaktor-FFT)
- **Hamming:** Ähnlich wie Hanning, weniger Leckage
- **Blackman:** Sehr wenig Leckage, breitere Hauptkeule
- **Bartlett:** Dreieck-Fenster, einfach

**Parameter:**
- `'Window'` - 'none', 'hanning', 'hamming', 'blackman', 'bartlett'

**Rückgabe:**
- Gefensterte IR

**Ort:**
- Direkt: MATLAB built-in `hanning(N)`
- Pipeline: `functions/process_ir_pipeline.m` (Schritt 4)
- Anwendung: `scripts/03_analysis/Berechnung_Reflexionsfaktor_FFT.m:47-50`

**Verwendung:**
```matlab
% Manuell
N = length(ir);
win = hanning(N);
ir_windowed = ir .* win;

% Via Pipeline
[ir_out, info] = process_ir_pipeline(ir_raw, ...
    'Window', 'hanning', ...
    'Truncate', false);  % Keine Truncation für FFT!
```

**Änderungen an IR:** Element-weise Multiplikation mit Fensterfunktion

**Wann verwenden?**
- **JA:** FFT-basierte Analysen (Reflexionsfaktor, Spektrum)
- **NEIN:** Energie-Berechnungen, RT60-Analyse, Zeitbereich-Plots


### 6. Filterung (Optional)

**Funktionen:**
- `butter()` + `filtfilt()`
- `process_ir_pipeline(..., 'Filter', true)`

**Zweck:** Frequenzselektive Filterung für Teilband-Analysen

**Filtertypen:**
- **Bandpass:** Lässt Frequenzband durch (z.B. 8-16 kHz)
- **Lowpass:** Lässt tiefe Frequenzen durch
- **Highpass:** Lässt hohe Frequenzen durch

**Häufig verwendete Filter im Projekt:**

#### 6.1 Terzband-Filterung (1/3-Oktave)
- **Ort:** `scripts/04_visualization/Visualize_Terzband_Filter.m:71,81`
- **Filter:** Butterworth Bandpass, Ordnung 8
- **Frequenzen:** 4 kHz - 63 kHz (Terzband-Schritte)
- **Code:**
  ```matlab
  [b, a] = butter(4, [f_low f_high]/(fs/2), 'bandpass');
  ir_filtered = filtfilt(b, a, ir);
  ```

#### 6.2 RT60/T30-Filterung
- **Ort:** `functions/calc_rt60_spectrum.m:29-31`
- **Filter:** Butterworth Bandpass, Ordnung 4
- **Zweck:** Frequenzselektive Nachhallzeit-Berechnung

#### 6.3 Reflexionsanalyse-Filterung
- **Ort:** `scripts/03_analysis/Analyse_Reflexionsgrad.m:78-81`
- **Filter:** Butterworth Bandpass, Ordnung 4
- **Frequenzen:** ±20% um Center-Frequenz

**Parameter (via Pipeline):**
- `'Filter'` - Boolean (default: false)
- `'FilterType'` - 'bandpass', 'lowpass', 'highpass'
- `'FilterOrder'` - Filter-Ordnung (default: 4)
- `'FilterFreq'` - [f_low f_high] oder [f_cutoff]
- `'SamplingRate'` - fs in Hz (default: 500000)

**Rückgabe:**
- Gefilterte IR (nur gewünschter Frequenzbereich)

**Ort:** `functions/process_ir_pipeline.m` (Schritt 5)

**Verwendung:**
```matlab
% Terzband 8-16 kHz
[ir_terz, info] = process_ir_pipeline(ir_raw, ...
    'Filter', true, ...
    'FilterType', 'bandpass', ...
    'FilterFreq', [8000 16000], ...
    'FilterOrder', 8, ...
    'SamplingRate', 500e3);
```

**Änderungen an IR:** Konvolution mit Filter-Koeffizienten (via `filtfilt` = Null-Phasen)

**Wann verwenden?**
- Terzband-Analyse
- Frequenzabhängige RT60-Berechnung
- Reflexionsgrad-Analyse
- **NICHT** für Full-Band Energie oder Zeitbereich-Analysen


### 7. Auto-Save (Optional)

**Funktion:** `process_ir_modifications(..., 'AutoSave', true)` oder `process_ir_pipeline(..., 'AutoSave', true)`

**Zweck:** Automatisches Speichern der verarbeiteten IR

**Features:**
- Speichert in Result-Struct-Format
- Aktualisiert `last_modified` Timestamp
- Erstellt Verzeichnisse automatisch
- Erhält bestehende Metadaten

**Parameter:**
- `'AutoSave'` - Boolean (default: false)
- `'SavePath'` - Pfad zur .mat Datei (erforderlich)
- `'VarName'` - Variable-Name (default: 'Result')

**Ort:**
- `functions/process_ir_modifications.m`
- `functions/process_ir_pipeline.m` (Schritt 6)

**Verwendung:**
```matlab
ir_out = process_ir_modifications(ir, ...
    'RemoveDC', true, ...
    'AutoSave', true, ...
    'FilePath', 'processed/IR_Pos1.mat');
```

**Gespeicherte Struktur:**
```matlab
Result.ir                  % Verarbeitete IR
Result.pipeline_info       % Verarbeitungsschritte-Info
Result.created             % Erstellungsdatum
Result.last_modified       % Letzte Änderung
```


##  Verwendungsszenarien

### Szenario 1: Standard-Preprocessing (für Analyse-Tools)
```matlab
% Schritt 1: Extraktion
S = load('dataraw/Variante_1_Pos1.mat');
ir_raw = extract_ir(S);

% Schritt 2-3: DC-Removal + Truncation (automatisch)
[ir_processed, metrics] = truncate_ir(ir_raw, 0);

% → Verwendung in: step1_process_data.m, Visual_Truncation_Tool.m
```

### Szenario 2: FFT-Reflexionsfaktor-Analyse
```matlab
% Keine Truncation, Hanning-Fenster
[ir_fft, info] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', false, ...
    'Window', 'hanning');

% → Verwendung in: Berechnung_Reflexionsfaktor_FFT.m
```

### Szenario 3: Terzband-Analyse (spezifisches Band)
```matlab
% DC-Removal + Truncation + Bandpass
[ir_terz, info] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', true, ...
    'Filter', true, ...
    'FilterType', 'bandpass', ...
    'FilterFreq', [8000 16000], ...
    'FilterOrder', 8);

% → Verwendung in: Visualize_Terzband_Filter.m, calc_terz_spectrum.m
```

### Szenario 4: Vollständig mit Auto-Save
```matlab
% Alle Schritte + Normalisierung + Speichern
[ir_final, info] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', true, ...
    'TruncateLength', 15000, ...
    'Normalize', true, ...
    'AutoSave', true, ...
    'SavePath', 'processed/IR_Final.mat');
```


##  Funktionsreferenz

| Funktion | Datei | Zeile | Zweck |
|----------|-------|-------|-------|
| `extract_ir()` | `functions/extract_ir.m` | 1-10 | IR aus Struct extrahieren |
| `process_ir_modifications()` | `functions/process_ir_modifications.m` | 1-130 | DC-Removal + Auto-Save |
| `truncate_ir()` | `functions/truncate_ir.m` | 1-87 | Start/Ende finden + zuschneiden |
| `process_ir_pipeline()` | `functions/process_ir_pipeline.m` | 1-350 | Zentrale Pipeline (alle Schritte) |
| `calc_terz_spectrum()` | `functions/calc_terz_spectrum.m` | - | Terzspektrum (intern gefiltert) |
| `calc_rt60_spectrum()` | `functions/calc_rt60_spectrum.m` | - | RT60 (intern gefiltert) |


##  Siehe auch

- **Beispiel-Skript:** `scripts/99_examples/example_ir_processing_pipeline.m`
- **README:** Technische Details zu DC-Offset, Hanning, Filterung
- **Main Preprocessing:** `scripts/00_pipeline/step1_process_data.m`


*Zuletzt aktualisiert: 2026-01-19*
