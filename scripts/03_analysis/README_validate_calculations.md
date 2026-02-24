# validate_calculations.m

## Zweck
Validiert verarbeitete Ergebnisdateien und meldet NaN, Inf und Ausreißer.

## Eingaben
- `processed/*.mat`
- `processed/Frequency_Domain/*.mat`

## Ausgaben
- Konsolenausgabe mit gefundenen Problemen

## Nutzung
```matlab
run('scripts/03_analysis/validate_calculations.m')
```
