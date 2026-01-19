%% Datenverarbeitung (Step 1)
% Liest Rohdaten, berechnet Metriken und speichert Ergebnisse.

clear; clc; close all;

% Repository-Pfade initialisieren (navigiert zum Root)
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions'); 

% Config
dataDir = 'dataraw';
procDir = 'processed';
fs = 500e3; % Abtastrate
use_fixed_length = true; % Setze auf true für feste Länge aller IRs
fixed_duration_s = 0.03;  % Gewünschte Länge in Sekunden (z.B. 0.2s = 100k Samples)

fprintf('=== Step 1: Datenverarbeitung gestartet ===\n');
fprintf('Konfiguration:\n');
fprintf('  - Rohdaten-Ordner: %s\n', dataDir);
fprintf('  - Ausgabe-Ordner: %s\n', procDir);
fprintf('  - Abtastrate: %.0f Hz\n', fs);

if ~exist(dataDir, 'dir'), error('Ordner "data" fehlt!'); end
if ~exist(procDir, 'dir')
    fprintf('Erstelle Ausgabe-Ordner: %s\n', procDir);
    mkdir(procDir);
end

dirTime = fullfile(procDir, 'Time_Domain');
dirFreq = fullfile(procDir, 'Frequency_Domain');
if ~exist(dirTime, 'dir')
    fprintf('Erstelle Unterordner: %s\n', dirTime);
    mkdir(dirTime);
end
if ~exist(dirFreq, 'dir')
    fprintf('Erstelle Unterordner: %s\n', dirFreq);
    mkdir(dirFreq);
end

% 1. Globale Referenz ermitteln
files = dir(fullfile(dataDir, '*.mat'));
fprintf('\n--- Phase 1: Ermittle globalen Referenzpegel ---\n');
fprintf('Anzahl gefundene Dateien: %d\n', length(files));

FS_global = 0;
valid_count = 0;
skipped_files = 0;

for i = 1:length(files)
    try
        filepath = fullfile(files(i).folder, files(i).name);
        [S, meta] = load_and_parse_file(filepath);  % Parse Metadaten
        ir = extract_ir(S);

        if ~isempty(ir)
            % Alle Messungen sind Receiver (Szenario B: Keine Quelle)
            valid_count = valid_count + 1;
            FS_global = max(FS_global, max(abs(ir)));
        else
            skipped_files = skipped_files + 1;
        end
    catch ME
        fprintf('  [!] Fehler beim Laden von %s: %s\n', files(i).name, ME.message);
        skipped_files = skipped_files + 1;
    end
end

if FS_global == 0, FS_global = 1; end
fprintf('Globaler Referenzpegel (FS_global): %.5f\n', FS_global);
fprintf('  Berechnet aus: %d Messungen\n', valid_count);
if skipped_files > 0
    fprintf('  Übersprungen: %d Dateien (Fehler oder keine IR)\n', skipped_files);
end

% Geometrie laden für Distanzberechnung
fprintf('\n--- Phase 2: Lade Geometriedaten ---\n');
geo = get_geometry();
fprintf('Geometriedaten geladen: %d Positionen definiert\n', length(geo));

% 2. Verarbeitung
fprintf('\n--- Phase 3: Verarbeite einzelne Dateien ---\n');
summary_data = {};
processed_count = 0;
skipped_count = 0; 

