# Terzpegel_DBFs_einzeln.m

## Zweck
Erstellt Terzspektrum-Plots für ausgewählte Varianten und Positionen.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `messungen`, `selectedPositions`, `y_limits`

## Ausgaben
- `Plots/Terzpegel_<Variante>_Pos<id>.png`
- `Plots/Terzpegel_<Variante>_Pos<id>.fig`

## Nutzung
```matlab
run('scripts/04_visualization/Terzpegel_DBFs_einzeln.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
