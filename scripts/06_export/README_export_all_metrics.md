# export_all_metrics.m

## Zweck
Exportiert Pegel, Terzspektren und T30 aus `processed` in eine Excel-Datei.

## Eingaben
- `processed/Proc_*.mat`
- Konfiguration im Skript: `outputFile`

## Ausgaben
- `Gesamt_Export_Metrics.xlsx`

## Nutzung
```matlab
run('scripts/06_export/export_all_metrics.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `calc_rt60_spectrum` für Fallback-Berechnung
