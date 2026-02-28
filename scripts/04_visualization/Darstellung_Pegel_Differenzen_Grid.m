%% Darstellung_Pegel_Differenzen_Grid.m
% Visualisiert die Messpositionen und Pegel (Leq) im Raum.
% Verbindet benachbarte Punkte (horizontal/vertikal) und zeigt die Pegeldifferenz an.

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

if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end

% Darstellungsmodus
use_terzband = true;   % true: nur ein Terzband, false: Summenpegel
target_frequency = 20000; % Hz, nur relevant wenn use_terzband = true

% FS_global Referenz (für dBFS)
FS_global_ref = 1.0;
procFiles = dir(fullfile(dataDir, 'Proc_*.mat'));
if ~isempty(procFiles)
    try
        tmp = load(fullfile(dataDir, procFiles(1).name), 'Result');
        if isfield(tmp.Result, 'meta') && isfield(tmp.Result.meta, 'FS_global_used')
            FS_global_ref = tmp.Result.meta.FS_global_used;
        end
    catch
    end
end

%% Geometrie Definition
% Manuelle Definition der Grid-Struktur für Pfade
% Format: {Start-Name, End-Name}
connections = {
    % Horizontal (Längsrichtung)
    'Q1', 'M13'; 'M13', 'M14'; 'M14', 'M15';  % y = 0
   % 'M9', 'M10'; 'M10', 'M11'; 'M11', 'M12';  % y = 0.3
   % 'M5', 'M6';  'M6', 'M7';   'M7', 'M8';    % y = 0.6
   % 'M1', 'M2';  'M2', 'M3';   'M3', 'M4';    % y = 1.2
    
    % Vertikal (Höhenrichtung)
    'Q1', 'M9';   'M9', 'M5';   'M5', 'M1';   % x = 0
    %'M13', 'M10'; 'M10', 'M6';  'M6', 'M2';   % x = 0.3
    %'M14', 'M11'; 'M11', 'M7';  'M7', 'M3';   % x = 0.6
    %'M15', 'M12'; 'M12', 'M8';  'M8', 'M4';   % x = 1.2
    
    % Diagonal (von der Quelle weg)
    'Q1', 'M10'; 'M10', 'M7'; 'M7', 'M4';
    'Q1', 'M11'; 'M11', 'M8'; 
    'Q1', 'M6';  'M6', 'M3';
};

% Koordinaten Mapping (Name -> [x, y])
posMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

% Geometrie laden (für M1-M15)
try
    geo = get_geometry();
    for i = 1:length(geo)
        key = sprintf('M%d', geo(i).pos);
        posMap(key) = [geo(i).x, geo(i).y];
    end
catch
    warning('get_geometry nicht gefunden oder fehlerhaft. Nutze Fallback-Koordinaten.');
    % Fallback-Layout (4x4 Raster wie in README: x=[0,0.3,0.6,1.2], y=[1.2,0.6,0.3,0])
    x_vals = [0, 0.3, 0.6, 1.2];
    y_vals = [1.2, 0.6, 0.3, 0];
    pos = 1;
    for yi = 1:numel(y_vals)
        for xi = 1:numel(x_vals)
            if yi == 4 && xi == 1
                % Q1 ist keine M-Position
                continue;
            end
            key = sprintf('M%d', pos);
            posMap(key) = [x_vals(xi), y_vals(yi)];
            pos = pos + 1;
        end
    end
end

% Quelle manuell hinzufügen
posMap('Q1') = [0, 0];

%% Varianten identifizieren
dirInfo = dir(fullfile(dataDir, 'Proc_*.mat'));
matFiles = {dirInfo.name};

variantNames = {};
for i = 1:numel(matFiles)
    tokens = regexp(matFiles{i}, '^Proc_(.*?)_Pos', 'tokens', 'once', 'ignorecase');
    if isempty(tokens), tokens = regexp(matFiles{i}, '^Proc_(.*?)_Quelle', 'tokens', 'once', 'ignorecase'); end
    if ~isempty(tokens), variantNames{end+1} = tokens{1}; end
