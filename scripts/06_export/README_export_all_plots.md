# export_all_plots.m

## Zweck
Batch-Export von standardisierten Plots für alle Varianten und Positionen.

## Eingaben
- `processed/Proc_*.mat`
- Konfiguration im Skript: Ausgabeordner und Plot-Optionen

## Ausgaben
- Plotdateien im Zielordner (typisch `Plots/`)

## Nutzung
```matlab
run('scripts/06_export/export_all_plots.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
