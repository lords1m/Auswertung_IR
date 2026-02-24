%% Terzband-Filter Visualisierung
% Zeigt Filterkurve und gefilterte Impulsantwort
% Nutzt verarbeitete Daten aus 'processed' (step1_process_data.m)

clear;
clc;

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

%% Einstellungen

selectedVariant = 'Variante_1';
selectedPosition = '1';
selectedFrequency = 16000;  % Hz

procDir = 'processed';
fs = 500e3;
filterOrder = 8;

%% Lade Daten

filename = fullfile(procDir, sprintf('Proc_%s_Pos%s.mat', selectedVariant, selectedPosition));

if ~exist(filename, 'file')
    error('Datei nicht gefunden: %s', filename);
end

fprintf('Lade: %s\n', filename);
Data = load(filename);

if isfield(Data, 'Result') && isfield(Data.Result, 'time') && isfield(Data.Result.time, 'ir')
    ir = Data.Result.time.ir(:);
    if isfield(Data.Result, 'meta')
        meta = Data.Result.meta;
        fs = meta.fs;
    end
else
    error('Result.time.ir nicht gefunden');
end

N_original = length(ir);
fprintf('Geladen: %d Samples (%.2f ms)\n', N_original, N_original/fs*1000);

%% Terzband-Parameter

% 1/3-Oktav-Mittenfrequenzen (IEC 61260 Standard)
f_terz = double([ ...
    630 800 1000 1250 1600 2000 2500 3150 4000 5000 6300 8000 ...
    10000 12500 16000 20000 25000 31500 40000 50000 63000 80000 ...
    100000 125000 ]);

[~, freq_idx] = min(abs(f_terz - selectedFrequency));
f_center = f_terz(freq_idx);
fprintf('\nMittenfrequenz: %.0f Hz\n', f_center);

f_lower = f_center / 2^(1/6);
f_upper = f_center * 2^(1/6);
fprintf('Grenzen: %.1f - %.1f Hz\n', f_lower, f_upper);

Wn = [f_lower f_upper] / (fs/2);

if Wn(2) >= 1
    error('Obere Grenzfrequenz über Nyquist');
end

%% Filter Design

if mod(filterOrder, 2) ~= 0
    warning('Filterordnung muss gerade sein, runde auf %d', filterOrder + 1);
    filterOrder = filterOrder + 1;
end

[b, a] = butter(filterOrder/2, Wn, 'bandpass');
fprintf('Filter: Butterworth BP, Ordnung %d\n', filterOrder);

%% Frequenzgang

[H_filter, f_filter] = freqz(b, a, 4096, fs);
H_filter_dB = 20*log10(abs(H_filter));

%% Filterung

ir_filtered = filtfilt(b, a, ir);
t = (0:N_original-1) / fs * 1000;

%% FFT

N_fft = 2^nextpow2(N_original * 2);
IR_fft = fft(ir, N_fft);
IR_filtered_fft = fft(ir_filtered, N_fft);

freq = (0:N_fft-1) * (fs / N_fft);
nHalf = floor(N_fft/2) + 1;
freq = freq(1:nHalf);

H_original = 20*log10(abs(IR_fft(1:nHalf)) + eps);
H_filtered = 20*log10(abs(IR_filtered_fft(1:nHalf)) + eps);

H_original = H_original - max(H_original);
H_filtered = H_filtered - max(H_filtered);

%% Plots

figure('Position', [100, 100, 1400, 900]);

subplot(3,2,1);
semilogx(f_filter, H_filter_dB, 'b-', 'LineWidth', 2.5);
hold on;
plot([f_lower f_lower], [-60 5], 'r--', 'LineWidth', 1.5);
plot([f_upper f_upper], [-60 5], 'r--', 'LineWidth', 1.5);
plot([f_center f_center], [-60 5], 'g-', 'LineWidth', 2);
plot([f_lower/2 f_upper*2], [-3 -3], 'k:', 'LineWidth', 1.5);
legend('Filter', sprintf('f_{lower}=%.1f Hz', f_lower), sprintf('f_{upper}=%.1f Hz', f_upper), ...
       sprintf('f_{center}=%.0f Hz', f_center), '-3 dB', 'Location', 'best');
hold off;
grid on;
xlabel('Frequenz [Hz]');
ylabel('Dämpfung [dB]');
title(sprintf('Butterworth Bandpass (Ordnung %d)', filterOrder));
xlim([f_lower/2, f_upper*2]);
ylim([-60 5]);

