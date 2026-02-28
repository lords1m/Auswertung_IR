# diagnose_dbfs_energy.m

## Zweck
Findet positive dBFS-Werte, indem Bandenergien gegen `FS_global` geprüft werden.

## Eingaben
- `dataraw/*.mat`
- Parameter für Temperatur und Luftfeuchte aus den Dateien, falls vorhanden

## Ausgaben
- Konsolenausgabe mit gefundenen Verletzungen und Zusammenfassung

## Nutzung
```matlab
run('scripts/02_qc_diagnostics/diagnose_dbfs_energy.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `load_and_parse_file`, `extract_ir`, `truncate_ir`, `calc_terz_spectrum`, `airabsorb`
