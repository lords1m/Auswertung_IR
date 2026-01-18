%% Heatmap Gesamtenergie
% Erstellt eine statische Heatmap der Gesamtenergie an jedem Messpunkt.

clear;
clc;
close all;

% Arbeitsverzeichnis
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end
addpath('functions');

%% Einstellungen
dataDir = 'processed';
outputDir = 'Plots';
fs = 500e3;

% Grid Layout
positionsLayout = {
    'M1',  'M2',  'M3',  'M4';
    'M5',  'M6',  'M7',  'M8';
    'M9',  'M10', 'M11', 'M12';
    'Q1',  'M13', 'M14', 'M15';
};

%% Setup
if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputDir,'dir'), mkdir(outputDir); end

dirInfo = dir(fullfile(dataDir, 'Proc_*.mat'));
matFiles = {dirInfo.name};

% Varianten identifizieren
variantNames = {};
for i = 1:numel(matFiles)
    tokens = regexp(matFiles{i}, '^Proc_(.*?)_Pos', 'tokens', 'once', 'ignorecase');
    if isempty(tokens), tokens = regexp(matFiles{i}, '^Proc_(.*?)_Quelle', 'tokens', 'once', 'ignorecase'); end
    if ~isempty(tokens), variantNames{end+1} = tokens{1}; end
end
variantNames = unique(variantNames);

if isempty(variantNames)
    warning('Keine Varianten in "%s" gefunden. Prüfen Sie den Pfad oder führen Sie step1 aus.', dataDir);
    return;
end

%% Globale Referenz
MaxAmp_global = 1;
if ~isempty(matFiles)
    try
        tmp = load(fullfile(dataDir, matFiles{1}), 'Result');
        if isfield(tmp.Result.meta, 'FS_global_used')
            MaxAmp_global = tmp.Result.meta.FS_global_used;
            fprintf('Globale Referenz aus Metadaten: %.5f\n', MaxAmp_global);
        end
    catch
        fprintf('Konnte globale Referenz nicht laden, nutze 1.0\n');
    end
end

%% Heatmap Erstellung für jede Variante
for v = 1:numel(variantNames)
    variante = variantNames{v};
    fprintf('Verarbeite: %s\n', variante);

    % Daten laden
    [rows, cols] = size(positionsLayout);
    energies = nan(rows, cols);

    for r = 1:rows
        for c = 1:cols
            posName = positionsLayout{r, c};
            filePath = find_mat_file(dataDir, matFiles, variante, posName);

            if ~isempty(filePath)
                try
                    D = load(filePath, 'Result');
                    ir = D.Result.time.ir;

                    % Gesamtenergie berechnen: Integral über |signal|^2
                    % Alternativ: sum(signal.^2) / fs für Energie in Joule-ähnlicher Einheit
                    totalEnergy = sum(ir.^2) / fs;

                    % In dB umrechnen (relativ zur globalen Referenz)
                    totalEnergy_dB = 10 * log10((totalEnergy + eps) / (MaxAmp_global^2));

                    energies(r, c) = totalEnergy_dB;
                catch ME
                    fprintf('  Fehler bei %s: %s\n', posName, ME.message);
                    energies(r, c) = nan;
                end
            end
        end
    end

    % Heatmap zeichnen
    fig = figure('Position', [100, 100, 800, 600]);

    % Patch-Objekt für Felder mit Abständen erstellen
    boxSize = 0.5; % Größe der Felder (0.5 = 50% Lücke)
    offset = boxSize / 2;
    vertices = [];
    faces = [];
    count = 0;

    % Geometrie erstellen (Zeilenweise)
    for r = 1:rows
        for c = 1:cols
            count = count + 1;
            % Vertices für Quadrat bei (c,r)
            v = [c-offset, r-offset; c+offset, r-offset; c+offset, r+offset; c-offset, r+offset];
            vertices = [vertices; v];
            faces = [faces; (count-1)*4 + (1:4)];
        end
    end

    hPatch = patch('Vertices', vertices, 'Faces', faces, ...
        'FaceVertexCData', energies(:), ...
        'FaceColor', 'flat', 'EdgeColor', 'k', 'LineWidth', 1.5);

    % Custom Colormap: Hell (Weiß) zu Dunkel (Blau)
    nC = 1024;
    colormap([linspace(1, 0, nC)', linspace(1, 0, nC)', linspace(1, 0.5, nC)']);

    % Automatische Farblimits basierend auf Daten
    validEnergies = energies(~isnan(energies));
    if ~isempty(validEnergies)
        cLimMin = min(validEnergies);
        cLimMax = max(validEnergies);
        caxis([cLimMin, cLimMax]);
    end

    cb = colorbar;
    cb.Label.String = 'Gesamtenergie [dB]';
    cb.Label.FontSize = 12;

    axis ij; axis equal; axis off;
    xlim([0.5, cols+0.5]); ylim([0.5, rows+0.5]);

    title(sprintf('Gesamtenergie - %s', strrep(variante,'_',' ')), 'FontSize', 16, 'FontWeight', 'bold');

    % Beschriftungen mit Position und Energiewert
    for r = 1:rows
        for c = 1:cols
            pos = positionsLayout{r,c};
            val = energies(r,c);

            if ~isnan(val)
                % Textfarbe basierend auf Hintergrundfarbe
                if val > mean([cLimMin, cLimMax])
                    textColor = 'w';
                else
                    textColor = 'k';
                end

                text(c, r, sprintf('%s\n%.1f dB', pos, val), ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 10, ...
                    'FontWeight', 'bold', ...
                    'Color', textColor);
            else
                text(c, r, pos, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 10, ...
                    'Color', [0.5, 0.5, 0.5]);
            end
        end
    end

    % Speichern
    outputFile = fullfile(outputDir, sprintf('Heatmap_Gesamtenergie_%s.png', variante));
    saveas(fig, outputFile);
    fprintf('  Gespeichert: %s\n', outputFile);

    % Optional: auch als PDF speichern
    outputFilePDF = fullfile(outputDir, sprintf('Heatmap_Gesamtenergie_%s.pdf', variante));
    saveas(fig, outputFilePDF);

    close(fig);
end

fprintf('\nFertig. Heatmaps gespeichert in "%s"\n', outputDir);

%% Helper Function
function filePath = find_mat_file(dataDir, allFiles, variante, posName)
    filePath = '';
    pattern = '';
    if startsWith(posName, 'M')
        posNum = extractAfter(posName, 'M');
        pattern = ['^Proc_' regexptranslate('escape', variante) '_Pos' posNum '\.mat$'];
    elseif startsWith(posName, 'Q')
        pattern = ['^Proc_' regexptranslate('escape', variante) '_Quelle\.mat$'];
    end

    if ~isempty(pattern)
        idx = find(~cellfun(@isempty, regexp(allFiles, pattern, 'once')), 1);
        if ~isempty(idx), filePath = fullfile(dataDir, allFiles{idx}); end
    end
end
