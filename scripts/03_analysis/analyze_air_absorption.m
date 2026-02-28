%% Luftdämpfungs-Analyse für Ultraschall
% Berechnet und visualisiert die Luftdämpfung und Korrektur-Faktoren
% für verschiedene Frequenzen und Distanzen
%
% Zeigt: Wie stark ist die Luftdämpfungskorrektur wirklich?
%
% Autor: Luftdämpfungs-Analyse
% Datum: 2026-01-19

clear; clc; close all;

% Repository-Pfade initialisieren
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');
init_repo_paths();

fprintf('=== Luftdämpfungs-Analyse für Ultraschall ===\n\n');

%% Konfiguration
fs = 500e3;              % Abtastrate
N_fft = 2^15;           % FFT-Länge für glatte Kurven
T = 20;                 % Temperatur [°C]
LF = 50;                % Luftfeuchte [%]
p_a = 101.325;          % Luftdruck [kPa]

% Distanzen analysieren
distances = [0.3, 0.6, 1.0, 1.5, 2.0, 3.0];  % Meter

% Frequenzbänder (Terzband-Mitten)
freq_bands = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];

fprintf('Parameter:\n');
fprintf('  Temperatur:   %.1f °C\n', T);
fprintf('  Luftfeuchte:  %.1f %%\n', LF);
fprintf('  Luftdruck:    %.3f kPa\n', p_a);
fprintf('  Abtastrate:   %.0f Hz\n\n', fs);

%% Berechnung für verschiedene Distanzen

% Tabelle für Ergebnisse
results = struct();
results.distance = distances;
results.freq = freq_bands;

fprintf('--- Luftdämpfung und Korrektur-Faktoren ---\n\n');

figure('Position', [100, 100, 1600, 900], 'Color', 'w');

% Subplot 1: Dämpfung in dB über Frequenz
subplot(2,3,1);
hold on; grid on;
colors = parula(length(distances));

for d_idx = 1:length(distances)
    dist = distances(d_idx);

    % Berechne Luftdämpfung
    [A_dB, A_lin, f] = airabsorb(p_a, fs, N_fft, T, LF, dist);

    % Plot
    plot(f/1000, A_dB, 'LineWidth', 1.5, 'Color', colors(d_idx,:), ...
         'DisplayName', sprintf('%.1f m', dist));

    % Speichere für spätere Analyse
    results.A_dB{d_idx} = A_dB;
    results.A_lin{d_idx} = A_lin;
    results.f = f;
end

xlim([4, 63]);
xlabel('Frequenz [kHz]');
ylabel('Dämpfung [dB]');
title('Luftdämpfung über Frequenz');
legend('Location', 'northwest');
set(gca, 'XScale', 'log');
set(gca, 'XTick', [4 5 6.3 8 10 12.5 16 20 25 31.5 40 50 63]);
ylim([0 50]);

% Subplot 2: Korrektur-Faktor (linear) über Frequenz
subplot(2,3,2);
hold on; grid on;

for d_idx = 1:length(distances)
    dist = distances(d_idx);
    A_lin = results.A_lin{d_idx};
    f = results.f;

    plot(f/1000, A_lin, 'LineWidth', 1.5, 'Color', colors(d_idx,:), ...
         'DisplayName', sprintf('%.1f m', dist));
end

