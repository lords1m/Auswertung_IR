%% Analyse_Reflexionsgrad.m
% Berechnet den Reflexionsfaktor am offenen Ende der Straßenschlucht
% durch Analyse der Impulsantwort im Zeitbereich.
%
% Methode:
% 1. Lädt die Impulsantwort einer Messposition.
% 2. Identifiziert den Direktschall.
% 3. Berechnet die theoretische Laufzeit der Reflexion vom offenen Ende.
% 4. Bestimmt das Verhältnis der Amplituden unter Berücksichtigung von
%    1/r-Dämpfung und Luftabsorption.

clear; clc; close all;

%% Konfiguration

% Zu analysierende Datei (Wähle eine Position nahe der Quelle oder Mitte)
target_variant = 'Variante_1';
target_pos = 4; % Position 4 (x=1.2m, y=1.2m) eignet sich gut

% Geometrie des Modells
c = 343; % Schallgeschwindigkeit [m/s]

% Analyse-Frequenz (für Filterung und Dämpfungskorrektur)
center_freq = 40000; % 40 kHz

% Pfade
procDir = 'processed';
% Repository-Pfade initialisieren (navigiert zum Root)
if exist('../../functions', 'dir')
    cd('../../.');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');

%% 1. Positionen definieren (aus Darstellung_Pegel_ueber_Entfernung.m übernommen)
positions_info = struct();
% Reihe 1
positions_info(1).pos = 1;  positions_info(1).x = 0;   positions_info(1).y = 1.2;
positions_info(2).pos = 2;  positions_info(2).x = 0.3;   positions_info(2).y = 1.2;
positions_info(3).pos = 3;  positions_info(3).x = 0.6;   positions_info(3).y = 1.2;
positions_info(4).pos = 4;  positions_info(4).x = 1.2;   positions_info(4).y = 1.2;
% Reihe 2
positions_info(5).pos = 5;  positions_info(5).x = 0;     positions_info(5).y = 0.6;
positions_info(6).pos = 6;  positions_info(6).x = 0.3;   positions_info(6).y = 0.6;
positions_info(7).pos = 7;  positions_info(7).x = 0.6;   positions_info(7).y = 0.6;
positions_info(8).pos = 8;  positions_info(8).x = 1.2;   positions_info(8).y = 0.6;
% Reihe 3
positions_info(9).pos = 9;  positions_info(9).x = 0;     positions_info(9).y = 0.3;
positions_info(10).pos = 10; positions_info(10).x = 0.3; positions_info(10).y = 0.3;
positions_info(11).pos = 11; positions_info(11).x = 0.6; positions_info(11).y = 0.3;
positions_info(12).pos = 12; positions_info(12).x = 1.2; positions_info(12).y = 0.3;
% Reihe 4
positions_info(13).pos = 13; positions_info(13).x = 0.3; positions_info(13).y = 0;
positions_info(14).pos = 14; positions_info(14).x = 0.6; positions_info(14).y = 0;
positions_info(15).pos = 15; positions_info(15).x = 1.2; positions_info(15).y = 0;

% Finde Koordinaten der gewählten Position
pos_idx = find([positions_info.pos] == target_pos);
if isempty(pos_idx)
    % Fallback falls Position nicht in Liste (manuelle Eingabe möglich)
    fprintf('Warnung: Position %d nicht in Geometrie-Liste. Nutze Distanz aus Datei.\n', target_pos);
    pos_x = NaN; 
else
    pos_x = positions_info(pos_idx).x;
    pos_y = positions_info(pos_idx).y;
end

%% 2. Daten laden
filename = fullfile(procDir, sprintf('Proc_%s_Pos%d.mat', target_variant, target_pos));
if ~exist(filename, 'file')
    error('Datei nicht gefunden: %s', filename);
end

fprintf('Lade Datei: %s\n', filename);
D = load(filename);
R = D.Result;
fs = R.meta.fs;
ir = R.time.ir;

% Zeitvektor
t = (0:length(ir)-1) / fs;

%% 3. Signalverarbeitung (Bandpass-Filterung)
% Reflexion ist frequenzabhängig, daher filtern wir auf die Zielfrequenz
fprintf('Filtere Signal bei %.0f Hz...\n', center_freq);
[b, a] = butter(4, [center_freq*0.8, center_freq*1.2]/(fs/2), 'bandpass');
ir_filt = filtfilt(b, a, ir);

