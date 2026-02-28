%% Pfade und Energieverluste Visualisierung
% Zeigt alle Pfade von der Quelle zu den Messpunkten mit Energieverlust

clear;
clc;
close all;

% Arbeitsverzeichnis
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end
% Repository-Pfade initialisieren (navigiert zum Root)
if exist('../../functions', 'dir')
    cd('../../.');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');
init_repo_paths();

%% Einstellungen
dataDir = 'processed';
outputDir = 'Plots';
fs = 500e3;

if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end

%% Geometrie laden
geo = get_geometry();

%% Varianten identifizieren
dirInfo = dir(fullfile(dataDir, 'Proc_*.mat'));
matFiles = {dirInfo.name};

variantNames = {};
for i = 1:numel(matFiles)
    tokens = regexp(matFiles{i}, '^Proc_(.*?)_Pos', 'tokens', 'once', 'ignorecase');
    if ~isempty(tokens), variantNames{end+1} = tokens{1}; end
end
variantNames = unique(variantNames);

if isempty(variantNames)
    warning('Keine Varianten gefunden.');
    return;
end

%% Globale Referenz
FS_global_ref = 1.0;
if ~isempty(matFiles)
    try
        tmp = load(fullfile(dataDir, matFiles{1}), 'Result');
        if isfield(tmp.Result.meta, 'FS_global_used')
            FS_global_ref = tmp.Result.meta.FS_global_used;
        end
    catch
    end
end

