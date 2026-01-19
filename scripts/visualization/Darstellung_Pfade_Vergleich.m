%% Pfadvergleich über Varianten
% Vergleicht Leq-Werte entlang definierter Pfade für alle Varianten

clear;
clc;
close all;

scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end

%% Einstellungen

varianten = {'Variante_1', 'Variante_2', 'Variante_3', 'Variante_4'};

% Pfade definieren
% Format: {'Pfadname', [Mikrofon-Positionen], [x_min, x_max], [y_min, y_max]}
% Falls Limits leer [] sind, werden die global berechneten Werte verwendet.
pfade = {
    'Pfad 1: M13-M14-M15', [13, 14, 15], [0.2, 1.2], [-2, 12];
    'Pfad 2: M9-M5-M1',    [9, 5, 1],    [0, 2.0], [-5, 10];
    'Pfad 3: M10-M7-M4',   [10, 7, 4],   [0.4, 1.8], [-5, 10];
    'Pfad 4: M11-M8',      [11, 8],      [0, 2.0], [-5, 10];
    'Pfad 5: M6-M3',       [6, 3],       [0, 2.0], [-5, 10]
};

%% Auswahl: Welche Pfade sollen verglichen werden?
% Setze die Indizes der gewünschten Pfade (1-5)
% Beispiele:
%   pfade_auswahl = [1];           % Nur Pfad 1
%   pfade_auswahl = [1, 2];        % Pfad 1 und 2
%   pfade_auswahl = [1, 2, 3, 4, 5]; % Alle Pfade
%   pfade_auswahl = 1:5;           % Alle Pfade

pfade_auswahl = [1];  % <-- HIER ANPASSEN

%% Auswahl: Welche Varianten sollen verglichen werden?
% Setze die Indizes der gewünschten Varianten (1-4)
% 1 = Variante_1, 2 = Variante_2, 3 = Variante_3, 4 = Variante_4
% Beispiele:
%varianten_auswahl = [1, 2];    % Nur Variante 1 und 4
%   varianten_auswahl = [1, 2, 3, 4]; % Alle Varianten
%   varianten_auswahl = 1:4;       % Alle Varianten

varianten_auswahl = [1, 2, 3, 4];  % <-- HIER ANPASSEN

% Positionen definieren (Quelle bei 0,0)
positions_info = struct();

% Reihe 1
positions_info(1).pos = 1;  positions_info(1).x = 0;   positions_info(1).y = 1.2;
positions_info(2).pos = 2;  positions_info(2).x = 0.3;   positions_info(2).y = 1.2;
positions_info(3).pos = 3;  positions_info(3).x = 0.6;   positions_info(3).y = 1.2;
positions_info(4).pos = 4;  positions_info(4).x = 1.2;   positions_info(4).y = 1.2;

% Reihe 2
positions_info(5).pos = 5;  positions_info(5).x = 0;   positions_info(5).y = 0.6;
positions_info(6).pos = 6;  positions_info(6).x = 0.3;   positions_info(6).y = 0.6;
positions_info(7).pos = 7;  positions_info(7).x = 0.6;   positions_info(7).y = 0.6;
positions_info(8).pos = 8;  positions_info(8).x = 1.2;   positions_info(8).y = 0.6;

% Reihe 3
positions_info(9).pos = 9;   positions_info(9).x = 0;   positions_info(9).y = 0.3;
positions_info(10).pos = 10; positions_info(10).x = 0.3;  positions_info(10).y = 0.3;
positions_info(11).pos = 11; positions_info(11).x = 0.6;  positions_info(11).y = 0.3;
positions_info(12).pos = 12; positions_info(12).x = 1.2;  positions_info(12).y = 0.3;

% Reihe 4
positions_info(13).pos = 13; positions_info(13).x = 0.3;  positions_info(13).y = 0;
positions_info(14).pos = 14; positions_info(14).x = 0.6;  positions_info(14).y = 0;
positions_info(15).pos = 15; positions_info(15).x = 1.2;  positions_info(15).y = 0;

% Quelle
source_x = 0;
source_y = 0;

% Distanzen berechnen
for i = 1:length(positions_info)
    dx = positions_info(i).x - source_x;
    dy = positions_info(i).y - source_y;
    positions_info(i).distance = sqrt(dx^2 + dy^2);
end

procDir = 'processed';

%% Daten laden

