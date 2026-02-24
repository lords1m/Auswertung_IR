# compare_spread_1000_20000.m

## Zweck
Erstellt eine Tabelle zum Vergleich der Ausbreitung bei 1000 Hz und 20000 Hz
auf Basis von Result.freq.terz_dbfs fuer eine Variante.

## Eingaben
- `processed/Proc_<Variante>_Pos<id>.mat`
- Konfiguration im Skript: `variant`, `target_freqs`, `tolerance_pct`

## Ausgaben
- `exported_tables/Terzband_Vergleich_<Variante>_1000Hz_20000Hz.xlsx`
- `exported_tables/Terzband_Vergleich_<Variante>_1000Hz_20000Hz.csv`

## Nutzung
```matlab
run('scripts/06_export/compare_spread_1000_20000.m')
```

## Hinweis
Der Wert bei 1000 Hz wird aus der Impulsantwort berechnet, da dieses Band
nicht im gespeicherten Terzspektrum enthalten ist. Der 20000 Hz Wert wird
aus `Result.freq.terz_dbfs` entnommen.