subplot(3,2,2);
semilogx(f_filter, H_filter_dB, 'b-', 'LineWidth', 2.5);
hold on;
plot([f_lower f_lower], [-6 1], 'r--', 'LineWidth', 1.5);
plot([f_upper f_upper], [-6 1], 'r--', 'LineWidth', 1.5);
plot([f_center f_center], [-6 1], 'g-', 'LineWidth', 2);
plot([f_lower/1.5 f_upper*1.5], [-3 -3], 'k:', 'LineWidth', 1.5);
hold off;
grid on;
xlabel('Frequenz [Hz]');
ylabel('Dämpfung [dB]');
title('Zoom Durchlassbereich');
xlim([f_lower/1.5, f_upper*1.5]);
ylim([-6 1]);

subplot(3,2,3);
ir_log = 20*log10(abs(ir) + eps);
ir_log = ir_log - max(ir_log);
plot(t, ir_log, 'b-', 'LineWidth', 1);
grid on;
xlabel('Zeit [ms]');
ylabel('Pegel [dB]');
title(sprintf('Original IR - %s Pos %s', selectedVariant, selectedPosition));
xlim([0 min(100, max(t))]);
ylim([-60 5]);

subplot(3,2,4);
ir_filtered_log = 20*log10(abs(ir_filtered) + eps);
ir_filtered_log = ir_filtered_log - max(ir_filtered_log);
plot(t, ir_filtered_log, 'r-', 'LineWidth', 1);
grid on;
xlabel('Zeit [ms]');
ylabel('Pegel [dB]');
title(sprintf('Gefilterte IR (f_c = %.0f Hz)', f_center));
xlim([0 min(100, max(t))]);
ylim([-60 5]);

subplot(3,2,5);
semilogx(freq, H_original, 'b-', 'LineWidth', 1.5);
hold on;
plot([f_lower f_lower], [-80 5], 'r--', 'LineWidth', 1.5);
plot([f_upper f_upper], [-80 5], 'r--', 'LineWidth', 1.5);
plot([f_center f_center], [-80 5], 'g-', 'LineWidth', 2);
hold off;
grid on;
xlabel('Frequenz [Hz]');
ylabel('Pegel [dB]');
title('Original Spektrum');
xlim([4000 60000]);
ylim([-80 5]);

subplot(3,2,6);
semilogx(freq, H_filtered, 'r-', 'LineWidth', 2);
hold on;
plot([f_lower f_lower], [-80 5], 'r--', 'LineWidth', 1.5);
plot([f_upper f_upper], [-80 5], 'r--', 'LineWidth', 1.5);
plot([f_center f_center], [-80 5], 'g-', 'LineWidth', 2);
text(f_lower, 0, sprintf('  %.1f Hz', f_lower), 'Color', 'r', 'FontSize', 9);
text(f_upper, 0, sprintf('  %.1f Hz', f_upper), 'Color', 'r', 'FontSize', 9);
text(f_center, 0, sprintf('  %.0f Hz', f_center), 'Color', 'g', 'FontSize', 9, 'FontWeight', 'bold');
hold off;
grid on;
xlabel('Frequenz [Hz]');
ylabel('Pegel [dB]');
title('Gefiltertes Spektrum');
xlim([4000 60000]);
ylim([-80 5]);

sgtitle(sprintf('Terzband-Filter: %s Pos %s, f_c = %.0f Hz', ...
                selectedVariant, selectedPosition, f_center), ...
        'FontSize', 14, 'FontWeight', 'bold');

%% Speichern

outputDir = 'Plots';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

filename_out = fullfile(outputDir, sprintf('Filter_%s_Pos%s_f%.0f.png', ...
                                            selectedVariant, selectedPosition, f_center));
saveas(gcf, filename_out);
saveas(gcf, strrep(filename_out, '.png', '.fig'));

fprintf('\nGespeichert: %s\n', filename_out);

%% Info

fprintf('\nFilter:\n');
fprintf('  f_center: %.0f Hz\n', f_center);
fprintf('  f_lower:  %.1f Hz\n', f_lower);
fprintf('  f_upper:  %.1f Hz\n', f_upper);
fprintf('  BW:       %.1f Hz (%.1f%%)\n', f_upper - f_lower, (f_upper - f_lower) / f_center * 100);
fprintf('  Ordnung:  %d\n', filterOrder);
fprintf('  fs:       %.0f kHz\n', fs/1000);
