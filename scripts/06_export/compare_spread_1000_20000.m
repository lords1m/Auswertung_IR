%% compare_spread_1000_20000.m
% Erstellt eine Tabelle zum Vergleich der Ausbreitung bei 1000 Hz und 20000 Hz
% auf Basis von Result.freq.terz_dbfs fuer eine Variante.

clear; clc;

% Repository-Pfade initialisieren
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');
init_repo_paths();

%% Konfiguration
variant = 'Variante_1';
target_freqs = [1000, 20000];
tolerance_pct = 5; % akzeptierte Abweichung in Prozent
procDir = 'processed';
outputDir = 'exported_tables';

if ~exist(procDir, 'dir')
    error('Ordner "%s" nicht gefunden.', procDir);
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% Daten laden
files = dir(fullfile(procDir, sprintf('Proc_%s_Pos*.mat', variant)));
if isempty(files)
    error('Keine Dateien fuer Variante "%s" gefunden.', variant);
end

geo = get_geometry();

rows = {};
missing_band_count = 0;

for i = 1:numel(files)
    fpath = fullfile(files(i).folder, files(i).name);
    D = load(fpath, 'Result');
    R = D.Result;

    if ~isfield(R, 'freq') || ~isfield(R.freq, 'terz_dbfs') || ~isfield(R.freq, 'f_center')
        continue;
    end

    posNum = str2double(R.meta.position);
    if isnan(posNum)
        continue;
    end

    dist = NaN;
    idx_geo = find([geo.pos] == posNum, 1);
    if ~isempty(idx_geo)
        dist = geo(idx_geo).distance;
    end

    f_center = R.freq.f_center;
    L_terz = R.freq.terz_dbfs;

    % 1000 Hz aus IR direkt berechnen (Option 2)
    L1 = calc_terz_dbfs_from_ir(R.time.ir, R.meta.fs, target_freqs(1), R.meta.FS_global_used);
    f1 = target_freqs(1);
    ok1 = isfinite(L1);

    % 20000 Hz aus Result.freq.terz_dbfs
    [L2, f2, ok2] = pick_band(L_terz, f_center, target_freqs(2), tolerance_pct);

    if ~ok1 || ~ok2
        missing_band_count = missing_band_count + 1;
    end

    delta = NaN;
    if isfinite(L1) && isfinite(L2)
        delta = L1 - L2;
    end

    rows(end+1, :) = {variant, posNum, dist, L1, L2, delta, f1, f2};
end

%% Tabelle schreiben
T = cell2table(rows, 'VariableNames', {
    'Variante', 'Position', 'Distance_m', ...
    'L_1000_dBFS', 'L_20000_dBFS', 'Delta_1000_minus_20000_dB', ...
    'Freq_1000_used_Hz', 'Freq_20000_used_Hz'});

T = sortrows(T, {'Position'});

baseName = fullfile(outputDir, sprintf('Terzband_Vergleich_%s_1000Hz_20000Hz', variant));
writetable(T, [baseName '.xlsx']);
writetable(T, [baseName '.csv']);

fprintf('Tabelle geschrieben: %s.xlsx und %s.csv\n', baseName, baseName);
if missing_band_count > 0
    fprintf('Hinweis: Bei %d Dateien lagen die Zielbaender ausserhalb der Toleranz.\n', missing_band_count);
end

%% Helper
function [L, f_used, ok] = pick_band(L_terz, f_center, target_freq, tol_pct)
    [diff_val, idx] = min(abs(f_center - target_freq));
    f_used = f_center(idx);
    ok = diff_val <= (target_freq * tol_pct / 100);
    if ok
        L = L_terz(idx);
    else
        L = NaN;
    end
end

function L = calc_terz_dbfs_from_ir(ir, fs, target_freq, FS_global_used)
    % Berechnet Terzbandpegel fuer eine Zielmittenfrequenz aus der IR
    if isempty(ir) || isempty(fs) || isempty(FS_global_used) || FS_global_used == 0
        L = NaN;
        return;
    end

    % Terzband-Grenzen nach IEC (Basis 10)
    fc = target_freq;
    fl = fc * 10^(-1/20);
    fu = fc * 10^(1/20);
    if fu >= fs/2
        L = NaN;
        return;
    end

    N = length(ir);
    N_fft = 2^nextpow2(N);
    X = fft(ir, N_fft);
    freqs = (0:N_fft-1) * (fs / N_fft);

    valid_idx = 1:floor(N_fft/2)+1;
    X = X(valid_idx);
    freqs = freqs(valid_idx);

    X_mag_sq = (abs(X).^2) / N;
    idx = freqs >= fl & freqs <= fu;
    if ~any(idx)
        L = NaN;
        return;
    end
    band_energy = sum(X_mag_sq(idx));
    L = 10 * log10((band_energy + eps) / (FS_global_used^2));
end
