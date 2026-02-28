# Visualize_Terzband_Filter.m

## Zweck
Visualisiert Terzband-Filter, Impulsantwort und Spektrum für eine gewählte Frequenz.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `selectedVariant`, `selectedPosition`, `selectedFrequency`

## Ausgaben
- Plot im Figure-Window
- `Plots/Filter_<Variante>_Pos<id>_f<freq>.png`
- `Plots/Filter_<Variante>_Pos<id>_f<freq>.fig`

## Nutzung
```matlab
run('scripts/04_visualization/Visualize_Terzband_Filter.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
