# step1_process_data.m

## Zweck
Verarbeitet alle Rohdaten in `dataraw` und erzeugt standardisierte Ergebnisdateien in `processed`.

## Eingaben
- `dataraw/*.mat`
- Konfiguration im Skript: `fs`, `use_fixed_length`, `fixed_duration_s`

## Verarbeitung
- IR extrahieren
- DC-Removal und Truncation
- FS_global bestimmen
- Terzspektren und T30 berechnen
- Ergebnisstrukturen schreiben

## Ausgaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- `processed/Proc_<Variante>_Quelle.mat` falls vorhanden
- `processed/Time_Domain/Time_*.mat`
- `processed/Frequency_Domain/Spec_*.mat`
- `processed/Summary.xlsx`
- `processed/Proc_<Variante>_Average.mat`

## Nutzung
```matlab
run('scripts/00_pipeline/step1_process_data.m')
```

## Abhängigkeiten
- `functions/` im MATLAB-Pfad
- `get_geometry`, `load_and_parse_file`, `extract_ir`, `truncate_ir`, `calc_terz_spectrum`, `calc_rt60_spectrum`