% Einhüllende (Hilbert) oder ETC (dB)
env = abs(hilbert(ir_filt));
env_db = 20*log10(env / max(env) + eps);

%% 4. Analyse der Peaks

% A) Direktschall finden (Maximum)
[amp_dir, idx_dir] = max(env);
t_dir = t(idx_dir);

% Distanz Direktschall (aus Geometrie oder Laufzeit)
if ~isnan(pos_x)
    % Distanz basierend auf relativen Koordinaten (Quelle bei 0,0)
    dist_dir = sqrt(pos_x^2 + pos_y^2);
else
    % Fallback: Schätzung aus Laufzeit (Achtung: Trigger-Verzögerung möglich)
    dist_dir = t_dir * c; 
end

%% 5. Theoretische Reflexionen berechnen
% Annahmen:
% - pos_x ist Längsrichtung (relativ zur Quelle)
% - pos_y ist Höhe (z) (relativ zur Quelle)
% - Empfänger ist mittig in der Breite (y=0)

x_rec = pos_x; % Relativ zur Quelle
z_rec = pos_y; % Höhe

% Geometrie-Parameter (Abstand von der Quelle/Achse)
d_side = 0.7;  % Seitenwand (Halbe Breite von 1.4m)
d_top  = 1.3;  % Decke/Oben
d_end  = 2.5;  % Stirnseite (Länge/2)

refl_list = struct('name', {}, 'dist', {}, 't_expected', {});
cnt = 1;

% 1. Seitenwände (2x, symmetrisch bei y=0)
% Pfad: sqrt(x^2 + (2*d_side)^2 + z^2)
dist_side = sqrt(x_rec^2 + (2*d_side)^2 + z_rec^2);
refl_list(cnt).name = 'Seite (2x)'; refl_list(cnt).dist = dist_side; cnt=cnt+1;

% 2. Oben (Decke)
% Pfad: sqrt(x^2 + (2*d_top - z)^2)  (Spiegelquelle bei z = 2*d_top)
dist_top = sqrt(x_rec^2 + (2*d_top - z_rec)^2);
refl_list(cnt).name = 'Oben'; refl_list(cnt).dist = dist_top; cnt=cnt+1;

% 3. Stirnseite 1 (in Blickrichtung, Forward)
% Pfad: Längs = d_end + (d_end - x_rec) = 2*d_end - x_rec
dist_end1 = sqrt((2*d_end - x_rec)^2 + z_rec^2);
refl_list(cnt).name = 'Ende (Vorne)'; refl_list(cnt).dist = dist_end1; cnt=cnt+1;

% 4. Stirnseite 2 (Rückwand, Backward)
% Pfad: Längs = d_end + (d_end + x_rec) = 2*d_end + x_rec
dist_end2 = sqrt((2*d_end + x_rec)^2 + z_rec^2);
refl_list(cnt).name = 'Ende (Hinten)'; refl_list(cnt).dist = dist_end2; cnt=cnt+1;

% Für die Berechnung von R nutzen wir das Echo von der Oberseite
dist_target_ref = dist_top;
t_ref_expected = t_dir + (dist_target_ref - dist_dir)/c;

%% 6. Peak-Suche für Reflexionsfaktor (Oben)

% Suche Peak im Fenster um die erwartete Zeit (+/- 1.0 ms)
win_width = 1e-3; 
idx_search_start = round((t_ref_expected - win_width) * fs);
idx_search_end = round((t_ref_expected + win_width) * fs);

% Bounds check
idx_search_start = max(1, idx_search_start);
idx_search_end = min(length(env), idx_search_end);

[amp_ref, idx_local] = max(env(idx_search_start:idx_search_end));
if isempty(amp_ref)
    error('Kein Peak gefunden. Prüfen Sie die Geometrie (pos_x/y) und das Suchfenster.');
end

idx_ref = idx_search_start + idx_local - 1;
t_ref = t(idx_ref);

fprintf('\n--- Analyse Ergebnisse (Pos %d) ---\n', target_pos);
fprintf('Direktschall:       t = %.4f s (d = %.2f m), Amp = %.4f\n', t_dir, dist_dir, amp_dir);
fprintf('Ziel-Reflexion:     t = %.4f s (d = %.2f m) [Oben]\n', t_ref_expected, dist_target_ref);
fprintf('Gefundener Peak:    t = %.4f s, Amp = %.4f\n', t_ref, amp_ref);