end
variantNames = unique(variantNames);

if isempty(variantNames)
    warning('Keine Varianten gefunden.');
    return;
end

%% Zuerst Variante 1 laden (Referenz für Differenzen)
refVariante = variantNames{1};
refLevelMap = containers.Map('KeyType', 'char', 'ValueType', 'double');

% Referenz-Quelle laden
srcFile = fullfile(dataDir, sprintf('Proc_%s_Quelle.mat', refVariante));
if exist(srcFile, 'file')
    D = load(srcFile, 'Result');
    if use_terzband && isfield(D.Result, 'freq') && isfield(D.Result.freq, 'terz_dbfs') && isfield(D.Result.freq, 'f_center')
        f_center = D.Result.freq.f_center;
        [~, idx] = min(abs(f_center - target_frequency));
        refLevelMap('Q1') = D.Result.freq.terz_dbfs(idx);
    else
        ir = D.Result.time.ir;
        refLevelMap('Q1') = 10 * log10((sum(ir.^2) + eps) / (FS_global_ref^2));
    end
end

% Referenz-Receiver laden
for i = 1:15
    recFile = fullfile(dataDir, sprintf('Proc_%s_Pos%d.mat', refVariante, i));
    if exist(recFile, 'file')
        D = load(recFile, 'Result');
        key = sprintf('M%d', i);
        if use_terzband && isfield(D.Result, 'freq') && isfield(D.Result.freq, 'terz_dbfs') && isfield(D.Result.freq, 'f_center')
            f_center = D.Result.freq.f_center;
            [~, idx] = min(abs(f_center - target_frequency));
            refLevelMap(key) = D.Result.freq.terz_dbfs(idx);
        else
            refLevelMap(key) = D.Result.freq.sum_level;
        end
    end
end

