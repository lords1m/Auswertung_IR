%% Diagnostik: Positive dBFS-Werte - Energie-basierte Analyse
% Verzichtet auf Pegel-Umwandlung und arbeitet nur mit Energien
% Findet die tatsächliche Ursache für band_energy > FS_global²
%
% Autor: dBFS Diagnostik
% Datum: 2026-01-19

clear; clc; close all;

% Repository-Pfade initialisieren
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');

fprintf('=== DIAGNOSTIK: Energie-Analyse für positive dBFS ===\n\n');

%% Config
dataDir = 'dataraw';
procDir = 'processed';
fs = 500e3;

% Geometrie laden
geo = get_geometry();

%% Phase 1: Finde FS_global (exakt wie in step1_process_data.m)

files = dir(fullfile(dataDir, '*.mat'));
fprintf('Phase 1: Bestimme FS_global aus RAW-Daten\n');
fprintf('Anzahl Dateien: %d\n\n', length(files));

FS_global = 0;
file_info = {};

for i = 1:length(files)
    try
        filepath = fullfile(files(i).folder, files(i).name);
        [S, meta] = load_and_parse_file(filepath);
        ir = extract_ir(S);

        if ~isempty(ir)
            max_val = max(abs(ir));
            FS_global = max(FS_global, max_val);

            file_info{end+1} = struct(...
                'filename', files(i).name, ...
                'variante', meta.variante, ...
                'position', meta.position, ...
                'type', meta.type, ...
                'max_amplitude', max_val, ...
                'is_FS_global', false ...
            );
        end
    catch
        % Skip
    end
end

% Markiere welche Datei FS_global bestimmt
for i = 1:length(file_info)
    if abs(file_info{i}.max_amplitude - FS_global) < 1e-6
        file_info{i}.is_FS_global = true;
        fprintf('FS_global = %.6f\n', FS_global);
        fprintf('Bestimmt durch: %s\n', file_info{i}.filename);
        fprintf('  Variante: %s, Position: %s, Typ: %s\n\n', ...
                file_info{i}.variante, file_info{i}.position, file_info{i}.type);
        break;
    end
end

FS_global_squared = FS_global^2;
fprintf('FS_global² = %.10f\n\n', FS_global_squared);

%% Phase 2: Analysiere JEDE Datei - suche band_energy > FS_global²

fprintf('Phase 2: Analysiere Terz-Spektren (ENERGIE-basiert)\n');
fprintf('Suche: band_energy > FS_global²\n\n');

% Terzband-Frequenzen
freq_bands = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
indices = 6:18;
f_exact = 1000 * 10.^(indices/10);

violations = {};  % Speichere alle Verletzungen
summary_stats = struct();

for i = 1:length(files)
    try
        filepath = fullfile(files(i).folder, files(i).name);
        [S, meta] = load_and_parse_file(filepath);

        fprintf('[%d/%d] %s\n', i, length(files), files(i).name);

        % IR Extract
        ir_raw = extract_ir(S);
        if isempty(ir_raw), continue; end

        % Truncate (wie in step1_process_data.m)
        use_fixed_length = true;
        fixed_duration_s = 0.03;
        target_samples = round(fixed_duration_s * fs);
        [ir_trunc, ~] = truncate_ir(ir_raw, target_samples);

        % Distanz ermitteln
        dist = 0;
        if strcmp(meta.type, 'Receiver')
            posNum = str2double(meta.position);
            if ~isnan(posNum)
                idx_geo = find([geo.pos] == posNum);
                if ~isempty(idx_geo)
                    dist = geo(idx_geo).distance;
                end
            end
        end

        % === ENERGIE-BERECHNUNG (ohne dB!) ===

        % FFT
        N = length(ir_trunc);
        N_fft = 2^nextpow2(N);
        X = fft(ir_trunc, N_fft);
        freqs = (0:N_fft-1) * (fs / N_fft);

        % Luftdämpfungskorrektur (falls dist > 0)
        if dist > 0
            T_val = 20;
            LF_val = 50;
            if isfield(S, 'T') && ~isempty(S.T), T_val = mean(S.T); end
            if isfield(S, 'Lf') && ~isempty(S.Lf), LF_val = mean(S.Lf);
            elseif isfield(S, 'LF') && ~isempty(S.LF), LF_val = mean(S.LF); end

            [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T_val, LF_val, dist);
            X = X .* A_lin(:);  % Korrektur anwenden
        end

        % Nur positive Frequenzen
        valid_idx = 1:floor(N_fft/2)+1;
        X = X(valid_idx);
        freqs = freqs(valid_idx);

        % Energie-Dichte (wie in calc_terz_spectrum.m)
        X_mag_sq = (abs(X).^2) / N;

        % Analysiere jedes Terzband
        found_violation = false;

        for k = 1:length(freq_bands)
            fc = f_exact(k);
            fl = fc * 10^(-1/20);
            fu = fc * 10^(1/20);

            if fl > fs/2, break; end

            idx_band = freqs >= fl & freqs <= fu;

            if any(idx_band)
                % === ENERGIE im Band (KEINE dB-Umwandlung!) ===
                band_energy = sum(X_mag_sq(idx_band));

                % Prüfe Verletzung: band_energy > FS_global²
                if band_energy > FS_global_squared
                    found_violation = true;

                    ratio = band_energy / FS_global_squared;
                    dBFS_would_be = 10 * log10(ratio);

                    violations{end+1} = struct(...
                        'filename', files(i).name, ...
                        'variante', meta.variante, ...
                        'position', meta.position, ...
                        'distance', dist, ...
                        'frequency_kHz', freq_bands(k)/1000, ...
                        'band_energy', band_energy, ...
                        'FS_global_squared', FS_global_squared, ...
                        'ratio', ratio, ...
                        'dBFS_would_be', dBFS_would_be ...
                    );

                    fprintf('  ⚠️  VERLETZUNG bei %.1f kHz:\n', freq_bands(k)/1000);
                    fprintf('      band_energy    = %.10f\n', band_energy);
                    fprintf('      FS_global²     = %.10f\n', FS_global_squared);
                    fprintf('      Ratio          = %.4f (%.2f dB)\n', ratio, dBFS_would_be);
                    fprintf('      → dBFS wäre    = +%.2f dB ✗\n', dBFS_would_be);
                end
            end
        end

        if ~found_violation
            fprintf('  ✓ Alle Energien < FS_global²\n');
        end

    catch ME
        fprintf('  Fehler: %s\n', ME.message);
    end
    fprintf('\n');
