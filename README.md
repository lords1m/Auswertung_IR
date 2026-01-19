# Akustik-Auswertung und Visualisierung (Ultraschall/Hochfrequenz)

Dieses Repository enthält eine Sammlung von MATLAB-Skripten zur Auswertung, Analyse und Visualisierung von Raumimpulsantworten (RIR). Der Fokus liegt auf hochauflösenden Messungen (500 kHz Abtastrate) und der Analyse im Ultraschallbereich (4 kHz bis 63 kHz).

Das Framework bietet sowohl eine interaktive GUI als auch Skripte für Batch-Export und physikalische Analysen (z. B. Pegelabfall über Entfernung).

## Ordnerstruktur

Die folgende Struktur wird für den reibungslosen Ablauf erwartet:

```text
Auswertung_IR/
├── dataraw/                      # Rohdaten (.mat Dateien der Messungen)
├── processed/                    # Verarbeitete Daten (Result-Structs)
├── functions/                    # Zentrale Hilfsfunktionen
│   ├── process_ir_modifications.m   # Zentrale IR-Modifikation mit Auto-Save
│   ├── init_repo_paths.m            # Repository-Pfad-Initialisierung
│   ├── truncate_ir.m                # IR-Truncation
│   ├── calc_terz_spectrum.m         # 1/3-Oktavband-Spektrum
│   ├── calc_rt60_spectrum.m         # Nachhallzeit-Berechnung
│   └── ...weitere Hilfsfunktionen
├── scripts/                      # Alle MATLAB Scripts (organisiert)
│   ├── preprocessing/            # Datenvorverarbeitung
│   │   └── step1_process_data.m      # Hauptverarbeitung: DC-Removal, Truncation, Spektrum
│   ├── analysis/                 # Physikalische Analysen
│   │   ├── Berechnung_Reflexionsfaktor_FFT.m  # FFT-basierte Reflexionsanalyse
│   │   ├── Analyse_Reflexionsgrad.m           # Frequenzabhängiger Reflexionsgrad
│   │   └── validate_calculations.m            # Validierung der Berechnungen
│   ├── visualization/            # Datenvisualisierung
│   │   ├── Darstellung_Heatmap_Video.m        # Energieausbreitungs-Videos
│   │   ├── Darstellung_Pegel_ueber_Entfernung.m # 1/r-Gesetz & 3D-Plots
│   │   ├── Visualize_Terzband_Filter.m        # Filterkurven-Visualisierung
│   │   └── Terzpegel_DBFs_einzeln.m           # Batch-Spektral-Plots
│   ├── tools/                    # Interaktive Tools
│   │   ├── interactive_plotter.m              # Haupt-GUI zur Analyse
│   │   └── Visual_Truncation_Tool.m           # Interaktives IR-Schnitt-Tool
│   └── export/                   # Export-Funktionen
│       ├── export_all_metrics.m               # Metriken-Export
│       └── export_all_plots.m                 # Plot-Export
├── archive/                      # Veraltete/alte Scripts
├── Plots/                        # (Auto-generiert) Exportierte Bilder
├── Videos/                       # (Auto-generiert) Heatmap-Videos
└── README.md                     # Diese Datei
```

##  Setup & Installation

1.  **Code herunterladen:**
    Lade das Repository als ZIP-Datei herunter oder klone es via Git:
    ```bash
    git clone https://github.com/DEIN_REPO_URL/Auswertung_IR.git
    ```

2.  **Voraussetzungen:**
    *   MATLAB (empfohlen: R2020b oder neuer).
    *   Signal Processing Toolbox.

3.  **Daten vorbereiten:**

    *   Lege die Rohmessungen (`.mat`) in den Ordner `dataraw/`.
    *   Stelle sicher, dass die Dateinamen dem Schema folgen (z. B. `Variante_1_Pos1.mat` oder `...Quelle...`), damit die Regex-Parser korrekt arbeiten.

4.  **Verarbeitung (Preprocessing):**
    *   Bevor die Visualisierungs-Tools genutzt werden können, müssen die Rohdaten verarbeitet werden (DC-Removal, Truncation, Spektrumberechnung).
    *   Führe das Skript `scripts/preprocessing/step1_process_data.m` aus:
        ```matlab
        cd /path/to/Auswertung_IR  % Zum Repository-Root wechseln
        run('scripts/preprocessing/step1_process_data.m')
        ```
    *   Das Script verarbeitet automatisch alle Dateien in `dataraw/` und speichert Ergebnisse in `processed/`.

**Hinweis:** Alle Scripts im `scripts/` Ordner navigieren automatisch zum Repository-Root, sodass relative Pfade (`dataraw`, `processed`, etc.) korrekt funktionieren.

##  Messaufbau & Positionen

Die Messungen wurden in einem definierten Raster durchgeführt. Für die Heatmap-Visualisierung (`interactive_plotter.m`) und die räumliche Zuordnung gilt folgendes 4x4-Layout:

