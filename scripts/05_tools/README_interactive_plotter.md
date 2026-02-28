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

Im Spektrum-Plot koennen in `Messung 1` mehrere Dateien gleichzeitig in der
Liste markiert werden (Cmd/Ctrl-Klick), um mehrere Positionskurven in einem
Plot zu ueberlagern.

Die gleiche Mehrfachauswahl in `Messung 1` ist auch im RT60-Plot verfuegbar.

Im Plot `Pegel ueber Entfernung` kann zusaetzlich ein Positionsfilter gesetzt
werden, z. B. `13,14,15`, um nur bestimmte Pfadpositionen anzuzeigen.

Im RT60-Plot gibt es eine Checkbox `Durchschnitt anzeigen`, mit der die
Durchschnittskurve der aktuell dargestellten Variante ein- und ausgeblendet
wird.

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