%% Visualisierung für jede Variante
for v = 1:numel(variantNames)
    variante = variantNames{v};
    fprintf('Verarbeite: %s\n', variante);

    % Daten für alle Positionen sammeln
    positions = [];
    distances = [];
    levels_dB = [];
    energies = [];
    x_coords = [];
    y_coords = [];

    for i = 1:15
        filePath = fullfile(dataDir, sprintf('Proc_%s_Pos%d.mat', variante, i));

        if exist(filePath, 'file')
            try
                D = load(filePath, 'Result');

                % Geometrie für diese Position
                geoIdx = find([geo.pos] == i);
                if isempty(geoIdx), continue; end

                % Daten extrahieren
                level_dB = D.Result.freq.sum_level;
                energy = D.Result.time.metrics.energy;
                dist = geo(geoIdx).distance;
                x = geo(geoIdx).x;
                y = geo(geoIdx).y;

                positions(end+1) = i;
                distances(end+1) = dist;
                levels_dB(end+1) = level_dB;
                energies(end+1) = energy;
                x_coords(end+1) = x;
                y_coords(end+1) = y;
            catch ME
                fprintf('  Fehler bei Position %d: %s\n', i, ME.message);
            end
        end
    end

    if isempty(positions)
        fprintf('  Keine Daten gefunden.\n');
        continue;
    end

    %% 2D Plot mit Pfaden
    fig = figure('Position', [100, 100, 1000, 800]);

    % Quelle bei (0,0)
    x_source = 0;
    y_source = 0;

    % Farbskala basierend auf dB-Werten
    cmap = [linspace(1, 0, 256)', linspace(1, 0, 256)', linspace(1, 0.5, 256)'];
    colormap(cmap);

    min_dB = min(levels_dB);
    max_dB = max(levels_dB);
    dB_range = max_dB - min_dB;
    if dB_range == 0
        dB_range = 1; % Guard gegen Division durch 0 bei konstanten Pegeln
    end

    % Referenzpegel (Quelle) - nehme den höchsten gemessenen Pegel als Referenz
    reference_dB = max(levels_dB);

    % Linien von Quelle zu jedem Messpunkt zeichnen
    hold on;

    for i = 1:length(positions)
        % Farbe basierend auf Pegel (je höher desto dunkler blau)
        norm_val = (levels_dB(i) - min_dB) / dB_range;
        color_idx = max(1, min(256, round(norm_val * 255 + 1)));
        line_color = cmap(color_idx, :);

        % Linie zeichnen
        plot([x_source, x_coords(i)], [y_source, y_coords(i)], ...
            'Color', line_color, 'LineWidth', 3);

        % Messpunkt als Kreis
        scatter(x_coords(i), y_coords(i), 150, line_color, 'filled', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

        % Verlust berechnen (relativ zur Referenz)
        loss_dB = reference_dB - levels_dB(i);

        % Label mit Position und dB-Wert am Messpunkt
        text(x_coords(i), y_coords(i), sprintf('  M%d\n  %.1f dB', positions(i), levels_dB(i)), ...
            'FontSize', 9, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
    end

    % Quelle markieren (größer und prominenter)
    scatter(x_source, y_source, 300, 'r', 'filled', 'p', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 2.5);
    text(x_source, y_source-0.2, 'Quelle', ...
        'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'LineWidth', 1);

    % Colorbar
    cb = colorbar;
    cb.Label.String = 'Summenpegel [dBFS]';
    cb.Label.FontSize = 12;
    caxis([min_dB max_dB]);

    % Achsen
    axis equal;
    grid on;
    xlabel('X [m]', 'FontSize', 12);
    ylabel('Y [m]', 'FontSize', 12);
    title(sprintf('Energiepfade - %s', strrep(variante, '_', ' ')), ...
        'FontSize', 14, 'FontWeight', 'bold');

    % Limits mit etwas Rand - Ursprung bei (0,0)
    x_range = [min([x_coords, x_source]) max([x_coords, x_source])];
    y_range = [min([y_coords, y_source]) max([y_coords, y_source])];
    margin = 0.2;
    xlim([x_range(1)-margin, x_range(2)+margin]);
    ylim([y_range(1)-margin, y_range(2)+margin]);

    % Textbox mit Energieverlusten außerhalb des Plots
    loss_text = 'Energieverluste:\n';
    for i = 1:length(positions)
        loss_dB = reference_dB - levels_dB(i);
        loss_text = sprintf('%sM%d: −%.1f dB\n', loss_text, positions(i), loss_dB);
    end
    annotation('textbox', [0.01, 0.5, 0.12, 0.4], 'String', loss_text, ...
        'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'w', ...
        'EdgeColor', 'k', 'LineWidth', 1.5, 'FitBoxToText', 'on');

    % Achsenbeschriftung oben und rechts
    set(gca, 'XAxisLocation', 'top', 'YAxisLocation', 'right');

    hold off;

    % Speichern
    outputFile = fullfile(outputDir, sprintf('Pfade_Energieverlust_%s.png', variante));
    saveas(fig, outputFile);
    fprintf('  Gespeichert: %s\n', outputFile);

    %% 3D Plot mit Höhe = Pegel
    fig2 = figure('Position', [150, 150, 1000, 800]);
    hold on;

    % 3D Linien von Quelle zu jedem Messpunkt
    for i = 1:length(positions)
        % Farbe basierend auf Pegel
        norm_val = (levels_dB(i) - min_dB) / dB_range;
        color_idx = max(1, min(256, round(norm_val * 255 + 1)));
        line_color = cmap(color_idx, :);

        % Linie in 3D (Z = Pegel)
        plot3([x_source, x_coords(i)], [y_source, y_coords(i)], ...
            [reference_dB, levels_dB(i)], 'Color', line_color, 'LineWidth', 3);

        % Messpunkt in 3D
        scatter3(x_coords(i), y_coords(i), levels_dB(i), 150, line_color, 'filled', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

        % Verlust berechnen
        loss_dB = reference_dB - levels_dB(i);

        % Label am Messpunkt
        text(x_coords(i), y_coords(i), levels_dB(i), sprintf('  M%d\n  %.1f dB', positions(i), levels_dB(i)), ...
            'FontSize', 9, 'FontWeight', 'bold');
    end

    % Quelle in 3D (größer und prominenter)
    scatter3(x_source, y_source, reference_dB, 300, 'r', 'filled', 'p', ...
        'MarkerEdgeColor', 'k', 'LineWidth', 2.5);
    text(x_source, y_source, reference_dB+2, sprintf('Quelle\n%.1f dB', reference_dB), ...
        'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'EdgeColor', 'k', 'LineWidth', 1);

    % Colorbar
    colormap(cmap);
    cb = colorbar;
    cb.Label.String = 'Summenpegel [dBFS]';
    cb.Label.FontSize = 12;
    caxis([min_dB max_dB]);

    % Achsen
    grid on;
    xlabel('X [m]', 'FontSize', 12);
    ylabel('Y [m]', 'FontSize', 12);
    zlabel('Pegel [dBFS]', 'FontSize', 12);
    title(sprintf('Energiepfade 3D - %s', strrep(variante, '_', ' ')), ...
        'FontSize', 14, 'FontWeight', 'bold');
    view(45, 30);

    % Achsenbeschriftung oben und rechts
    set(gca, 'XAxisLocation', 'origin', 'YAxisLocation', 'origin');

    % Textbox mit Energieverlusten außerhalb des Plots (3D)
    loss_text_3d = 'Energieverluste:\n';
    for i = 1:length(positions)
        loss_dB = reference_dB - levels_dB(i);
        loss_text_3d = sprintf('%sM%d: −%.1f dB\n', loss_text_3d, positions(i), loss_dB);
    end
    annotation('textbox', [0.01, 0.5, 0.12, 0.4], 'String', loss_text_3d, ...
        'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'w', ...
        'EdgeColor', 'k', 'LineWidth', 1.5, 'FitBoxToText', 'on');

    hold off;

    % Speichern
    outputFile3D = fullfile(outputDir, sprintf('Pfade_Energieverlust_3D_%s.png', variante));
    saveas(fig2, outputFile3D);
    fprintf('  Gespeichert: %s\n', outputFile3D);

    close(fig);
    close(fig2);
end

fprintf('\nFertig. Plots gespeichert in "%s"\n', outputDir);
