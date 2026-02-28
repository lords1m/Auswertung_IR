# Analyse_Reflexionsgrad.m

## Zweck
Schätzt den Reflexionsgrad anhand einer Impulsantwort, Direktschall und erwarteter Reflexionszeit.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `target_variant`, `target_pos`, `center_freq`

## Ausgaben
- Plots und Konsolenausgabe zur Reflexionsanalyse

## Nutzung
```matlab
run('scripts/03_analysis/Analyse_Reflexionsgrad.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `get_geometry`
