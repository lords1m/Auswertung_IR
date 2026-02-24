# Berechnung_Reflexionen.m

## Zweck
Berechnet Laufzeiten von Wandreflexionen für eine definierte Messposition.

## Eingaben
- `get_geometry` liefert die Positionen
- Konfiguration im Skript: `target_pos_id`, `c`, `wall_dist`

## Ausgaben
- Konsolenausgabe mit Direktschall und Reflexionslaufzeiten

## Nutzung
```matlab
run('scripts/03_analysis/Berechnung_Reflexionen.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `get_geometry`