fprintf('\n--- Alle theoretischen Reflexionen ---\n');
for i = 1:length(refl_list)
    delta_d = refl_list(i).dist - dist_dir;
    refl_list(i).t_expected = t_dir + delta_d / c;
    fprintf('%-15s: t = %.4f s (d = %.2f m)\n', refl_list(i).name, refl_list(i).t_expected, refl_list(i).dist);
end

%% 7. Berechnung des Reflexionsfaktors R (für Oben)

% Luftdämpfung berechnen (alpha in dB/m)
% Nutze airabsorb falls vorhanden, sonst Schätzung
try
    [A_dB_100m, ~, f_air] = airabsorb(101.325, fs, 1024, 20, 50, 100);
    % Interpoliere alpha für center_freq
    alpha_dB_per_m = interp1(f_air, A_dB_100m, center_freq);
    fprintf('Luftdämpfung (%.0f Hz): %.2f dB/m\n', center_freq, alpha_dB_per_m);
catch
    warning('Funktion airabsorb nicht gefunden. Nutze Schätzwert.');
    alpha_dB_per_m = 1.2; % Grober Schätzwert für 40kHz
end

% Dämpfungskorrektur (in linearer Amplitude)
% Wir müssen den reflektierten Schall "verstärken", um den Verlust auf dem Weg zu kompensieren
loss_geo_dir = 1 / dist_dir;
loss_air_dir = 10^(-alpha_dB_per_m * dist_dir / 20);

loss_geo_ref = 1 ./ dist_target_ref;
loss_air_ref = 10^(-alpha_dB_per_m * dist_target_ref / 20);

% Amplitude an der Quelle (rekonstruiert)
A0_from_dir = amp_dir / (loss_geo_dir * loss_air_dir);

% Amplitude der Reflexion (rekonstruiert vor Reflexion, aber nach Weg)
% P_ref_measured = A0 * R * loss_geo_ref * loss_air_ref
% => R = P_ref_measured / (A0 * loss_geo_ref * loss_air_ref)
% => R = P_ref_measured / ( (P_dir / (loss_geo_dir * loss_air_dir)) * loss_geo_ref * loss_air_ref )

R = amp_ref ./ (A0_from_dir * loss_geo_ref * loss_air_ref);

fprintf('\nReflexionsfaktor |R|: %.2f (%.1f %%)\n', R, R*100);
fprintf('Reflexionsdämpfung:   %.1f dB\n', 20*log10(R));

%% 8. Plot
max_t = max([refl_list.t_expected]);

figure('Position', [100, 100, 1000, 600], 'Color', 'w');
subplot(2,1,1);
plot(t*1000, ir_filt);
grid on;
xlabel('Zeit [ms]'); ylabel('Amplitude');
title(sprintf('Gefilterte Impulsantwort (%.0f Hz)', center_freq));
xlim([0, (max_t + 0.005)*1000]);

subplot(2,1,2);
plot(t*1000, env_db, 'k'); hold on;

% Markierungen
plot(t_dir*1000, 20*log10(amp_dir), 'bo', 'MarkerFaceColor', 'b');
text(t_dir*1000, 20*log10(amp_dir)+2, 'Direkt', 'Color', 'b', 'FontWeight', 'bold');

plot(t_ref*1000, 20*log10(amp_ref), 'ro', 'MarkerFaceColor', 'r');
text(t_ref*1000, 20*log10(amp_ref)+2, sprintf('Reflexion\n(R=%.2f)', R), 'Color', 'r', 'FontWeight', 'bold');

% Alle theoretischen Linien plotten
colors = {'g', 'm', 'r', 'c'};
for i = 1:length(refl_list)
    xline(refl_list(i).t_expected*1000, '--', refl_list(i).name, 'Color', colors{mod(i-1,4)+1}, 'LabelVerticalAlignment', 'bottom');
end

grid on;
xlabel('Zeit [ms]'); ylabel('Pegel [dB]');
title('Energy Time Curve (ETC)');
xlim([0, (max_t + 0.005)*1000]);
ylim([-60, 0]);
