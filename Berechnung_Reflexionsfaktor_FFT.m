%% Berechnung_Reflexionsfaktor_FFT.m
% Berechnet den frequenzabhängigen Reflexionsfaktor aus zwei geschnittenen IRs.
%
% Ablauf:
% 1. Lädt Direktschall-IR und Reflexions-IR (z.B. aus Visual_Truncation_Tool).
% 2. Wendet ein Hanning-Fenster an.
% 3. Berechnet die FFT.
% 4. Bestimmt den Reflexionsfaktor R(f) unter Berücksichtigung der Weglängen.

clear; clc; close all;

%% 1. Dateien laden
fprintf('Bitte wählen Sie die Datei für den DIREKTSCHALL...\n');
[file_dir, path_dir] = uigetfile('*.mat', 'Wähle Direktschall-IR');
if isequal(file_dir, 0), return; end

fprintf('Bitte wählen Sie die Datei für die REFLEXION...\n');
[file_ref, path_ref] = uigetfile('*.mat', 'Wähle Reflexions-IR');
if isequal(file_ref, 0), return; end

% Laden
D_dir = load(fullfile(path_dir, file_dir));
D_ref = load(fullfile(path_ref, file_ref));

% IRs extrahieren (Support für Result-Struct und Arrays)
ir_dir = get_ir_from_struct(D_dir);
ir_ref = get_ir_from_struct(D_ref);

% Samplingrate (Annahme: identisch)
fs = 500e3; 
if isfield(D_dir, 'Result') && isfield(D_dir.Result, 'meta') && isfield(D_dir.Result.meta, 'fs')
    fs = D_dir.Result.meta.fs;
end

%% 2. Längen anpassen & Fensterung
N_dir = length(ir_dir);
N_ref = length(ir_ref);
N = min(N_dir, N_ref);

if N_dir ~= N_ref
    fprintf('Warnung: Längen unterschiedlich (%d vs %d). Kürze auf %d Samples.\n', N_dir, N_ref, N);
    ir_dir = ir_dir(1:N);
    ir_ref = ir_ref(1:N);
end

% Hanning Fenster
win = hanning(N);
ir_dir_win = ir_dir .* win;
ir_ref_win = ir_ref .* win;

%% 3. Distanzen abfragen
prompt = {'Abstand Quelle -> Mikro (Direktweg) [m]:', ...
          'Abstand Quelle -> Wand -> Mikro (Reflexionsweg) [m]:'};
dlgtitle = 'Geometrie Eingabe';
dims = [1 50];
definput = {'1.7', '3.98'}; % Beispielwerte
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer), return; end
d_dir = str2double(answer{1});
d_ref = str2double(answer{2});

%% 4. FFT & Berechnung

% FFT (Zero-Padding für glatteren Plot optional, hier N)
N_fft = 2^nextpow2(N) * 4; % 4-fach Zero Padding für Interpolation
H_dir = fft(ir_dir_win, N_fft);
H_ref = fft(ir_ref_win, N_fft);

% Frequenzvektor
f = (0:N_fft-1) * (fs / N_fft);
valid_idx = 1:floor(N_fft/2)+1; % Nur positive Frequenzen
f = f(valid_idx);
H_dir = H_dir(valid_idx);
H_ref = H_ref(valid_idx);

% Berechnung Reflexionsfaktor R(f)
% Formel: R = (H_ref * d_ref) / (H_dir * d_dir)
% Herleitung: H_mic ~ (1/d) * H_source  => H_source ~ H_mic * d
% R = H_source_ref / H_source_dir

R_complex = (H_ref .* d_ref) ./ (H_dir .* d_dir);
R_mag = abs(R_complex);

%% 5. Plot
figure('Position', [100, 100, 1000, 800], 'Color', 'w');

% Zeitbereich
subplot(3,1,1);
t = (0:N-1)/fs*1000;
plot(t, ir_dir_win, 'b', 'DisplayName', 'Direkt (gefenstert)'); hold on;
plot(t, ir_ref_win, 'r', 'DisplayName', 'Reflexion (gefenstert)');
grid on; legend show;
xlabel('Zeit [ms]'); ylabel('Amplitude');
title('Gefensterte Impulsantworten');

% Frequenzbereich (Pegel)
subplot(3,1,2);
semilogx(f, 20*log10(abs(H_dir)), 'b', 'DisplayName', 'Direkt'); hold on;
semilogx(f, 20*log10(abs(H_ref)), 'r', 'DisplayName', 'Reflexion');
grid on; legend show;
xlabel('Frequenz [Hz]'); ylabel('Pegel [dB]');
title('Frequenzspektrum (Unkorrigiert)');
xlim([1000, fs/2]);
set(gca, 'XTick', [1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000], ...
         'XTickLabel', {'1k', '2k', '5k', '10k', '20k', '50k', '100k', '200k'});

% Reflexionsfaktor
subplot(3,1,3);
semilogx(f, R_mag, 'k', 'LineWidth', 1.5); hold on;
yline(1, 'k--');
grid on;
xlabel('Frequenz [Hz]'); ylabel('Reflexionsfaktor |R|');
title(sprintf('Reflexionsfaktor (d_{dir}=%.2fm, d_{ref}=%.2fm)', d_dir, d_ref));
xlim([4000, 63000]); % Fokus auf Ultraschall
ylim([0, 1.5]); % R sollte meist < 1 sein
set(gca, 'XTick', [4000, 10000, 20000, 40000, 63000], ...
         'XTickLabel', {'4k', '10k', '20k', '40k', '63k'});

% Durchschnitt im relevanten Bereich
idx_rel = f >= 30000 & f <= 50000;
mean_R = mean(R_mag(idx_rel));
text(40000, 1.2, sprintf('Mean (30-50k): %.2f', mean_R), 'BackgroundColor', 'w');

%% Hilfsfunktion
function ir = get_ir_from_struct(D)
    if isfield(D, 'Result') && isfield(D.Result, 'time') && isfield(D.Result.time, 'ir')
        ir = D.Result.time.ir;
    elseif isfield(D, 'ir')
        ir = D.ir;
    elseif isfield(D, 'RiR')
        ir = D.RiR;
    else
        % Fallback: Erstes numerisches Feld
        fns = fieldnames(D);
        for i=1:length(fns)
            if isnumeric(D.(fns{i})) && length(D.(fns{i})) > 10
                ir = D.(fns{i});
                return;
            end
        end
        error('Keine IR gefunden');
    end
    ir = double(ir(:));
    ir = ir - mean(ir); % DC weg
end