| Y (m) \ X (m) | 0 | 0.3 | 0.6 | 1.2 |
| :--- | :---: | :---: | :---: | :---: |
| **1.2** | Pos 1 | Pos 2 | Pos 3 | Pos 4 |
| **0.6** | Pos 5 | Pos 6 | Pos 7 | Pos 8 |
| **0.3** | Pos 9 | Pos 10 | Pos 11 | Pos 12 |
| **0** | **Quelle (Q1)** | Pos 13 | Pos 14 | Pos 15 |

*   **Quelle (Q1):** Befindet sich an der Position unten links (Reihe 4, Spalte 1).
*   **Pos 1-15:** Mikrofonpositionen im Raum.

## Funktionsweise der Skripte

**Wichtig:** Starte Scripts entweder:
1. Direkt aus dem Repository-Root: `run('scripts/tools/interactive_plotter.m')`
2. Oder aus MATLAB File Browser (Scripts navigieren automatisch zum Root)

### 1. `scripts/tools/interactive_plotter.m` (Haupt-Tool)
Eine umfangreiche GUI zum explorativen Analysieren der Daten.
*   **Modi:** Einzelansicht oder Vergleich (Differenzbildung) zweier Messungen.
*   **Datenquellen:** Kann sowohl Rohdaten (`dataraw/`) als auch verarbeitete Daten (`processed/`) laden.
*   **Visualisierungen:**
    *   Frequenzspektrum (1/3-Oktave).
    *   Impulsantwort (Zeitbereich).
    *   ETC (Energy Time Curve) & EDC (Energy Decay Curve).
    *   Pegel über Entfernung (Scatter Plots).
    *   3D-Raum-Visualisierung.
    *   Raumzeit-Heatmap (mit Slider und Animation).
    *   Nachhallzeit (T30) über Frequenz.
*   **Export:** Ermöglicht das Speichern von Plots und Batch-Export(funktioniert noch nicht richtig) ganzer Varianten.

### 2. `scripts/visualization/Darstellung_Pegel_ueber_Entfernung.m`
Fokussiert auf die physikalische Ausbreitung des Schalls im Raum.
*   Vergleicht gemessene Pegel mit der idealen 1/r-Kurve (bzw. 1/r² für Energie)
*   Berechnet statistische Abweichungen (Standardabweichung vom Ideal)
*   Erstellt 2D- und 3D-Scatterplots der Messpositionen im Raum
*   Visualisiert Pfade und Differenzen zwischen verschiedenen Mess-Varianten

### 3. `scripts/visualization/Darstellung_Heatmap_Video.m`
Visualisiert die zeitliche Ausbreitung der Schallenergie.
*   Erstellt `.mp4`-Videos der Energieausbreitung
*   Zeigt 4x4-Raster der Messpositionen
*   Farbe repräsentiert aktuellen RMS-Pegel in kurzen Zeitfenstern
*   Nützlich für Analyse von Reflexionen und Raumakustik

### 4. `scripts/visualization/Terzpegel_DBFs_einzeln.m`
Skript für Stapelverarbeitung von Spektral-Plots.
*   Erstellt standardisierte `stairs`-Plots (Treppendiagramme)
*   Logarithmische X-Achsen oder Terzband-Indizes
*   Automatische Speicherung in `Plots/`

### 5. `scripts/tools/Visual_Truncation_Tool.m`
Interaktives Tool zum visuellen Schneiden von Impulsantworten.
*   Lädt .mat Dateien aus `dataraw/` oder `processed/`
*   Visualisiert IR im Zeitbereich
*   Verschiebbare Start- und End-Marker per Maus
*   Echtzeit-Berechnung von Pegel, RMS, Energie
*   Export der geschnittenen IR

### 6. `scripts/analysis/Berechnung_Reflexionsfaktor_FFT.m`
FFT-basierte Berechnung des frequenzabhängigen Reflexionsfaktors.
*   Lädt Direktschall- und Reflexions-IRs
*   Wendet Hanning-Fenster an (spektrale Leckage-Reduktion)
*   Berechnet FFT und Reflexionsfaktor R(f)
*   Berücksichtigt Weglängen und Luftdämpfung
*   Fokus auf Ultraschallbereich (4-63 kHz)

## Technische Details

### Signalverarbeitung

#### 1. DC-Offset Entfernung
**Was ist DC-Offset?**
DC-Offset (Gleichspannungsanteil) ist eine konstante Verschiebung des Signals von der Null-Linie, sodass der Mittelwert ≠ 0 ist. Dies verfälscht:
- RMS- und Energieberechnungen
- FFT-Analysen (Bias im Frequenzbereich)
- Visualisierungen

**Implementierung:**
Alle IRs werden durch die zentrale Funktion `process_ir_modifications()` verarbeitet:
```matlab
ir_clean = process_ir_modifications(ir_raw, 'RemoveDC', true, 'AutoSave', false);
```
Die Funktion subtrahiert den Mittelwert: `ir = ir - mean(ir)` und bietet optionale automatische Speicherung.

