# Berechnung_Reflexionsfaktor_FFT.m

## Zweck
Berechnet den frequenzabhängigen Reflexionsfaktor aus Direktschall und Reflexion per FFT.

## Eingaben
- `processed` Daten oder Rohdaten gemäß Skriptkonfiguration
- Konfiguration im Skript für Dateipfade, Fensterung und Dämpfungskorrektur

## Ausgaben
- Plots und numerische Ergebnisse für den Reflexionsfaktor

## Nutzung
```matlab
run('scripts/03_analysis/Berechnung_Reflexionsfaktor_FFT.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `airabsorb`, `truncate_ir`, `process_ir_modifications`
