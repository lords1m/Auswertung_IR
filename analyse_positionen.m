% Analyse: Welche Positionen existieren und warum positive dBFS?

clear; clc;

% Summary laden
fprintf('=== Analyse der Positionen und dBFS-Werte ===\n\n');

% Load summary
load('processed/Summary_Database.mat', 'summary_table');

fprintf('Gesamt-Anzahl Einträge: %d\n\n', height(summary_table));

% Zeige erste Zeilen
fprintf('Erste 10 Einträge:\n');
disp(summary_table(1:min(10, height(summary_table)), :));

% Analysiere Positionen
fprintf('\n--- Positions-Analyse ---\n');
unique_positions = unique(summary_table.Position);
fprintf('Anzahl eindeutige Positionen: %d\n', length(unique_positions));
fprintf('Positionen: ');
for i = 1:length(unique_positions)
    fprintf('%s ', unique_positions{i});
end
fprintf('\n\n');

% Analysiere numerische vs. nicht-numerische
numeric_pos = {};
non_numeric_pos = {};

for i = 1:length(unique_positions)
    pos = unique_positions{i};
    num = str2double(pos);
    if ~isnan(num) && num >= 1 && num <= 15
        numeric_pos{end+1} = pos;
    else
        non_numeric_pos{end+1} = pos;
    end
end

fprintf('Numerische Positionen (1-15): %d\n', length(numeric_pos));
fprintf('  → ');
for i = 1:length(numeric_pos)
    fprintf('%s ', numeric_pos{i});
end
fprintf('\n\n');

fprintf('Nicht-numerische / Außerhalb 1-15: %d\n', length(non_numeric_pos));
fprintf('  → ');
for i = 1:length(non_numeric_pos)
    fprintf('%s ', non_numeric_pos{i});
end
fprintf('\n\n');

% Analysiere Summenpegel
fprintf('--- Summenpegel-Analyse ---\n');

for v = 1:4
    var = sprintf('Variante_%d', v);
    mask = strcmp(summary_table.Variante, var);
    subset = summary_table(mask, :);

    fprintf('\n%s (%d Positionen):\n', var, height(subset));

    % Numerische Positionen
    mask_num = false(height(subset), 1);
    for i = 1:height(subset)
        pos = subset.Position{i};
        num = str2double(pos);
        if ~isnan(num) && num >= 1 && num <= 15
            mask_num(i) = true;
        end
    end

    numeric_subset = subset(mask_num, :);
    non_numeric_subset = subset(~mask_num, :);

    fprintf('  Numerisch (1-15): %d Positionen\n', height(numeric_subset));
    if height(numeric_subset) > 0
        avg_numeric = mean(numeric_subset.SumLevel);
        fprintf('    Durchschnitt: %.2f dB FS\n', avg_numeric);
        fprintf('    Min: %.2f dB FS, Max: %.2f dB FS\n', ...
            min(numeric_subset.SumLevel), max(numeric_subset.SumLevel));
    end

    fprintf('  Nicht-numerisch / >15: %d Positionen\n', height(non_numeric_subset));
    if height(non_numeric_subset) > 0
        avg_non_numeric = mean(non_numeric_subset.SumLevel);
        fprintf('    Durchschnitt: %.2f dB FS\n', avg_non_numeric);
        fprintf('    Min: %.2f dB FS, Max: %.2f dB FS\n', ...
            min(non_numeric_subset.SumLevel), max(non_numeric_subset.SumLevel));
        fprintf('    Positionen: ');
        for i = 1:height(non_numeric_subset)
            fprintf('%s(%.1f dB) ', non_numeric_subset.Position{i}, non_numeric_subset.SumLevel(i));
        end
        fprintf('\n');
    end
end

fprintf('\n--- FS_global Analyse ---\n');
% Lade eine Result-Datei um FS_global zu sehen
result_files = dir('processed/Proc_*.mat');
if ~isempty(result_files)
    first_file = fullfile('processed', result_files(1).name);
    tmp = load(first_file);
    if isfield(tmp, 'Result') && isfield(tmp.Result.meta, 'FS_global_used')
        fprintf('FS_global_used: %.5f\n', tmp.Result.meta.FS_global_used);
    end
end

fprintf('\n=== SCHLUSSFOLGERUNG ===\n');
fprintf('Problem: Es gibt %d zusätzliche Positionen über die erwarteten 15 hinaus!\n', ...
    length(non_numeric_pos));
fprintf('Diese Positionen könnten:\n');
fprintf('  1. dist=0 haben (nicht in Geometrie)\n');
fprintf('  2. Keine Luftdämpfungs-Korrektur erhalten\n');
fprintf('  3. Höhere Summenpegel haben\n');
fprintf('  4. Den Average-Wert nach oben treiben\n\n');

fprintf('Empfehlung:\n');
fprintf('  Option A: Aus Average ausschließen (nur Pos 1-15 verwenden)\n');
fprintf('  Option B: Geometrie erweitern (Positionen Z1, Z2, etc. hinzufügen)\n');
fprintf('  Option C: Dateien entfernen (falls Testdaten)\n');
