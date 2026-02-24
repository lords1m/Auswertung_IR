# Darstellung_Pegel_ueber_Entfernung.m

## Zweck
Vergleicht Pegel über Entfernung mit einer idealen 1/r Kurve und erzeugt mehrere Plots.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `varianten`, `analyse_modus`, `darstellung_modus`

## Ausgaben
- Mehrere Plots im aktuellen Figure-Window
- Optionaler Dateiexport, falls aktiviert

## Nutzung
```matlab
run('scripts/04_visualization/Darstellung_Pegel_ueber_Entfernung.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
