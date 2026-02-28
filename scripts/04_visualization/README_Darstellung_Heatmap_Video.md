# Darstellung_Heatmap_Video.m

## Zweck
Erstellt Heatmap-Videos der zeitlichen Energieausbreitung.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `videoFPS`, `timeStep_ms`, `windowSize_ms`, `maxDuration_s`

## Ausgaben
- `Videos/Heatmap_<Variante>.mp4`
- Optionales Vergleichsvideo für zwei Varianten
- Werte sind in dBFS skaliert

## Nutzung
```matlab
run('scripts/04_visualization/Darstellung_Heatmap_Video.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- MATLAB VideoWriter