xlim([4, 63]);
xlabel('Frequenz [kHz]');
ylabel('Verstärkungsfaktor (linear)');
title('Luftdämpfungs-KORREKTUR (A_{lin} = 10^{A_{dB}/20})');
legend('Location', 'northwest');
set(gca, 'XScale', 'log');
set(gca, 'XTick', [4 5 6.3 8 10 12.5 16 20 25 31.5 40 50 63]);
set(gca, 'YScale', 'log');
yline(1, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');

% Subplot 3: Dämpfung bei spezifischen Terzbändern
subplot(2,3,3);
hold on; grid on;

freq_highlight = [10000, 20000, 40000, 63000];  % kHz
colors_highlight = lines(length(freq_highlight));

for f_idx = 1:length(freq_highlight)
    fc = freq_highlight(f_idx);

    % Finde nächste Frequenz in f-Vektor
    [~, idx] = min(abs(results.f - fc));

    damping_vs_dist = zeros(size(distances));
    for d_idx = 1:length(distances)
        damping_vs_dist(d_idx) = results.A_dB{d_idx}(idx);
    end

    plot(distances, damping_vs_dist, '-o', 'LineWidth', 2, ...
         'MarkerSize', 8, 'Color', colors_highlight(f_idx,:), ...
         'DisplayName', sprintf('%d kHz', fc/1000));
end

xlabel('Distanz [m]');
ylabel('Dämpfung [dB]');
title('Dämpfung über Distanz für verschiedene Frequenzen');
legend('Location', 'northwest');
grid on;

% Subplot 4: Tabelle der Korrektur-Faktoren bei 3m
subplot(2,3,4);
axis off;

dist_table = 3.0;  % Meter
d_idx_table = find(distances == dist_table);

if ~isempty(d_idx_table)
    A_dB_3m = results.A_dB{d_idx_table};
    A_lin_3m = results.A_lin{d_idx_table};
    f = results.f;

    % Erstelle Tabelle
    table_data = {};
    table_data{1,1} = 'Frequenz [kHz]';
    table_data{1,2} = 'Dämpfung [dB]';
    table_data{1,3} = 'Korrektur-Faktor';

    row = 2;
    for fb = freq_bands
        [~, idx] = min(abs(f - fb));

        table_data{row, 1} = sprintf('%.1f', fb/1000);
        table_data{row, 2} = sprintf('%.2f dB', A_dB_3m(idx));
        table_data{row, 3} = sprintf('×%.2f', A_lin_3m(idx));
        row = row + 1;
    end

    % Display Tabelle
    text(0.1, 0.95, sprintf('Luftdämpfung bei %.1f m Distanz:', dist_table), ...
         'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized');

    y_pos = 0.85;
    for r = 1:size(table_data, 1)
        if r == 1
            % Header
            text(0.1, y_pos, table_data{r,1}, 'FontSize', 10, 'FontWeight', 'bold', 'Units', 'normalized');
            text(0.4, y_pos, table_data{r,2}, 'FontSize', 10, 'FontWeight', 'bold', 'Units', 'normalized');
            text(0.7, y_pos, table_data{r,3}, 'FontSize', 10, 'FontWeight', 'bold', 'Units', 'normalized');
        else
            % Data
            text(0.1, y_pos, table_data{r,1}, 'FontSize', 9, 'Units', 'normalized');
            text(0.4, y_pos, table_data{r,2}, 'FontSize', 9, 'Units', 'normalized');
            text(0.7, y_pos, table_data{r,3}, 'FontSize', 9, 'Units', 'normalized');
        end
        y_pos = y_pos - 0.06;
    end
end

% Subplot 5: Warum positive dBFS?
subplot(2,3,5);
axis off;

text(0.1, 0.95, 'WARUM POSITIVE dBFS-WERTE?', ...
     'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized', 'Color', 'r');

explanation = {
    ''
    '1. FS_global wird aus RAW IRs berechnet:'
    '   FS_global = max(|ir_raw|) = z.B. 0.8'
    ''
    '2. Terzspektrum wird KORRIGIERT:'
    '   X_korr = X_raw × A_lin'
    '   Bei 40 kHz, 3m: A_lin ≈ 5.6x !'
    ''
    '3. Nach Korrektur kann gelten:'
    '   band_energy_korr > FS_global²'
    ''
    '4. dBFS-Berechnung:'
    '   L = 10·log₁₀(E_korr / FS_global²)'
    '   Wenn E_korr > FS_global²:'
    '   → log₁₀(>1) > 0'
    '   → L_dBFS > 0 dB ✗'
    ''
    'LÖSUNG:'
    'FS_global aus korrigierten IRs berechnen!'
};

y_pos = 0.85;
for i = 1:length(explanation)
    if contains(explanation{i}, 'LÖSUNG')
        text(0.05, y_pos, explanation{i}, 'FontSize', 10, 'FontWeight', 'bold', ...
             'Units', 'normalized', 'Color', [0 0.6 0]);
    elseif contains(explanation{i}, '✗')
        text(0.05, y_pos, explanation{i}, 'FontSize', 9, ...
             'Units', 'normalized', 'Color', 'r');
    else
        text(0.05, y_pos, explanation{i}, 'FontSize', 9, ...
             'Units', 'normalized');
    end
    y_pos = y_pos - 0.045;
end

% Subplot 6: Maximaler Verstärkungsfaktor
subplot(2,3,6);
hold on; grid on;

max_factors = zeros(size(distances));
for d_idx = 1:length(distances)
    max_factors(d_idx) = max(results.A_lin{d_idx});
end

bar(distances, max_factors, 'FaceColor', [0.2 0.6 0.8]);
xlabel('Distanz [m]');
ylabel('Maximaler Verstärkungsfaktor');
title('Max. Korrektur-Faktor über Distanz');
grid on;

% Annotationen
for d_idx = 1:length(distances)
    text(distances(d_idx), max_factors(d_idx) + 0.5, ...
         sprintf('×%.1f', max_factors(d_idx)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end

sgtitle(sprintf('Luftdämpfungs-Analyse (T=%.1f°C, LF=%.1f%%)', T, LF), ...
        'FontSize', 14, 'FontWeight', 'bold');

%% Konsolen-Ausgabe: Detaillierte Tabelle

fprintf('\n=== DETAILLIERTE ERGEBNISSE ===\n\n');

fprintf('Luftdämpfung bei 3m Distanz:\n');
fprintf('%-12s | %-15s | %-20s | %-15s\n', 'Frequenz', 'Dämpfung', 'Korrektur-Faktor', 'dB-Verstärkung');
fprintf('%s\n', repmat('-', 1, 70));

d_idx_3m = find(distances == 3.0);
if ~isempty(d_idx_3m)
    A_dB_3m = results.A_dB{d_idx_3m};
    A_lin_3m = results.A_lin{d_idx_3m};
    f = results.f;

    for fb = freq_bands
        [~, idx] = min(abs(f - fb));

        fprintf('%-12s | %-15s | %-20s | %-15s\n', ...
                sprintf('%.1f kHz', fb/1000), ...
                sprintf('%.2f dB', A_dB_3m(idx)), ...
                sprintf('×%.2f (linear)', A_lin_3m(idx)), ...
                sprintf('+%.2f dB', 20*log10(A_lin_3m(idx))));
    end
end

fprintf('\n\n=== INTERPRETATION ===\n\n');
fprintf('Bei 63 kHz und 3m Distanz:\n');
[~, idx_63k] = min(abs(f - 63000));
damping_63k = A_dB_3m(idx_63k);
factor_63k = A_lin_3m(idx_63k);

fprintf('  - Luftdämpfung: %.1f dB\n', damping_63k);
fprintf('  - Korrektur-Faktor: ×%.1f\n', factor_63k);
fprintf('  - Signal wird um Faktor %.1f VERSTÄRKT!\n', factor_63k);
fprintf('\n');
fprintf('Wenn das korrigierte Signal an dieser Frequenz mehr Energie\n');
fprintf('hat als das globale Maximum aller RAW IRs (FS_global),\n');
fprintf('dann entstehen POSITIVE dBFS-Werte.\n');
fprintf('\n');
fprintf('Beispiel-Rechnung:\n');
fprintf('  FS_global (raw) = 0.8\n');
fprintf('  Signal bei 63 kHz (raw): 0.05\n');
fprintf('  Nach Korrektur: 0.05 × %.1f = %.2f\n', factor_63k, 0.05 * factor_63k);
fprintf('  Falls dies > 0.8: Positive dBFS!\n');

fprintf('\n=== FAZIT ===\n');
fprintf('Die Luftdämpfungskorrektur ist MASSIV bei hohen Frequenzen!\n');
fprintf('Verstärkungsfaktoren von 5-20x sind normal bei Ultraschall.\n');
fprintf('→ FS_global MUSS aus korrigierten IRs berechnet werden!\n\n');

% Save Figure
saveas(gcf, 'Plots/Air_Absorption_Analysis.png');
fprintf('Plot gespeichert: Plots/Air_Absorption_Analysis.png\n');
