# Akustik-Auswertung und Visualisierung (Ultraschall/Hochfrequenz)

Dieses Repository enthält eine Sammlung von MATLAB-Skripten zur Auswertung, Analyse und Visualisierung von Raumimpulsantworten (RIR). Der Fokus liegt auf hochauflösenden Messungen (500 kHz Abtastrate) und der Analyse im Ultraschallbereich (4 kHz bis 63 kHz).

Das Framework bietet sowohl eine interaktive GUI als auch Skripte für Batch-Export und physikalische Analysen (z. B. Pegelabfall über Entfernung).

## Ordnerstruktur

Die folgende Struktur wird für den reibungslosen Ablauf erwartet:

```text
Auswertung_IR/
├── dataraw/                  # Rohdaten (.mat Dateien der Messungen)
├── processed/             # Verarbeitete Daten (Result-Structs, wird automatisch generiert durch Step 1)
├── functions/             # Hilfsfunktionen (z.B. Terz-Berechnung, IR-Truncation)
├── Plots/                 # (Automatisch erstellt) Speicherort für exportierte Bilder
├── Videos/                # (Automatisch erstellt) Speicherort für Heatmap-Videos
│
├── interactive_plotter.m            # Haupt-GUI zur Analyse und zum Vergleich
├── Darstellung_Pegel_ueber_Entfernung.m # Analyse des 1/r-Gesetzes und 3D-Raum-Plots
├── Darstellung_Heatmap_Video.m      # Erstellt Videos der Energieausbreitung
├── Terzpegel_DBFs_einzeln.m         # Batch-Plotter für Terzspektren
├── Visualize_Terzband_Filter.m      # Darstellung der angewanten Filterkurven
└── README.md                        # Diese Datei
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
    *   Führe hierfür das Skript `step1_process_data.m` (falls vorhanden) aus, um die Dateien im Ordner `processed/` zu generieren.

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

### 1. `interactive_plotter.m` (Haupt-Tool)
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

### 2. `Darstellung_Pegel_ueber_Entfernung.m`
Fokussiert auf die physikalische Ausbreitung des Schalls im Raum.
*   Vergleicht gemessene Pegel mit der idealen 1/r-Kurve (bzw. 1/r² für Energie).
*   Berechnet statistische Abweichungen (Standardabweichung vom Ideal).
*   Erstellt 2D- und 3D-Scatterplots, die die Messpositionen im Raum zeigen.
*   Visualisiert Pfade und Differenzen zwischen verschiedenen Mess-Varianten.

### 3. `Darstellung_Heatmap_Video.m`
Visualisiert die zeitliche Ausbreitung der Schallenergie.
*   Erstellt `.mp4`-Videos.
*   Zeigt ein 4x4-Raster (oder definiertes Layout) der Messpositionen.
*   Die Farbe repräsentiert den aktuellen RMS-Pegel in einem kurzen Zeitfenster.

### 4. `Terzpegel_DBFs_einzeln.m`
Ein Skript für die Stapelverarbeitung von Spektral-Plots.
*   Erstellt standardisierte `stairs`-Plots (Treppendiagramme) für ausgewählte Positionen.
*   Nutzt logarithmische X-Achsen oder Terzband-Indizes.
*   Speichert die Ergebnisse automatisch in `Plots/`.

## Technische Details

*   **Abtastrate (fs):** Standardmäßig 500 kHz.
*   **Frequenzbereich:** Die Analysen konzentrieren sich auf Terzbänder von **4 kHz bis 63 kHz**.
*   **Filterung:** Es werden Butterworth-Bandpassfilter (Ordnung 8) für die Frequenzanalyse und T30-Berechnung verwendet.
*   **Metriken:**
    *   **dBFS:** Pegel relativ zu Full Scale.
    *   **T30:** Nachhallzeit basierend auf dem Abfall von -5 dB auf -35 dB der Schroeder-Integralen.

## Namenskonventionen

Damit die Skripte die Positionen und Varianten korrekt zuordnen können, sollten Dateinamen idealerweise folgende Muster enthalten:
*   `...PosX...` oder `...Pos_X...` für Empfängerpositionen (z. B. `Pos1`, `Pos12`).
*   `...Quelle...` für Quellsignale.
*   Der Teil vor "Pos" wird meist als Varianten-Name interpretiert.

---
*Erstellt für die Auswertung von Ultraschall-Raumimpulsantworten.*
