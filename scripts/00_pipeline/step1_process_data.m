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
init_repo_paths(); 

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

% 1. Geometrie laden
fprintf('\n--- Phase 1: Lade Geometriedaten ---\n');
geo = get_geometry();
fprintf('Geometriedaten geladen: %d Positionen definiert\n', length(geo));

% 2. Dateien laden und suchen
files = dir(fullfile(dataDir, '*.mat'));
fprintf('\n--- Phase 2: Verarbeite IRs und ermittle FS_global ---\n');
fprintf('Anzahl gefundene Dateien: %d\n', length(files));
% PASS 1: IRs verarbeiten und FS_global sammeln
processed_irs = {};
FS_global_peak = 0;
processed_count = 0;
skipped_count = 0;

for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);
    fprintf('\n[%d/%d] Pass 1 - Lade und verarbeite IR: %s\n', i, length(files), files(i).name);

    % Parse
    [S, meta] = load_and_parse_file(filepath);

    if isempty(S) || isempty(meta.variante)
        fprintf('  [SKIP] Datei konnte nicht geparst werden\n');
        skipped_count = skipped_count + 1;
        continue;
    end

    fprintf('  - Variante: %s, Position: %s\n', meta.variante, meta.position);

    % Umgebungsparameter auslesen
    T_val = 20;
    LF_val = 50;
    if isfield(S, 'T') && ~isempty(S.T), T_val = mean(S.T); end
    if isfield(S, 'Lf') && ~isempty(S.Lf)
        LF_val = mean(S.Lf);
    elseif isfield(S, 'LF') && ~isempty(S.LF)
        LF_val = mean(S.LF);
    end

    % IR Extract
    ir_raw = extract_ir(S);
    if isempty(ir_raw)
        fprintf('  [SKIP] Keine Impulsantwort extrahierbar\n');
        skipped_count = skipped_count + 1;
        continue;
    end

    % Truncate (enthält DC-Removal!)
    target_samples = 0;
    if use_fixed_length
        target_samples = round(fixed_duration_s * fs);
    end
    [ir_trunc, metrics] = truncate_ir(ir_raw, target_samples);

    fprintf('  - IR verarbeitet: %d → %d Samples, SNR: %.2f dB\n', ...
        length(ir_raw), length(ir_trunc), metrics.snr_db);

    % Globales Maximum der verarbeiteten IR bestimmen
    ir_max = max(abs(ir_trunc));
    posNum = str2double(meta.position);

    FS_global_peak = max(FS_global_peak, ir_max);
    fprintf('  - Max Amplitude (verarbeitet): %.5f → in FS_global_peak einbezogen\n', ir_max);

    % Distanz ermitteln
    dist = 0;
    if ~isnan(posNum)
        idx = find([geo.pos] == posNum);
        if ~isempty(idx)
            dist = geo(idx).distance;
        else
            warning('Position %d nicht in Geometrie gefunden! dist=0 gesetzt.', posNum);
        end
    else
        warning('Position "%s" ist nicht numerisch! dist=0 gesetzt.', meta.position);
    end

    % Naming
    if strcmp(meta.type, 'Source')
        nameTag = sprintf('%s_Quelle', meta.variante);
    else
        nameTag = sprintf('%s_Pos%s', meta.variante, meta.position);
    end

    % Save Time Domain (verarbeitete IR)
    save(fullfile(dirTime, ['Time_' nameTag '.mat']), 'ir_trunc', 'metrics', 'meta');

    % Speichern für Pass 2
    processed_irs{end+1} = struct(...
        'filepath', filepath, ...
        'nameTag', nameTag, ...
        'meta', meta, ...
        'ir_trunc', ir_trunc, ...
        'metrics', metrics, ...
        'dist', dist, ...
        'T', T_val, ...
        'LF', LF_val, ...
        'ir_max', ir_max);

    processed_count = processed_count + 1;
end

if FS_global_peak == 0, FS_global_peak = 1; end

fprintf('\n--- Phase 2 abgeschlossen ---\n');
fprintf('Verarbeitet: %d Dateien\n', processed_count);
fprintf('Übersprungen: %d Dateien\n', skipped_count);
fprintf('\n*** FS_global_peak (aus verarbeiteten IRs): %.5f ***\n', FS_global_peak);

% PASS 2: Spektren berechnen mit FS_global = 1 (liefert lineare Energien)
fprintf('\n--- Phase 3: Berechne Spektren fuer Energie-Referenz ---\n');
summary_data = {};
max_energy_sum = 0;