if ~exist(procDir, 'dir')
    error('Ordner "%s" nicht gefunden', procDir);
end

fprintf('Lade Pegel für ausgewählte Varianten...\n');
results = struct();

% Nur ausgewählte Varianten laden
varianten_zu_laden = varianten(varianten_auswahl);

for v_idx = 1:numel(varianten_zu_laden)
    variante = varianten_zu_laden{v_idx};

    results(v_idx).variante = variante;
    results(v_idx).positions = [];
    results(v_idx).distances = [];
    results(v_idx).leq_values = [];

    for p_idx = 1:length(positions_info)
        position = positions_info(p_idx).pos;
        distance = positions_info(p_idx).distance;

        if distance == 0, continue; end

        posStr = num2str(position);
        filename = fullfile(procDir, sprintf('Proc_%s_Pos%s.mat', variante, posStr));

        if ~exist(filename, 'file')
            continue;
        end

        try
            Data = load(filename);
            if isfield(Data, 'Result') && isfield(Data.Result, 'freq')
                % Leq aus FFT-Spektrum: Summe der Terzenergien
                if isfield(Data.Result.freq, 'terz_dbfs')
                    terz_dbfs = Data.Result.freq.terz_dbfs;
                    % Energie aus Terzpegeln: E = sum(10^(L/10))
                    E_terz = 10.^(terz_dbfs / 10);
                    E_total = sum(E_terz);
                    leq_value = E_total;
                elseif isfield(Data.Result.freq, 'sum_level')
                    % Fallback: Summenpegel verwenden
                    leq_value = 10^(Data.Result.freq.sum_level / 10);
                else
                    continue;
                end

                results(v_idx).positions(end+1) = position;
                results(v_idx).distances(end+1) = distance;
                results(v_idx).leq_values(end+1) = leq_value;
            end
        catch
            continue;
        end
    end

    fprintf('  %s: %d Positionen geladen\n', variante, length(results(v_idx).positions));
end

%% In absolute dB umrechnen

% Leq aus FFT-Energie: 10 * log10(E_total)
for v_idx = 1:numel(results)
    results(v_idx).levels_dB = 10 * log10(results(v_idx).leq_values);
end

fprintf('Leq aus FFT-Spektrum (Summe Terzenergien) berechnet\n');

%% Farben und Marker für Varianten

colors = [
    0.0 0.4470 0.7410;  % Blau
    0.8500 0.3250 0.0980;  % Orange
    0.9290 0.6940 0.1250;  % Gelb
    0.4940 0.1840 0.5560   % Lila
];

markers = {'o', 's', 'd', '^'};
line_styles = {'-', '-', '-', '-'};

%% Globale Achsenlimits berechnen (für einheitliche Darstellung)

% Alle Distanzen und Levels sammeln für ausgewählte Pfade
global_min_dist = inf;
global_max_dist = 0;
global_min_level = inf;
global_max_level = -inf;

for pfad_idx = pfade_auswahl
    pfad_positionen = pfade{pfad_idx, 2};

    for pos = pfad_positionen
        pos_idx = find([positions_info.pos] == pos);
        if ~isempty(pos_idx)
            dist = positions_info(pos_idx).distance;
            global_min_dist = min(global_min_dist, dist);
            global_max_dist = max(global_max_dist, dist);
        end
    end

    for v_idx = 1:numel(results)
        for pos = pfad_positionen
            pos_result_idx = find(results(v_idx).positions == pos, 1);
            if ~isempty(pos_result_idx)
                level = results(v_idx).levels_dB(pos_result_idx);
                global_min_level = min(global_min_level, level);
                global_max_level = max(global_max_level, level);
            end
        end
    end
end

% Sinnvolle Achsenlimits setzen
% X-Achse: Start bei 0, Ende bei 2m (da max Distanz ~1.7m)
x_lim = [0.3, 1.8];

% Y-Achse: Dynamisch basierend auf Daten, aber mit "schönen" Grenzen
if isinf(global_min_level) || isinf(global_max_level)
    y_lim = [-5, 10]; % Fallback falls keine Daten
else
    % Puffer von 5 dB oben und unten, gerundet auf 5er Schritte
    y_min_rounded = floor(global_min_level / 5) * 5 - 5;
    y_max_rounded = ceil(global_max_level / 5) * 5 + 5;
    y_lim = [y_min_rounded, y_max_rounded];
