%% Example: IR Processing Pipeline - Alle Verarbeitungsschritte in Reihenfolge
%
% Dieses Skript demonstriert alle Schritte der IR-Verarbeitung in der
% korrekten Reihenfolge:
%
% 1. IR Extraktion (aus Rohdaten)
% 2. DC-Offset Entfernung
% 3. Truncation (Start/Ende finden)
% 4. Optional: Normalisierung
% 5. Optional: Windowing (für FFT)
% 6. Optional: Filterung (für Frequenzanalyse)
% 7. Auto-Save
%
% Autor: IR Processing Example
% Datum: 2026-01-19

clear; clc; close all;

% Repository-Pfade initialisieren
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');

fprintf('=== IR Processing Pipeline - Beispiel ===\n\n');

%% BEISPIEL 1: Minimale Verarbeitung (Standard-Workflow)
fprintf('--- BEISPIEL 1: Minimale Verarbeitung ---\n');
fprintf('Schritte: Extraktion → DC-Removal → Truncation\n\n');

% Lade Beispiel-Rohdaten
example_file = uigetfile('dataraw/*.mat', 'Wähle Rohdaten-Datei');
if isequal(example_file, 0)
    fprintf('Abbruch durch Benutzer.\n');
    return;
end

% SCHRITT 1: Extraktion
fprintf('[1/3] Extrahiere IR aus Rohdaten...\n');
S = load(fullfile('dataraw', example_file));
ir_raw = extract_ir(S);
fprintf('      → %d Samples extrahiert\n', length(ir_raw));
fprintf('      → Max-Amplitude: %.6f\n', max(abs(ir_raw)));
fprintf('      → DC-Offset: %.6f\n\n', mean(ir_raw));

% SCHRITT 2 & 3: DC-Removal + Truncation (via Pipeline)
fprintf('[2-3/3] DC-Removal + Truncation...\n');
[ir_processed, info] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', true, ...
    'TruncateLength', 0, ...  % 0 = dynamische Länge
    'Verbose', true);

fprintf('\n✓ Minimale Verarbeitung abgeschlossen\n');
fprintf('  Original: %d Samples → Final: %d Samples\n', ...
        info.original_length, info.final_length);
fprintf('  SNR: %.2f dB\n\n', info.truncation_metrics.snr_db);


%% BEISPIEL 2: Vollständige Verarbeitung mit fester Länge
fprintf('\n--- BEISPIEL 2: Vollständige Verarbeitung ---\n');
fprintf('Schritte: DC-Removal → Truncation (fest) → Normalisierung → Auto-Save\n\n');

% Festgelegte Länge: 30 ms bei 500 kHz = 15000 Samples
target_length = round(0.03 * 500e3);

[ir_full, info_full] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', true, ...
    'TruncateLength', target_length, ...
    'Normalize', true, ...
    'NormalizeTo', 1.0, ...
    'AutoSave', true, ...
    'SavePath', 'processed/Example_Processed.mat', ...
    'Verbose', true);

fprintf('\n✓ Vollständige Verarbeitung abgeschlossen\n');
fprintf('  Gespeichert in: %s\n\n', info_full.save_path);


%% BEISPIEL 3: Für FFT-Reflexionsfaktor-Analyse
fprintf('\n--- BEISPIEL 3: FFT-Reflexionsfaktor-Analyse ---\n');
fprintf('Schritte: DC-Removal → Hanning-Fenster\n');
fprintf('(Keine Truncation, da wir die volle Länge für FFT benötigen)\n\n');

[ir_fft, info_fft] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', false, ...     % KEINE Truncation für FFT
    'Window', 'hanning', ...   % Hanning-Fenster anwenden
    'Verbose', true);

fprintf('\n✓ FFT-Vorbereitung abgeschlossen\n');
fprintf('  Hanning-Fenster angewendet\n');
fprintf('  Länge beibehalten: %d Samples\n\n', length(ir_fft));


%% BEISPIEL 4: Terzband-Analyse mit Bandpass-Filter
fprintf('\n--- BEISPIEL 4: Terzband-Filterung ---\n');
fprintf('Schritte: DC-Removal → Truncation → Bandpass-Filter (8-16 kHz)\n\n');

[ir_terz, info_terz] = process_ir_pipeline(ir_raw, ...
    'RemoveDC', true, ...
    'Truncate', true, ...
    'Filter', true, ...
    'FilterType', 'bandpass', ...
    'FilterFreq', [8000 16000], ...  % 8-16 kHz Band
    'FilterOrder', 8, ...             % Butterworth 8. Ordnung
    'SamplingRate', 500e3, ...
    'Verbose', true);

fprintf('\n✓ Terzband-Filterung abgeschlossen\n');
fprintf('  Frequenzband: 8-16 kHz\n');
fprintf('  Filter-Ordnung: 8 (Butterworth)\n\n');


%% BEISPIEL 5: Manuelle Schritt-für-Schritt-Verarbeitung
fprintf('\n--- BEISPIEL 5: Manuelle Verarbeitung (ohne Pipeline) ---\n');
fprintf('Zeigt wie man die Schritte einzeln ausführt\n\n');

