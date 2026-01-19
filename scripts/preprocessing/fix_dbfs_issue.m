%% Fix für positive dBFS-Werte
% Problem: FS_global wird aus RAW IRs berechnet, aber Terzspektrum
%          verwendet luftdämpfungs-korrigierte IRs
%
% Lösung: FS_global aus korrigierten IRs berechnen

clear; clc; close all;

% Repository-Pfade initialisieren
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');

% Config
dataDir = 'dataraw';
procDir = 'processed';
fs = 500e3;

fprintf('=== Fix: FS_global aus korrigierten IRs berechnen ===\n');

%% 1. Globale Referenz ermitteln (MIT Luftdämpfungskorrektur)
files = dir(fullfile(dataDir, '*.mat'));
fprintf('\n--- Phase 1: Ermittle globalen Referenzpegel (korrigiert) ---\n');

geo = get_geometry();

FS_global_raw = 0;
FS_global_corrected = 0;

for i = 1:length(files)
    try
        filepath = fullfile(files(i).folder, files(i).name);
        [S, meta] = load_and_parse_file(filepath);
        ir = extract_ir(S);

        if ~isempty(ir)
            % Raw Maximum
            FS_global_raw = max(FS_global_raw, max(abs(ir)));

            % Korrigiertes Maximum (mit Luftdämpfungskorrektur)
            % Distanz ermitteln
            dist = 0;
            if strcmp(meta.type, 'Receiver')
                posNum = str2double(meta.position);
                if ~isnan(posNum)
                    idx = find([geo.pos] == posNum);
                    if ~isempty(idx)
                        dist = geo(idx).distance;
                    end
                end
            end

            % Luftdämpfungskorrektur anwenden (im Frequenzbereich)
            if dist > 0
                % Umgebungsparameter
                T_val = 20;
                LF_val = 50;
                if isfield(S, 'T') && ~isempty(S.T), T_val = mean(S.T); end
                if isfield(S, 'Lf') && ~isempty(S.Lf)
                    LF_val = mean(S.Lf);
                elseif isfield(S, 'LF') && ~isempty(S.LF)
                    LF_val = mean(S.LF);
                end

                % FFT
                N = length(ir);
                N_fft = 2^nextpow2(N);
                X = fft(ir, N_fft);

                % Luftdämpfungskorrektur
                [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T_val, LF_val, dist);
                X_corrected = X .* A_lin(:);

                % Zurück in Zeitbereich
                ir_corrected = real(ifft(X_corrected));
                ir_corrected = ir_corrected(1:N);

                % Maximum der korrigierten IR
                FS_global_corrected = max(FS_global_corrected, max(abs(ir_corrected)));
            else
                % Quelle: keine Korrektur
                FS_global_corrected = max(FS_global_corrected, max(abs(ir)));
            end
        end
    catch ME
        fprintf('  [!] Fehler bei %s: %s\n', files(i).name, ME.message);
    end
end

if FS_global_raw == 0, FS_global_raw = 1; end
if FS_global_corrected == 0, FS_global_corrected = 1; end

fprintf('\n--- Ergebnis ---\n');
fprintf('FS_global (RAW):        %.5f\n', FS_global_raw);
fprintf('FS_global (KORRIGIERT): %.5f\n', FS_global_corrected);
fprintf('Faktor:                 %.2f (%.2f dB)\n', ...
        FS_global_corrected/FS_global_raw, ...
        20*log10(FS_global_corrected/FS_global_raw));

fprintf('\n💡 Empfehlung:\n');
fprintf('   Verwende FS_global_corrected = %.5f in step1_process_data.m\n', FS_global_corrected);
fprintf('   Dies verhindert positive dBFS-Werte.\n');
