# Darstellung_Pfade_Vergleich.m

## Zweck
Vergleicht Leq-Werte entlang definierter Pfade für mehrere Varianten.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `pfade`, `pfade_auswahl`, `varianten_auswahl`

## Ausgaben
- `Plots/Pfadvergleich_<id>.png`
- Konsolenausgabe mit Summenpegeln pro Pfad

## Nutzung
```matlab
run('scripts/04_visualization/Darstellung_Pfade_Vergleich.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