for i = 1:length(processed_irs)
    proc = processed_irs{i};
    fprintf('\n[%d/%d] Pass 2 - Spektrum berechnen: %s\n', i, length(processed_irs), proc.nameTag);

    % Calc Spectrum mit FS_global = 1.0 (liefert lineare Energie ueber 10^(L/10))
    fprintf('  - Berechne Terzspektrum (FS_global=1.0)...\n');
    [L_terz_tmp, L_sum_tmp, f_center] = calc_terz_spectrum(proc.ir_trunc, fs, 1.0, proc.dist, proc.T, proc.LF);
    if isfinite(L_sum_tmp)
        energy_sum = 10^(L_sum_tmp / 10);
    else
        energy_sum = 0;
    end
    E_terz = 10.^(L_terz_tmp / 10);
    E_terz(~isfinite(E_terz)) = 0;
    max_energy_sum = max(max_energy_sum, energy_sum);

    % Calc RT60 (T30)
    fprintf('  - Berechne Nachhallzeit (T30)...\n');
    [t30_vals, t30_freqs] = calc_rt60_spectrum(proc.ir_trunc, fs, proc.T, proc.LF);

    % Speichern fuer Pass 3
    processed_irs{i}.E_terz = E_terz;
    processed_irs{i}.E_sum = energy_sum;
    processed_irs{i}.f_center = f_center;
    processed_irs{i}.t30_vals = t30_vals;
    processed_irs{i}.t30_freqs = t30_freqs;
end

fprintf('\n--- Phase 3 abgeschlossen ---\n');
fprintf('Spektren berechnet: %d Dateien\n', length(processed_irs));

% FS_global_final aus globaler Energie bestimmen
FS_global_energy = sqrt(max_energy_sum);
if FS_global_energy == 0, FS_global_energy = 1; end
FS_global_final = max(FS_global_peak, FS_global_energy);
fprintf('\n*** FS_global_final (Energie-Referenz): %.5f ***\n', FS_global_final);

% PASS 3: Ergebnisse mit finaler dBFS-Skalierung schreiben
fprintf('\n--- Phase 4: Schreibe Ergebnisse mit finaler dBFS-Skalierung ---\n');
for i = 1:length(processed_irs)
    proc = processed_irs{i};

    % dBFS aus linearer Energie
    L_terz = 10 * log10((proc.E_terz + eps) / (FS_global_final^2));
    L_sum = 10 * log10((proc.E_sum + eps) / (FS_global_final^2));
    L_terz = min(L_terz, 0);
    L_sum = min(L_sum, 0);

    % Save Freq
    meta = proc.meta;
    save(fullfile(dirFreq, ['Spec_' proc.nameTag '.mat']), 'L_terz', 'L_sum', 'f_center', 't30_vals', 'meta');

    % Result Struct
    Result = struct();
    Result.meta = proc.meta;
    Result.meta.fs = fs;
    Result.meta.FS_global_used = FS_global_final;
    Result.meta.T = proc.T;
    Result.meta.LF = proc.LF;

    Result.time.ir = proc.ir_trunc;
    Result.time.metrics = proc.metrics;

    Result.freq.f_center = proc.f_center;
    Result.freq.terz_dbfs = L_terz;
    Result.freq.sum_level = L_sum;
    Result.freq.t30 = proc.t30_vals;
    Result.freq.t30_freqs = proc.t30_freqs;

    % Save Processed
    if strcmp(proc.meta.type, 'Source')
        saveName = sprintf('Proc_%s_Quelle.mat', proc.meta.variante);
    else
        saveName = sprintf('Proc_%s_Pos%s.mat', proc.meta.variante, proc.meta.position);
    end

    save(fullfile(procDir, saveName), 'Result');
    fprintf('  - Gespeichert: %s\n', saveName);

    summary_data(end+1,:) = {proc.meta.variante, proc.meta.position, L_sum, proc.metrics.snr_db, saveName};
end

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

        % Nur numerische Positionen 1-15 für Average verwenden!
        % Schließt aus: "Quelle", "Z1", "Z2", "16", etc.
        mask_var = strcmp(summary_table.Variante, v);
        mask_valid = false(height(summary_table), 1);

        for j = 1:height(summary_table)
            if mask_var(j)
                pos = summary_table.Position{j};
                posNum = str2double(pos);
                if ~isnan(posNum) && posNum >= 1 && posNum <= 15
                    mask_valid(j) = true;
                end
            end
        end

        subset = summary_table(mask_valid, :);
        total_count = sum(mask_var);
        excluded_count = total_count - height(subset);

        if isempty(subset)
            fprintf('  [SKIP] Keine gültigen Receiver-Positionen (1-15) gefunden\n');
            continue;
        end

        fprintf('  - Anzahl Positionen: %d (von %d gesamt, %d ausgeschlossen)\n', ...
            height(subset), total_count, excluded_count);

        if excluded_count > 0
            fprintf('  - HINWEIS: Ausgeschlossen %d nicht-numerische/ungültige Positionen\n', excluded_count);
        end

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
% (lokale Helpers entfernt, damit die zentralen Funktionen aus /functions genutzt werden)
