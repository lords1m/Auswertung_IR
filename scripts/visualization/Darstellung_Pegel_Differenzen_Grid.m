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

%% Einstellungen
dataDir = 'processed';
outputDir = 'Plots';

if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end

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
    % Fallback falls get_geometry fehlt
    % (Hier nur exemplarisch, normalerweise sollte get_geometry funktionieren)
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

%% Plotting Loop
for v = 1:numel(variantNames)
    variante = variantNames{v};
    fprintf('Verarbeite: %s\n', variante);
10
    % Daten sammeln
    levelMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
    
    % 1. Quelle laden
    srcFile = fullfile(dataDir, sprintf('Proc_%s_Quelle.mat', variante));
    if exist(srcFile, 'file')
        D = load(srcFile, 'Result');
        ir = D.Result.time.ir;
        levelMap('Q1') = 10 * log10(sum(ir.^2) + eps);
    end
    
    % 2. Receiver laden
    for i = 1:15
        recFile = fullfile(dataDir, sprintf('Proc_%s_Pos%d.mat', variante, i));
        if exist(recFile, 'file')
            D = load(recFile, 'Result');
            key = sprintf('M%d', i);
            levelMap(key) = D.Result.freq.sum_level;
        end
    end
    
    if isempty(levelMap)
        continue;
    end
    
    % Figure erstellen
    fig = figure('Position', [100, 100, 1000, 800], 'Color', 'w');
    hold on; grid on;
    
    % Farbskala vorbereiten
    allLevels = values(levelMap);
    allLevels = [allLevels{:}];
    minL = min(allLevels);
    maxL = max(allLevels);
    
    % Custom Colormap: Weiß -> Gelb -> Dunkelrot (Hoher Pegel = Rot)
    nC = 256;
    % Segment 1: Weiß [1, 1, 1] -> Gelb [1, 1, 0]
    r1 = linspace(1, 1, nC/2)'; g1 = linspace(1, 1, nC/2)'; b1 = linspace(1, 0, nC/2)';
    % Segment 2: Gelb [1, 1, 0] -> Dunkelrot [0.8, 0, 0]
    r2 = linspace(1, 0.8, nC/2)'; g2 = linspace(1, 0, nC/2)'; b2 = linspace(0, 0, nC/2)';
    
    cmap = [ [r1; r2], [g1; g2], [b1; b2] ];
    colormap(cmap);
    
    caxis([minL, maxL]);
    
    % 1. Verbindungen zeichnen (Pfade)
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
            
            % Differenztext in der Mitte
            mid = (coord1 + coord2) / 2;
            
            % Textfarbe: Schwarz
            txtColor = 'k';
            
            text(mid(1), mid(2), sprintf('%.1f', diff_val), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 9, 'Color', txtColor, 'BackgroundColor', 'w', 'EdgeColor', 'none', 'Margin', 1);
        end
    end
    
    % 2. Punkte zeichnen
    keys = levelMap.keys;
    for k = 1:length(keys)
        name = keys{k};
        if isKey(posMap, name)
            coord = posMap(name);
            val = levelMap(name);
            
            % Farbe basierend auf Pegel
            % scatter nutzt caxis automatisch wenn CData gesetzt ist
            scatter(coord(1), coord(2), 250, val, 'filled', 'MarkerEdgeColor', 'none');
            scatter(coord(1), coord(2), 250, val, 'filled', 'MarkerEdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.5);
            
            % Label
            text(coord(1)-0.04, coord(2)+0.04, sprintf('%s\n%.1f', name, val), ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
        end
    end
    
    % Layout
    xlabel('Längsrichtung x [m]');
    ylabel('Höhe y [m]');
    title(sprintf('Pegelverteilung und Differenzen - %s', strrep(variante, '_', ' ')), 'FontSize', 14);
    
    cb = colorbar;
    cb.Label.String = 'Summenpegel L_{eq} [dBFS] über 30ms';
    
    axis equal;
    xlim([-0.1, 1.4]);
    ylim([-0.1, 1.4]);
    
    % Legende (Dummy-Objekte)
    hL = [];
    hL(1) = scatter(NaN, NaN, 100, [0.8 0 0], 'filled', 'o', 'MarkerEdgeColor', 'none', 'DisplayName', 'Messpunkt (Farbe = Pegel)');
    hL(1) = scatter(NaN, NaN, 100, [0.8 0 0], 'filled', 'o', 'MarkerEdgeColor', [0.4 0.4 0.4], 'LineWidth', 0.5, 'DisplayName', 'Messpunkt (Farbe = Pegel)');
    hL(2) = plot([NaN NaN], [NaN NaN], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 1, 'DisplayName', 'Pfad mit Pegeldifferenz [dB]');
    legend(hL, 'Location', 'westoutside', 'FontSize', 10);
    
    
    % Speichern
    outFile = fullfile(outputDir, sprintf('Grid_Differenzen_%s.png', variante));
    saveas(fig, outFile);
    fprintf('  Gespeichert: %s\n', outFile);
    
    close(fig);
end

fprintf('\nFertig. Plots in "%s" gespeichert.\n', outputDir);