for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);

    fprintf('\n[%d/%d] Verarbeite: %s\n', i, length(files), files(i).name);

    % Parse
    [S, meta] = load_and_parse_file(filepath);

    if isempty(S) || isempty(meta.variante)
        fprintf('  [SKIP] Datei konnte nicht geparst werden oder keine Variante erkannt\n');
        skipped_count = skipped_count + 1;
        continue;
    end

    fprintf('  - Variante: %s\n', meta.variante);
    fprintf('  - Typ: %s\n', meta.type);
    fprintf('  - Position: %s\n', meta.position);
    
    % Umgebungsparameter auslesen (Defaults: 20°C, 50%)
    T_val = 20;
    LF_val = 50;
    if isfield(S, 'T') && ~isempty(S.T), T_val = mean(S.T); end
    if isfield(S, 'Lf') && ~isempty(S.Lf)
        LF_val = mean(S.Lf);
    elseif isfield(S, 'LF') && ~isempty(S.LF)
        LF_val = mean(S.LF);
    end
    fprintf('  - Temperatur: %.1f°C, Luftfeuchte: %.1f%%\n', T_val, LF_val);

    % IR Extract
    ir_raw = extract_ir(S);
    if isempty(ir_raw)
        fprintf('  [SKIP] Keine Impulsantwort extrahierbar\n');
        skipped_count = skipped_count + 1;
        continue;
    end
    fprintf('  - Rohdaten extrahiert: %d Samples\n', length(ir_raw));

    % Truncate
    target_samples = 0;
    if use_fixed_length
        target_samples = round(fixed_duration_s * fs);
    end
    [ir_trunc, metrics] = truncate_ir(ir_raw, target_samples);
    
    fprintf('  - Trunkierte IR: %d Samples (Start: %d, Ende: %d)\n', ...
        length(ir_trunc), metrics.idx_start, metrics.idx_end);
    fprintf('  - SNR: %.2f dB\n', metrics.snr_db);
    
    % Naming
    if strcmp(meta.type, 'Source')
        nameTag = sprintf('%s_Quelle', meta.variante);
    else
        nameTag = sprintf('%s_Pos%s', meta.variante, meta.position);
    end
    
    % Save Time
    save(fullfile(dirTime, ['Time_' nameTag '.mat']), 'ir_trunc', 'metrics', 'meta');
    
    % Distanz ermitteln (alle Dateien sind Receiver)
    dist = 0;
    posNum = str2double(meta.position);
    if ~isnan(posNum)
        idx = find([geo.pos] == posNum);
        if ~isempty(idx)
            dist = geo(idx).distance;
            fprintf('  - Distanz zur Quelle: %.2f m\n', dist);
        else
            warning('Position %d nicht in Geometrie gefunden! Verfügbare Positionen: %s. dist=0 gesetzt (keine Luftdämpfung).', ...
                posNum, mat2str([geo.pos]));
            fprintf('  - Distanz zur Quelle: 0 m [!] Position nicht in Geometrie\n');
        end
    else
        warning('Position "%s" ist nicht numerisch! dist=0 gesetzt.', meta.position);
        fprintf('  - Distanz zur Quelle: 0 m [!] Position nicht numerisch\n');
    end

    % Calc Spectrum
    fprintf('  - Berechne Terzspektrum...\n');
    [L_terz, L_sum, f_center] = calc_terz_spectrum(ir_trunc, fs, FS_global, dist, T_val, LF_val);
    fprintf('    Summenpegel: %.2f dB FS\n', L_sum);

    % Calc RT60 (T30) mit Umgebungsparametern
    fprintf('  - Berechne Nachhallzeit (T30)...\n');
    [t30_vals, t30_freqs] = calc_rt60_spectrum(ir_trunc, fs, T_val, LF_val);
    if ~isempty(t30_vals)
        fprintf('    T30 Werte berechnet für %d Frequenzbänder\n', length(t30_vals));
    end
    
    % Save Freq
    save(fullfile(dirFreq, ['Spec_' nameTag '.mat']), 'L_terz', 'L_sum', 'f_center', 't30_vals', 'meta');
    
    % Result Struct
    Result = struct();
    Result.meta = meta;
    Result.meta.fs = fs;
    Result.meta.FS_global_used = FS_global;
    Result.meta.T = T_val;
    Result.meta.LF = LF_val;
    
    Result.time.ir = ir_trunc;
    Result.time.metrics = metrics;
    
    Result.freq.f_center = f_center;
    Result.freq.terz_dbfs = L_terz;
    Result.freq.sum_level = L_sum;
    Result.freq.t30 = t30_vals;
    Result.freq.t30_freqs = t30_freqs;
    
    % Save Processed
    if strcmp(meta.type, 'Source')
        saveName = sprintf('Proc_%s_Quelle.mat', meta.variante);
    else
        saveName = sprintf('Proc_%s_Pos%s.mat', meta.variante, meta.position);
    end

    save(fullfile(procDir, saveName), 'Result');
    fprintf('  - Gespeichert: %s\n', saveName);

    summary_data(end+1,:) = {meta.variante, meta.position, L_sum, metrics.snr_db, saveName};
    processed_count = processed_count + 1;
    fprintf('  [OK] Datei erfolgreich verarbeitet\n');
end

fprintf('\n--- Phase 3 abgeschlossen ---\n');
fprintf('Verarbeitet: %d Dateien\n', processed_count);
fprintf('Übersprungen: %d Dateien\n', skipped_count);