end

%% Phase 3: Zusammenfassung

fprintf('\n=== ZUSAMMENFASSUNG ===\n\n');

if isempty(violations)
    fprintf('✓ KEINE Verletzungen gefunden!\n');
    fprintf('  Alle band_energy ≤ FS_global²\n');
    fprintf('  Es sollten KEINE positiven dBFS auftreten.\n');
else
    fprintf('⚠️  %d VERLETZUNGEN gefunden!\n\n', length(violations));

    % Statistik
    freq_counts = zeros(size(freq_bands));
    for v_idx = 1:length(violations)
        v = violations{v_idx};
        f_idx = find(freq_bands == v.frequency_kHz * 1000);
        if ~isempty(f_idx)
            freq_counts(f_idx) = freq_counts(f_idx) + 1;
        end
    end

    fprintf('Verletzungen pro Frequenzband:\n');
    fprintf('%-12s | %-10s\n', 'Frequenz', 'Anzahl');
    fprintf('%s\n', repmat('-', 1, 25));
    for k = 1:length(freq_bands)
        if freq_counts(k) > 0
            fprintf('%-12s | %-10d\n', sprintf('%.1f kHz', freq_bands(k)/1000), freq_counts(k));
        end
    end

    % Finde maximale Verletzung
    max_ratio = 0;
    max_v_idx = 0;
    for v_idx = 1:length(violations)
        if violations{v_idx}.ratio > max_ratio
            max_ratio = violations{v_idx}.ratio;
            max_v_idx = v_idx;
        end
    end

    if max_v_idx > 0
        v_max = violations{max_v_idx};
        fprintf('\n--- Maximale Verletzung ---\n');
        fprintf('Datei:     %s\n', v_max.filename);
        fprintf('Variante:  %s\n', v_max.variante);
        fprintf('Position:  %s\n', v_max.position);
        fprintf('Distanz:   %.2f m\n', v_max.distance);
        fprintf('Frequenz:  %.1f kHz\n', v_max.frequency_kHz);
        fprintf('band_energy / FS_global² = %.4f\n', v_max.ratio);
        fprintf('→ dBFS = +%.2f dB\n', v_max.dBFS_would_be);
    end

    % Analysiere Muster
    fprintf('\n--- Analyse der Muster ---\n');

    % Welche Varianten?
    varianten = {};
    for v_idx = 1:length(violations)
        var = violations{v_idx}.variante;
        if ~ismember(var, varianten)
            varianten{end+1} = var;
        end
    end
    fprintf('Betroffene Varianten: %s\n', strjoin(varianten, ', '));

    % Welche Distanzen?
    distances = [];
    for v_idx = 1:length(violations)
        distances(end+1) = violations{v_idx}.distance;
    end
    fprintf('Distanz-Bereich: %.2f - %.2f m (Mittel: %.2f m)\n', ...
            min(distances), max(distances), mean(distances));

    % Bei allen gleich oder unterschiedlich?
    all_files_affected = length(violations) == length(files);
    fprintf('Alle Dateien betroffen? %s\n', iff(all_files_affected, 'JA', 'NEIN'));