**Verwendung an:**
- `functions/truncate_ir.m:15` - Nach IR-Extraktion
- `scripts/analysis/Berechnung_Reflexionsfaktor_FFT.m:163` - Vor FFT-Analyse
- `scripts/tools/Visual_Truncation_Tool.m:332` - Beim Laden von Daten
- `scripts/tools/interactive_plotter.m` - Mehrere Stellen für konsistente Darstellung

#### 2. Hanning-Fenster (Windowing)
**Wo wird es angewendet?**
Das Hanning-Fenster wird **nur** bei der FFT-basierten Reflexionsfaktor-Berechnung verwendet (`scripts/analysis/Berechnung_Reflexionsfaktor_FFT.m:47-50`):

```matlab
win = hanning(N);
ir_dir_win = ir_dir .* win;
ir_ref_win = ir_ref .* win;
```

**Zweck:**
- Reduziert spektrale Leckage (Spectral Leakage) bei der FFT
- Glättet Übergänge am Anfang und Ende des Signals
- Verbessert Frequenzauflösung für präzise Reflexionsfaktor-Berechnung

**Nicht verwendet für:** Allgemeine IR-Verarbeitung, Energie-Berechnungen, oder Visualisierungen.

#### 3. Filterung

**Terzband-Filterung** (1/3-Oktave):
- **Ort:** `scripts/visualization/Visualize_Terzband_Filter.m:71,81`
- **Filter:** Butterworth Bandpass, **Ordnung 8**
- **Frequenzen:** 4 kHz bis 63 kHz (1/3-Oktav-Schritte)
- **Implementierung:** `filtfilt()` für Null-Phasen-Verzerrung

**RT60/T30-Berechnung:**
- **Ort:** `functions/calc_rt60_spectrum.m:29-31`
- **Filter:** Butterworth Bandpass, **Ordnung 4**
- **Zweck:** Frequenzselektive Nachhallzeit-Analyse

**Reflexionsanalyse:**
- **Ort:** `scripts/analysis/Analyse_Reflexionsgrad.m:78-81`
- **Filter:** Frequenzabhängiger Bandpass (±20% um Centerfrequenz)
- **Implementierung:** Butterworth 4. Ordnung

#### 4. Automatische Speicherung (Auto-Save)

Die neue zentrale Funktion `process_ir_modifications()` unterstützt automatisches Speichern:

```matlab
ir_clean = process_ir_modifications(ir, ...
    'RemoveDC', true, ...
    'AutoSave', true, ...
    'FilePath', 'processed/Time_XY.mat');
```

**Features:**
- Speichert IR automatisch bei jeder Modifikation
- Aktualisiert `last_modified` Timestamp
- Erstellt Verzeichnisse automatisch wenn nötig
- Erhält Result-Struct-Struktur

**Verwendung:** Kann in allen interaktiven Tools aktiviert werden für kontinuierliche Datensicherung.

### System-Parameter

*   **Abtastrate (fs):** Standardmäßig 500 kHz
*   **Frequenzbereich:** Terzbänder von **4 kHz bis 63 kHz**
*   **Metriken:**
    *   **dBFS:** Pegel relativ zu Full Scale
    *   **T30:** Nachhallzeit (Abfall -5 dB bis -35 dB)

## Namenskonventionen

Damit die Skripte die Positionen und Varianten korrekt zuordnen können, sollten Dateinamen idealerweise folgende Muster enthalten:
*   `...PosX...` oder `...Pos_X...` für Empfängerpositionen (z. B. `Pos1`, `Pos12`).
*   `...Quelle...` für Quellsignale.
*   Der Teil vor "Pos" wird meist als Varianten-Name interpretiert.

## Changelog & Updates

### 2026-01-19: Repository Refactoring
**Strukturverbesserungen:**
- ✅ **Neue Ordnerstruktur:** Alle Scripts in thematische Unterordner organisiert (`scripts/preprocessing/`, `scripts/analysis/`, `scripts/visualization/`, `scripts/tools/`, `scripts/export/`)
- ✅ **Zentrale IR-Modifikations-Funktion:** `process_ir_modifications()` ersetzt Code-Duplikate für DC-Removal
- ✅ **Auto-Save Funktionalität:** Automatische Speicherung von modifizierten IRs
- ✅ **Automatische Pfad-Initialisierung:** Alle Scripts navigieren automatisch zum Repository-Root
- ✅ **Verbesserte Dokumentation:** README komplett aktualisiert mit technischen Details zu DC-Offset, Hanning-Fenster, und Filterung
- ✅ **Code-Duplikate entfernt:** DC-Removal an 5+ Stellen durch zentrale Funktion ersetzt

**Technische Dokumentation:**
- 📖 DC-Offset Erklärung und Verwendung dokumentiert
- 📖 Hanning-Fenster: Wo und warum es verwendet wird
- 📖 Filterung: Übersicht aller Filter-Implementierungen (Terzband, RT60, Reflexion)
- 📖 Auto-Save: Wie man automatische Speicherung aktiviert

**Migrations-Hinweis:**
Alle Scripts verwenden jetzt relative Pfade vom Repository-Root. Alte Pfade werden automatisch aufgelöst.

---
*Erstellt für die Auswertung von Ultraschall-Raumimpulsantworten.*