end

level_range = y_lim(2) - y_lim(1);

fprintf('Achsenlimits: x=[%.2f, %.2f] m, y=[%.1f, %.1f] dB\n', x_lim(1), x_lim(2), y_lim(1), y_lim(2));

%% Plot für jeden ausgewählten Pfad erstellen

for pfad_idx = pfade_auswahl
    pfad_name = pfade{pfad_idx, 1};
    pfad_positionen = pfade{pfad_idx, 2};

    % Spezifische Limits für diesen Pfad abrufen (falls definiert)
    cur_x_lim = x_lim; % Fallback auf global
    cur_y_lim = y_lim; % Fallback auf global
    
    if size(pfade, 2) >= 3 && ~isempty(pfade{pfad_idx, 3})
        cur_x_lim = pfade{pfad_idx, 3};
    end
    if size(pfade, 2) >= 4 && ~isempty(pfade{pfad_idx, 4})
        cur_y_lim = pfade{pfad_idx, 4};
    end
    cur_level_range = cur_y_lim(2) - cur_y_lim(1);

    fig = figure('Position', [100 + pfad_idx*50, 100 + pfad_idx*50, 1000, 600], 'Visible', 'on');
    hold on;

    legend_entries = {};
    plot_handles = [];

    % Sammle Positionen für einmalige Beschriftung
    label_positions = struct('dist', {}, 'pos', {});

    % Jede Variante plotten
    for v_idx = 1:numel(results)
        if isempty(results(v_idx).positions)
            continue;
        end

        % Daten für diesen Pfad extrahieren
        pfad_dist = [];
        pfad_level = [];
        pfad_pos_labels = [];

        for pos = pfad_positionen
            pos_result_idx = find(results(v_idx).positions == pos, 1);
            if ~isempty(pos_result_idx)
                pfad_dist(end+1) = results(v_idx).distances(pos_result_idx);
                pfad_level(end+1) = results(v_idx).levels_dB(pos_result_idx);
                pfad_pos_labels(end+1) = pos;
            end
        end

        if isempty(pfad_dist)
            continue;
        end

        % Nach Entfernung sortieren
        [pfad_dist_sorted, sort_idx] = sort(pfad_dist);
        pfad_level_sorted = pfad_level(sort_idx);
        pfad_pos_sorted = pfad_pos_labels(sort_idx);

        % Linie mit kleinen Punkten plotten
        h = plot(pfad_dist_sorted, pfad_level_sorted, ...
            line_styles{v_idx}, ...
            'Color', colors(v_idx, :), ...
            'LineWidth', 1.5, ...
            'Marker', '.', ...
            'MarkerSize', 12);

        plot_handles(end+1) = h;
        legend_entries{end+1} = strrep(results(v_idx).variante, '_', ' ');

        % Positionen für Beschriftung speichern (nur beim ersten Durchlauf)
        if v_idx == 1
            for i = 1:length(pfad_dist_sorted)
                label_positions(i).dist = pfad_dist_sorted(i);
                label_positions(i).pos = pfad_pos_sorted(i);
            end
        end
    end

    % Positionsnummern einmalig beschriften (in schwarz, oberhalb der Daten)
    for i = 1:length(label_positions)
        text(label_positions(i).dist, cur_y_lim(2) - 0.02*cur_level_range, ...
            sprintf('M%d', label_positions(i).pos), ...
            'FontSize', 10, 'Color', 'k', ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold');
    end

    hold off;
    grid on;

    xlabel('Entfernung von der Quelle [m]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('L_{eq} [dBFS]', 'FontSize', 12, 'FontWeight', 'bold');
    title(pfad_name, 'FontSize', 14, 'FontWeight', 'bold');

    legend(plot_handles, legend_entries, 'Location', 'northwest', 'FontSize', 10);

    set(gca, 'FontSize', 11);
    set(gcf, 'Color', 'w');

    % Einheitliche Achsenlimits
    xlim(cur_x_lim);
    ylim(cur_y_lim);

    % Speichern
    save_name = sprintf('Plots/Pfadvergleich_%d.png', pfad_idx);
    if ~exist('Plots', 'dir')
        mkdir('Plots');
    end
    saveas(fig, save_name);
    fprintf('Gespeichert: %s\n', save_name);
end

fprintf('\nFertig!\n');