% 3. Summary & Average
if ~isempty(summary_data)
    fprintf('\n--- Phase 4: Erstelle Zusammenfassung ---\n');
    summary_table = cell2table(summary_data, ...
        'VariableNames', {'Variante', 'Position', 'SumLevel', 'SNR', 'File'});

    summary_table = sortrows(summary_table, {'Variante', 'Position'});

    save(fullfile(procDir, 'Summary_Database.mat'), 'summary_table');
    writetable(summary_table, fullfile(procDir, 'Summary.xlsx'));
    fprintf('Zusammenfassungstabelle gespeichert:\n');
    fprintf('  - Summary_Database.mat\n');
    fprintf('  - Summary.xlsx\n');

    % Average berechnen
    fprintf('\n--- Phase 5: Berechne Durchschnittswerte ---\n');
    unique_vars = unique(summary_table.Variante);
    fprintf('Gefundene Varianten: %d\n', length(unique_vars));
    
    for i = 1:length(unique_vars)
        v = unique_vars{i};
        fprintf('\nBerechne Durchschnitt für Variante: %s\n', v);
        mask = strcmp(summary_table.Variante, v) & ~strcmp(summary_table.Position, 'Quelle');
        subset = summary_table(mask, :);

        if isempty(subset)
            fprintf('  [SKIP] Keine Receiver-Positionen gefunden\n');
            continue;
        end

        fprintf('  - Anzahl Positionen: %d\n', height(subset));

        % Template
        first_file = fullfile(procDir, subset.File{1});
        tmp = load(first_file);
        R_tmpl = tmp.Result;

        % Summation
        sum_E_terz = 0;
        sum_E_total = 0;
        n = height(subset);

        for k = 1:n
            D = load(fullfile(procDir, subset.File{k}));
            E_terz = 10.^(D.Result.freq.terz_dbfs / 10);
            E_terz(~isfinite(E_terz)) = 0;
            sum_E_terz = sum_E_terz + E_terz;

            E_tot = 10^(D.Result.freq.sum_level / 10);
            if ~isfinite(E_tot), E_tot = 0; end
            sum_E_total = sum_E_total + E_tot;
        end
        fprintf('  - Energiewerte summiert\n');
        
        % Result
        Result = R_tmpl;
        Result.meta.position = 'Average';
        Result.meta.type = 'Average';
        Result.time.ir = zeros(100,1); 
        Result.time.metrics.energy = (sum_E_total/n) * (Result.meta.FS_global_used^2);
        Result.time.metrics.snr_db = NaN;
        Result.time.metrics.idx_start = 1;
        Result.time.metrics.idx_end = 1;
        Result.time.metrics.energy_total = NaN;
        Result.time.metrics.energy_share = NaN;
        
        Result.freq.terz_dbfs = 10 * log10((sum_E_terz/n) + eps);
        Result.freq.sum_level = 10 * log10((sum_E_total/n) + eps);
        Result.freq.t30 = []; % Average T30 ist komplexer, hier leer lassen oder separat mitteln
        Result.freq.t30_freqs = [];

        fprintf('  - Durchschnittlicher Summenpegel: %.2f dB FS\n', Result.freq.sum_level);

        saveName = sprintf('Proc_%s_Average.mat', v);
        save(fullfile(procDir, saveName), 'Result');
        fprintf('  - Gespeichert: %s\n', saveName);
    end

    fprintf('\n--- Phase 5 abgeschlossen ---\n');
else
    fprintf('\n[!] Keine Daten zum Zusammenfassen vorhanden\n');
end

fprintf('\n=== Step 1 erfolgreich abgeschlossen ===\n');
fprintf('Ergebnisse befinden sich im Ordner: %s\n', procDir);

% Helper
function [S, meta] = load_and_parse_file(filepath)
    [~, fname, ~] = fileparts(filepath);
    S = load(filepath);
    meta = struct('filename', fname);

    % Erwartetes Format: Variante_X_Pos_Y.mat
    % Beispiele: Variante_1_Pos_10.mat, Var2_Pos_5.mat
    tokens = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once', 'ignorecase');
    if ~isempty(tokens)
        meta.variante = tokens{1};
        meta.position = tokens{2};  % z.B. "1", "10", "15"
        meta.type = 'Receiver';
    else
        % Dateiname passt nicht zum erwarteten Format
        meta.variante = 'Unknown';
        meta.position = '0';
        meta.type = 'Unknown';
        warning('Dateiname "%s" passt nicht zum erwarteten Format (Variante_X_Pos_Y.mat)', fname);
    end
end

function ir = extract_ir(S)
    ir = [];
    if isfield(S,'RiR') && ~isempty(S.RiR), ir = double(S.RiR(:));
    elseif isfield(S,'RIR') && ~isempty(S.RIR), ir = double(S.RIR(:));
    elseif isfield(S,'aufn') && ~isempty(S.aufn), ir = double(S.aufn(:));
    else
        fns = fieldnames(S);
        for f = 1:numel(fns)
            fname = fns{f};
            if startsWith(fname, '__'), continue; end
            v = S.(fname);
            if isnumeric(v) && numel(v) > 1000, ir = double(v(:)); return; end
        end
    end
end