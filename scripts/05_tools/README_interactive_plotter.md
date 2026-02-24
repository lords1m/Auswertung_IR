# interactive_plotter.m

## Zweck
Interaktive GUI zur Analyse von Impulsantworten und Spektren.

## Eingaben
- `dataraw/*.mat` oder `processed/Proc_*.mat`
- Auswahl im GUI

## Ausgaben
- Interaktive Plots
- Optionaler Plot-Export im GUI

## Nutzung
```matlab
run('scripts/05_tools/interactive_plotter.m')
```

## Hinweis
Im Spektrum-Plot gibt es eine Option, die Frequenzachse auf den Realmaßstab
des 1:20 Modells umzurechnen.

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
