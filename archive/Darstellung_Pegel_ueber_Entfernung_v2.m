%% Pegel über Entfernung
% Plot L vs. s mit idealer 1/r-Linie
% Nutzt verarbeitete Daten aus 'processed'

clear; clc; close all;

%% Einstellungen

varianten = {'Variante_1', 'Variante_3'};
procDir = 'processed';

% Positionen und Entfernungen [m]
positions_info = struct();

% Reihe 1
positions_info(1).pos = '1';  positions_info(1).x = 0;   positions_info(1).y = 1.2;
positions_info(2).pos = '2';  positions_info(2).x = 0.3;   positions_info(2).y = 1.2;
positions_info(3).pos = '3';  positions_info(3).x = 0.6;   positions_info(3).y = 1.2;
positions_info(4).pos = '4';  positions_info(4).x = 1.2;   positions_info(4).y = 1.2;

% Reihe 2
positions_info(5).pos = '5';  positions_info(5).x = 0;   positions_info(5).y = 0.6;
positions_info(6).pos = '6';  positions_info(6).x = 0.3;   positions_info(6).y = 0.6;
positions_info(7).pos = '7';  positions_info(7).x = 0.6;   positions_info(7).y = 0.6;
positions_info(8).pos = '8';  positions_info(8).x = 1.2;   positions_info(8).y = 0.6;

% Reihe 3
positions_info(9).pos = '9';   positions_info(9).x = 0;   positions_info(9).y = 0.3;
positions_info(10).pos = '10'; positions_info(10).x = 0.3;  positions_info(10).y = 0.3;
positions_info(11).pos = '11'; positions_info(11).x = 0.6;  positions_info(11).y = 0.3;
positions_info(12).pos = '12'; positions_info(12).x = 1.2;  positions_info(12).y = 0.3;

% Reihe 4 (Q1 = Quelle bei 0,0)
positions_info(13).pos = '13'; positions_info(13).x = 0.3;  positions_info(13).y = 0;
positions_info(14).pos = '14'; positions_info(14).x = 0.6;  positions_info(14).y = 0;
positions_info(15).pos = '15'; positions_info(15).x = 1.2;  positions_info(15).y = 0;

% Quelle
source_x = 0;
source_y = 0;

% Entfernungen berechnen
for i = 1:length(positions_info)
    dx = positions_info(i).x - source_x;
    dy = positions_info(i).y - source_y;
    positions_info(i).distance = sqrt(dx^2 + dy^2);
end

%% Daten laden

fprintf('Lade Daten aus %s...\n', procDir);

results = struct();

for v_idx = 1:numel(varianten)
    variante = varianten{v_idx};
    fprintf('\n--- %s ---\n', variante);

    results(v_idx).variante = variante;
    results(v_idx).positions = [];
    results(v_idx).distances = [];
    results(v_idx).levels = [];

    for p_idx = 1:length(positions_info)
        pos = positions_info(p_idx).pos;
        distance = positions_info(p_idx).distance;

        if distance == 0, continue; end  % Quelle überspringen

        % Lade processed Datei
        filename = fullfile(procDir, sprintf('Proc_%s_Pos%s.mat', variante, pos));

        if ~exist(filename, 'file')
            continue;
        end

        try
            Data = load(filename);
            if isfield(Data, 'Result') && isfield(Data.Result, 'freq')
                level = Data.Result.freq.sum_level;  % Summenpegel in dBFS

                results(v_idx).positions(end+1) = str2double(pos);
                results(v_idx).distances(end+1) = distance;
                results(v_idx).levels(end+1) = level;

                fprintf('  Pos %s: L = %.2f dBFS\n', pos, level);
            end
        catch
            continue;
        end
    end
end

%% Ideale 1/r-Kurve

all_distances = [];
all_levels = [];
for v_idx = 1:numel(results)
    all_distances = [all_distances, results(v_idx).distances];
    all_levels = [all_levels, results(v_idx).levels];
end

min_dist = min(all_distances);
max_dist = max(all_distances);

% Referenz: gemessener Pegel bei kleinster Entfernung
levels_at_min = [];
for v_idx = 1:numel(results)
    idx = find(abs(results(v_idx).distances - min_dist) < 0.01);
    if ~isempty(idx)
        levels_at_min = [levels_at_min, results(v_idx).levels(idx(1))];
    end
end

L_ref = mean(levels_at_min);
r_ref = min_dist;
fprintf('\nReferenz: L_ref = %.2f dBFS bei r_ref = %.2f m\n', L_ref, r_ref);

% Ideale Kurve: L(r) = L_ref - 20*log10(r/r_ref)
distance_ideal = linspace(min_dist, max_dist, 200);
L_ideal = L_ref - 20*log10(distance_ideal / r_ref);

%% Plot

colors = lines(numel(varianten));

figure('Position', [100, 100, 1200, 700]);
hold on;

% Differenzlinien zwischen gleichen Positionen (dezent im Hintergrund)
if numel(results) == 2
    common_pos = intersect(results(1).positions, results(2).positions);
    for pos = common_pos
        idx1 = find(results(1).positions == pos);
        idx2 = find(results(2).positions == pos);
        if ~isempty(idx1) && ~isempty(idx2)
            x = results(1).distances(idx1);
            y1 = results(1).levels(idx1);
            y2 = results(2).levels(idx2);

            % Dezente graue Linie
            plot([x x], [y1 y2], '-', 'Color', [0.7 0.7 0.7], ...
                'LineWidth', 1.5, 'HandleVisibility', 'off');
        end
    end
end

for v_idx = 1:numel(results)
    if isempty(results(v_idx).distances), continue; end

    [sorted_dist, sort_idx] = sort(results(v_idx).distances);
    sorted_levels = results(v_idx).levels(sort_idx);
    sorted_pos = results(v_idx).positions(sort_idx);

    scatter(sorted_dist, sorted_levels, 150, colors(v_idx, :), ...
        'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
        'DisplayName', strrep(results(v_idx).variante, '_', ' '));

    % Positionsnummern
    for i = 1:length(sorted_dist)
        text(sorted_dist(i), sorted_levels(i), sprintf('  %d', sorted_pos(i)), ...
            'FontSize', 8, 'Color', colors(v_idx, :));
    end
end

% Ideale 1/r-Kurve
plot(distance_ideal, L_ideal, 'k--', 'LineWidth', 2, ...
    'DisplayName', 'Ideal 1/r (Halbraum)');

hold off;
grid on;
xlabel('Entfernung [m]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Summenpegel [dBFS]', 'FontSize', 12, 'FontWeight', 'bold');
title('Summenpegel über Entfernung', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 10);
xlim([0, max_dist * 1.1]);
set(gcf, 'Color', 'w');

fprintf('\n✓ Plot erstellt\n');

%% Statistik

fprintf('\n=== Statistik ===\n');

for v_idx = 1:numel(results)
    if isempty(results(v_idx).distances), continue; end

    fprintf('\n--- %s ---\n', results(v_idx).variante);

    % Abweichung von ideal
    L_ideal_meas = L_ref - 20*log10(results(v_idx).distances / r_ref);
    deviation = results(v_idx).levels - L_ideal_meas;

    fprintf('  Mittelwert:  %+.2f dB\n', mean(deviation));
    fprintf('  STD:          %.2f dB\n', std(deviation));
    fprintf('  Max:         %+.2f dB\n', max(deviation));
    fprintf('  Min:         %+.2f dB\n', min(deviation));
end

fprintf('\n✓ Fertig\n');