% Schritt 1: DC-Removal
fprintf('[1/5] DC-Removal...\n');
ir_manual = process_ir_modifications(ir_raw, 'RemoveDC', true, 'AutoSave', false);
fprintf('      DC-Offset vor: %.6f, nach: %.6f\n', mean(ir_raw), mean(ir_manual));

% Schritt 2: Truncation
fprintf('[2/5] Truncation...\n');
[ir_manual, metrics] = truncate_ir(ir_manual, 0);
fprintf('      %d → %d Samples, SNR: %.2f dB\n', length(ir_raw), length(ir_manual), metrics.snr_db);

% Schritt 3: Normalisierung
fprintf('[3/5] Normalisierung...\n');
max_val = max(abs(ir_manual));
ir_manual = ir_manual / max_val;
fprintf('      Max: %.6f → 1.0\n', max_val);

% Schritt 4: Hanning-Fenster
fprintf('[4/5] Hanning-Fenster...\n');
win = hanning(length(ir_manual));
ir_manual = ir_manual .* win;
fprintf('      Fenster angewendet\n');

% Schritt 5: Save
fprintf('[5/5] Speichern...\n');
Result = struct();
Result.ir = ir_manual;
Result.created = datetime('now');
save('processed/Example_Manual.mat', 'Result', '-v7.3');
fprintf('      Gespeichert: processed/Example_Manual.mat\n');

fprintf('\n✓ Manuelle Verarbeitung abgeschlossen\n\n');


%% VISUALISIERUNG: Vergleich aller Verarbeitungsschritte
fprintf('\n--- VISUALISIERUNG: Vergleich ---\n');

figure('Position', [100, 100, 1400, 900], 'Color', 'w');
t_raw = (0:length(ir_raw)-1) / 500e3 * 1000;  % Zeit in ms

% Raw
subplot(3,2,1);
plot(t_raw, ir_raw, 'b');
grid on;
title('1. Original (Roh)');
xlabel('Zeit [ms]'); ylabel('Amplitude');
text(0.05, 0.95, sprintf('DC: %.6f\nMax: %.4f', mean(ir_raw), max(abs(ir_raw))), ...
     'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w');

% Nach DC-Removal
subplot(3,2,2);
ir_dc = process_ir_modifications(ir_raw, 'RemoveDC', true, 'AutoSave', false);
plot(t_raw, ir_dc, 'b');
grid on;
title('2. Nach DC-Removal');
xlabel('Zeit [ms]'); ylabel('Amplitude');
text(0.05, 0.95, sprintf('DC: %.6f\nMax: %.4f', mean(ir_dc), max(abs(ir_dc))), ...
     'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w');

% Nach Truncation
subplot(3,2,3);
[ir_trunc, ~] = truncate_ir(ir_dc, 0);
t_trunc = (0:length(ir_trunc)-1) / 500e3 * 1000;
plot(t_trunc, ir_trunc, 'b');
grid on;
title('3. Nach Truncation');
xlabel('Zeit [ms]'); ylabel('Amplitude');
text(0.05, 0.95, sprintf('Länge: %d → %d\nMax: %.4f', length(ir_dc), length(ir_trunc), max(abs(ir_trunc))), ...
     'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w');

% Nach Normalisierung
subplot(3,2,4);
ir_norm = ir_trunc / max(abs(ir_trunc));
plot(t_trunc, ir_norm, 'b');
grid on;
title('4. Nach Normalisierung');
xlabel('Zeit [ms]'); ylabel('Amplitude');
text(0.05, 0.95, sprintf('Max: %.4f → 1.0', max(abs(ir_trunc))), ...
     'Units', 'normalized', 'VerticalAlignment', 'top', 'BackgroundColor', 'w');

% Nach Windowing
subplot(3,2,5);
win = hanning(length(ir_norm));
ir_win = ir_norm .* win;
plot(t_trunc, ir_win, 'b'); hold on;
plot(t_trunc, win, 'r--', 'LineWidth', 1.5);
grid on;
title('5. Nach Hanning-Fenster');
xlabel('Zeit [ms]'); ylabel('Amplitude');
legend('Signal', 'Fenster', 'Location', 'best');

% Frequenzspektrum (Final)
subplot(3,2,6);
N_fft = 2^nextpow2(length(ir_win)) * 4;
H = fft(ir_win, N_fft);
f = (0:N_fft-1) * (500e3 / N_fft);
idx = 1:floor(N_fft/2)+1;
semilogx(f(idx), 20*log10(abs(H(idx))), 'b', 'LineWidth', 1.2);
grid on;
title('6. Frequenzspektrum (Final)');
xlabel('Frequenz [Hz]'); ylabel('Pegel [dB]');
xlim([4000 63000]);
set(gca, 'XTick', [4000 10000 20000 40000 63000], ...
         'XTickLabel', {'4k', '10k', '20k', '40k', '63k'});

sgtitle('IR Processing Pipeline - Alle Schritte', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('Visualisierung erstellt.\n');
fprintf('\n=== Beispiele abgeschlossen ===\n');
