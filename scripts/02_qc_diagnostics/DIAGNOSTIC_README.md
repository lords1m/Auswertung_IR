# Diagnose positiver dBFS-Werte

## Zweck
Dieses Dokument beschreibt das Vorgehen mit `diagnose_dbfs_energy.m`.

## Kurzbeschreibung des Ablaufs
- FS_global bestimmen
- Terzband-Energien pro Datei berechnen
- Prüfen, ob `band_energy > FS_global^2`
- Zusammenfassung der Auffälligkeiten

## Ausführung
```matlab
run('scripts/02_qc_diagnostics/diagnose_dbfs_energy.m')
```

## Hinweise zur Interpretation
- Auffälligkeiten bei hohen Frequenzen können auf Resonanzen oder spektrale Konzentration hinweisen.
- Auffälligkeiten über alle Bänder können auf eine inkonsistente FS_global-Bestimmung hindeuten.
- Wenn keine Auffälligkeiten gefunden werden, liegt die Ursache vermutlich in einer anderen Berechnung oder Darstellung.
