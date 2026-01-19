%% Quick Fix: Zeige bisherige Ergebnisse aus der Konsolen-Ausgabe
% Falls das Script vorher abgebrochen ist

fprintf('=== WICHTIGE ERKENNTNIS ===\n\n');
fprintf('Aus der Fehler-Ausgabe sehen wir:\n');
fprintf('  "Bin 5: f=11169.4 Hz, E=910.6122719236 (3.7%% der Band-Energie)"\n\n');
fprintf('Das bedeutet:\n');
fprintf('  1. Es wurden VERLETZUNGEN gefunden! ✓\n');
fprintf('  2. Das Script war in Phase 4 (detaillierte Analyse)\n');
fprintf('  3. Die Frequenz 11169.4 Hz liegt im 10 kHz Terzband\n');
fprintf('  4. NICHT bei hohen Frequenzen (40-63 kHz)!\n\n');
fprintf('→ Das deutet auf ein ANDERES Problem hin als Luftdämpfung/Resonanzen\n\n');
fprintf('Nächster Schritt:\n');
fprintf('  Führe das Script erneut aus (Fehler ist behoben):\n');
fprintf('  run(''scripts/preprocessing/diagnose_dbfs_energy.m'')\n\n');
