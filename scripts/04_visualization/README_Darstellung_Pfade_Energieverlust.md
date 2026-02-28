# Darstellung_Pfade_Energieverlust.m

## Zweck
Visualisiert Energieverluste entlang von Pfaden von der Quelle zu den Messpunkten.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `outputDir`

## Ausgaben
- `Plots/Pfade_Energieverlust_<Variante>.png`
- `Plots/Pfade_Energieverlust_3D_<Variante>.png`

## Nutzung
```matlab
run('scripts/04_visualization/Darstellung_Pfade_Energieverlust.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `get_geometry`
