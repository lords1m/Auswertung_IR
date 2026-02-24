# Darstellung_Pegel_Differenzen_Grid.m

## Zweck
Zeigt Pegel und Pegeldifferenzen im Raumraster mit Verbindungspfaden.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- `processed/Proc_<Variante>_Quelle.mat` falls vorhanden
- Konfiguration im Skript: `connections`

## Ausgaben
- `Plots/Grid_Differenzen_<Variante>.png`

## Nutzung
```matlab
run('scripts/04_visualization/Darstellung_Pegel_Differenzen_Grid.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `get_geometry`
