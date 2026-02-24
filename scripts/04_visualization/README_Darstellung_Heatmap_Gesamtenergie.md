# Darstellung_Heatmap_Gesamtenergie.m

## Zweck
Erstellt eine statische Heatmap der Gesamtenergie pro Messpunkt.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `dataDir`, `outputDir`

## Ausgaben
- `Plots/Heatmap_Gesamtenergie_<Variante>.png`
- `Plots/Heatmap_Gesamtenergie_<Variante>.pdf`
- Werte sind in dBFS skaliert

## Nutzung
```matlab
run('scripts/04_visualization/Darstellung_Heatmap_Gesamtenergie.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