%% Plotting Loop
for v = 1:numel(variantNames)
    variante = variantNames{v};
    fprintf('Verarbeite: %s\n', variante);

    % Daten sammeln
    levelMap = containers.Map('KeyType', 'char', 'ValueType', 'double');

    % 1. Quelle laden
    srcFile = fullfile(dataDir, sprintf('Proc_%s_Quelle.mat', variante));
    if exist(srcFile, 'file')
        D = load(srcFile, 'Result');
        if use_terzband && isfield(D.Result, 'freq') && isfield(D.Result.freq, 'terz_dbfs') && isfield(D.Result.freq, 'f_center')
            f_center = D.Result.freq.f_center;
            [~, idx] = min(abs(f_center - target_frequency));
            levelMap('Q1') = D.Result.freq.terz_dbfs(idx);
        else
            ir = D.Result.time.ir;
            levelMap('Q1') = 10 * log10((sum(ir.^2) + eps) / (FS_global_ref^2));
        end
    end

    % 2. Receiver laden
    for i = 1:15
        recFile = fullfile(dataDir, sprintf('Proc_%s_Pos%d.mat', variante, i));
        if exist(recFile, 'file')
            D = load(recFile, 'Result');
            key = sprintf('M%d', i);
            if use_terzband && isfield(D.Result, 'freq') && isfield(D.Result.freq, 'terz_dbfs') && isfield(D.Result.freq, 'f_center')
                f_center = D.Result.freq.f_center;
                [~, idx] = min(abs(f_center - target_frequency));
                levelMap(key) = D.Result.freq.terz_dbfs(idx);
            else
                levelMap(key) = D.Result.freq.sum_level;
            end
        end
    end

    if isempty(levelMap)
        continue;
    end

    % Figure erstellen (höher für Legende unten)
    fig = figure('Position', [100, 100, 1000, 900], 'Color', 'w');
    hold on; grid on;

    % Prüfen ob es sich um Variante 1 handelt
    isReferenceVariant = (v == 1);

    % Farbskala vorbereiten
    nC = 256;

    if isReferenceVariant
        % Variante 1: Weiß -> Gelb -> Dunkelrot (Hoher Pegel = Rot)
        allLevels = values(levelMap);
        allLevels = [allLevels{:}];
        minL = min(allLevels);
        maxL = max(allLevels);

        % Segment 1: Weiß [1, 1, 1] -> Gelb [1, 1, 0]
        r1 = linspace(1, 1, nC/2)'; g1 = linspace(1, 1, nC/2)'; b1 = linspace(1, 0, nC/2)';
        % Segment 2: Gelb [1, 1, 0] -> Dunkelrot [0.8, 0, 0]
        r2 = linspace(1, 0.8, nC/2)'; g2 = linspace(1, 0, nC/2)'; b2 = linspace(0, 0, nC/2)';
        cmap = [ [r1; r2], [g1; g2], [b1; b2] ];
    else
        % Varianten 2-4: Blau (negativ) -> Weiß (0) -> Rot (positiv)
        % Differenzen zu Variante 1 berechnen für Farbskala
        diffLevels = [];
        keys = levelMap.keys;
        for k = 1:length(keys)
            name = keys{k};
            if isKey(refLevelMap, name)
                diffLevels(end+1) = levelMap(name) - refLevelMap(name);
            end
        end

        % Symmetrische Skala um 0
        if isempty(diffLevels)
            maxAbsDiff = 1; % Fallback falls keine Differenzen vorhanden
        else
            maxAbsDiff = max(abs(diffLevels));
            if maxAbsDiff == 0, maxAbsDiff = 1; end
        end
        minL = -maxAbsDiff;
        maxL = maxAbsDiff;

        % Blau [0, 0, 1] -> Weiß [1, 1, 1] -> Rot [1, 0, 0]
        r1 = linspace(0, 1, nC/2)'; g1 = linspace(0, 1, nC/2)'; b1 = linspace(1, 1, nC/2)';
        r2 = linspace(1, 1, nC/2)'; g2 = linspace(1, 0, nC/2)'; b2 = linspace(1, 0, nC/2)';
        cmap = [ [r1; r2], [g1; g2], [b1; b2] ];
    end

    colormap(cmap);
    caxis([minL, maxL]);

    if isReferenceVariant
        % VARIANTE 1: Pfade mit Differenzen zwischen benachbarten Punkten zeichnen
        for k = 1:size(connections, 1)
            p1_name = connections{k, 1};
            p2_name = connections{k, 2};

            if isKey(posMap, p1_name) && isKey(posMap, p2_name) && ...
               isKey(levelMap, p1_name) && isKey(levelMap, p2_name)

                coord1 = posMap(p1_name);
                coord2 = posMap(p2_name);

                lev1 = levelMap(p1_name);
                lev2 = levelMap(p2_name);
                diff_val = lev2 - lev1;

                % Pfeil zeichnen (Quiver) - dezent
                dp = coord2 - coord1;
                % Verkürzen damit Pfeil nicht von Punkten verdeckt wird
                shorten = 0.15;
                quiver(coord1(1) + dp(1)*shorten, coord1(2) + dp(2)*shorten, dp(1)*(1-2*shorten), dp(2)*(1-2*shorten), 0, ...
                    'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'MaxHeadSize', 0.4, 'AutoScale', 'off');

                % Differenztext neben der Mitte (versetzt, um Überlagerung zu vermeiden)
                mid = (coord1 + coord2) / 2;

                % Offset senkrecht zur Pfeilrichtung berechnen
                dp_norm = dp / norm(dp);
                perp = [-dp_norm(2), dp_norm(1)] * 0.05;  % Senkrechter Versatz

                text(mid(1) + perp(1), mid(2) + perp(2), sprintf('%.1f', diff_val), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                    'FontSize', 12, 'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', 'none', 'Margin', 1);
            end
        end
    end

    % Punkte zeichnen
    keys = levelMap.keys;
    for k = 1:length(keys)
        name = keys{k};
        if isKey(posMap, name)
            coord = posMap(name);
            val = levelMap(name);

            if isReferenceVariant
                % Variante 1: Farbe basierend auf absolutem Pegel
                colorVal = val;
                labelText = sprintf('%s\n%.1f', name, val);
            else
                % Varianten 2-4: Farbe basierend auf Differenz zu Variante 1
                if isKey(refLevelMap, name)
                    diffToRef = val - refLevelMap(name);
                    colorVal = diffToRef;
                    % Vorzeichen anzeigen
                    if diffToRef >= 0
                        labelText = sprintf('%s\n+%.1f', name, diffToRef);
                    else
                        labelText = sprintf('%s\n%.1f', name, diffToRef);
                    end
                else
                    colorVal = val;
                    labelText = sprintf('%s\n%.1f', name, val);
                end
            end

            % Punkt zeichnen
            scatter(coord(1), coord(2), 250, colorVal, 'filled', 'MarkerEdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.5);

            % Label positionieren
            if isReferenceVariant
                % Variante 1: M1, M5, M9 rechts diagonal, Rest links diagonal
                if strcmp(name, 'M1') || strcmp(name, 'M5') || strcmp(name, 'M9')
                    text(coord(1)+0.04, coord(2)+0.06, labelText, ...
                        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'FontSize', 12, 'FontWeight', 'bold');
                else
                    text(coord(1)-0.04, coord(2)+0.06, labelText, ...
                        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 12, 'FontWeight', 'bold');
                end
            else
                % Varianten 2-4: zentriert über den Positionen
                text(coord(1), coord(2)+0.08, labelText, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12, 'FontWeight', 'bold');
            end
        end
    end

    % Layout
    xlabel('Längsrichtung x [m]');
    ylabel('Höhe y [m]');

    cb = colorbar;
    if isReferenceVariant
        if use_terzband
            cb.Label.String = sprintf('Terzpegel [dBFS] bei %.0f Hz', target_frequency);
        else
            cb.Label.String = 'Summenpegel L_{eq} [dBFS] über 30ms';
        end
    else
        cb.Label.String = 'Pegeldifferenz zu Variante 1 [dB]';
    end

    axis equal;
    xlim([-0.1, 1.4]);
    ylim([-0.1, 1.4]);

    % Legende (Dummy-Objekte) - Position unten
    hL = [];
    if isReferenceVariant
        hL(1) = scatter(NaN, NaN, 100, [0.8 0 0], 'filled', 'o', 'MarkerEdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.5, 'DisplayName', 'Messpunkt (Farbe = Pegel)');
        hL(2) = plot([NaN NaN], [NaN NaN], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'DisplayName', 'Pfad mit Pegeldifferenz [dB]');
    else
        hL(1) = scatter(NaN, NaN, 100, [0.8 0 0], 'filled', 'o', 'MarkerEdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.5, 'DisplayName', 'Messpunkt (Farbe = Pegel)');
        hL(2) = plot(NaN, NaN, 'w', 'DisplayName', sprintf('Werte = Differenz zu %s [dB]', strrep(refVariante, '_', ' ')));
    end
    legend(hL, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10);

    % Speichern
    if use_terzband
        baseName = sprintf('Grid_Differenzen_%s_%dHz', variante, round(target_frequency));
    else
        baseName = sprintf('Grid_Differenzen_%s', variante);
    end
    outFile = fullfile(outputDir, [baseName '.png']);
    saveas(fig, outFile);
    savefig(fig, fullfile(outputDir, [baseName '.fig']));
    fprintf('  Gespeichert: %s (.png + .fig)\n', outFile);


end

fprintf('\nFertig. Plots in "%s" gespeichert.\n', outputDir);