end

%% Phase 4: Detaillierte Analyse einer Beispiel-Datei

if ~isempty(violations)
    fprintf('\n\n=== DETAILLIERTE ANALYSE (Beispiel-Datei) ===\n\n');

    % Nimm erste Verletzung
    v_example = violations{1};

    fprintf('Analysiere: %s\n', v_example.filename);
    fprintf('Verletzung bei %.1f kHz\n\n', v_example.frequency_kHz);

    % Lade Datei erneut für detaillierte Analyse
    filepath = fullfile(dataDir, v_example.filename);
    [S, meta] = load_and_parse_file(filepath);
    ir_raw = extract_ir(S);
    [ir_trunc, ~] = truncate_ir(ir_raw, round(0.03 * fs));

    fprintf('IR Statistik:\n');
    fprintf('  Länge (raw):       %d Samples\n', length(ir_raw));
    fprintf('  Länge (truncated): %d Samples\n', length(ir_trunc));
    fprintf('  Max (raw):         %.6f\n', max(abs(ir_raw)));
    fprintf('  Max (truncated):   %.6f\n', max(abs(ir_trunc)));
    fprintf('  RMS (truncated):   %.6f\n', rms(ir_trunc));
    fprintf('  FS_global:         %.6f\n', FS_global);
    fprintf('  Max/FS_global:     %.4f\n', max(abs(ir_trunc))/FS_global);

    % FFT Analyse
    N = length(ir_trunc);
    N_fft = 2^nextpow2(N);
    X = fft(ir_trunc, N_fft);

    % Distanz
    dist = v_example.distance;
    if dist > 0
        [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, 20, 50, dist);
        X = X .* A_lin(:);
    end

    valid_idx = 1:floor(N_fft/2)+1;
    X = X(valid_idx);
    freqs_fft = (0:N_fft-1) * (fs / N_fft);
    freqs_fft = freqs_fft(valid_idx);
    X_mag_sq = (abs(X).^2) / N;

    % Energie-Verteilung über Frequenz
    fprintf('\n\nEnergie-Verteilung:\n');
    fprintf('  Gesamt-Energie (Zeitbereich): %.10f\n', sum(ir_trunc.^2));
    fprintf('  Gesamt-Energie (FFT, Parseval): %.10f\n', sum(X_mag_sq) * 2);  % *2 wegen nur pos. Freq.

    % Finde Band mit Verletzung
    f_target = v_example.frequency_kHz * 1000;
    f_idx = find(freq_bands == f_target);
    fc = f_exact(f_idx);
    fl = fc * 10^(-1/20);
    fu = fc * 10^(1/20);

    idx_band = freqs_fft >= fl & freqs_fft <= fu;
    band_energy = sum(X_mag_sq(idx_band));

    fprintf('\n\nTerzband %.1f kHz (%.1f - %.1f Hz):\n', f_target/1000, fl, fu);
    fprintf('  Anzahl FFT-Bins: %d\n', sum(idx_band));
    fprintf('  Band-Energie:    %.10f\n', band_energy);
    fprintf('  FS_global²:      %.10f\n', FS_global_squared);
    fprintf('  Ratio:           %.6f\n', band_energy / FS_global_squared);

    % Wo kommt die Energie her?
    fprintf('\n\nEnergie-Beiträge (Top 5 FFT-Bins im Band):\n');
    band_energies = X_mag_sq(idx_band);
    band_freqs = freqs_fft(idx_band);
    [sorted_energies, sort_idx] = sort(band_energies, 'descend');

    for kk = 1:min(5, length(sorted_energies))
        fprintf('  Bin %d: f=%.1f Hz, E=%.10f (%.1f%% der Band-Energie)\n', ...
                kk, band_freqs(sort_idx(kk)), sorted_energies(kk), ...
                100 * sorted_energies(kk) / band_energy);
    end
end

%% Save Ergebnisse

if ~isempty(violations)
    % Export Verletzungen als Tabelle
    T_violations = struct2table(violations);
    writetable(T_violations, 'Plots/dBFS_Violations.xlsx');
    fprintf('\n\n✓ Verletzungen exportiert: Plots/dBFS_Violations.xlsx\n');
end

fprintf('\n=== DIAGNOSTIK ABGESCHLOSSEN ===\n');

%% Helper function
function result = iff(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
