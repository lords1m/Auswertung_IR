%% Terzpegel-Auswertung
% Erstellt Plots der Terzspektren für ausgewählte Messungen.

clear;
clc;
close all;

% Pfade
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end
% Repository-Pfade initialisieren (navigiert zum Root)
if exist('../../functions', 'dir')
    cd('../../.');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');

%% Konfiguration

% Auswahl: { 'Variante', Position } (Position [] = alle)
messungen = { ...
    {'Variante_1', []}, ...
    {'Variante_2', []}, ...
    {'Variante_3', []}, ... 
    {'Variante_4', []}, ...       % Plot-Beispiel: Nur Position 1 von Variante 2
};

dataDir = 'processed';
outputPlotDir = 'Plots';
selectedPositions = 1:15; % Standard für "ganze Variante"

fs = 500e3;
y_limits = [-70, 10];

%% Verarbeitung

if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputPlotDir,'dir'), mkdir(outputPlotDir); end

% Dateien suchen
dirInfo = dir(fullfile(dataDir, 'Proc_*.mat'));
matFiles = {dirInfo.name};
if isempty(matFiles), error('Keine Proc_*.mat-Dateien im Ordner "%s" gefunden!', dataDir); end

% Daten laden
all_L_dBFS = [];
all_plot_data = {};

fprintf('Lade Daten...\n');
for i = 1:numel(messungen)
    variante = messungen{i}{1};
    position_spec = messungen{i}{2};

    positions_to_plot = position_spec;
    if isempty(position_spec)
        positions_to_plot = selectedPositions;
    end

    for j = 1:numel(positions_to_plot)
        pos = positions_to_plot(j);

        % Daten abrufen
        [L_dBFS, f_terz] = getTerzpegel(variante, pos, dataDir, matFiles);

        if ~all(isnan(L_dBFS))
            entry = struct();
            entry.variante = variante;
            entry.position = pos;
            entry.L_dBFS = L_dBFS;
            entry.f_terz = f_terz;
            all_plot_data{end+1} = entry;

            all_L_dBFS = [all_L_dBFS; L_dBFS];
        else
            warning('Keine gültigen Daten für %s, Pos %d erhalten. Wird im Plot ausgelassen.', variante, pos);
        end
    end
end

if isempty(all_L_dBFS)
    error('Keine einzige der ausgewählten Messungen konnte verarbeitet werden. Es wird kein Plot erstellt.');
end

%% Plotting

fprintf('Erstelle Plots...\n');

for i = 1:numel(all_plot_data)
    data = all_plot_data{i};

    fig = figure('Visible','on','Position',[100,100,1200,600]);

    % Stairs-Plot vorbereiten
    y_plot = [data.L_dBFS, data.L_dBFS(end)];
    x_plot = (1:length(y_plot)) - 0.5;
    
    stairs(x_plot, y_plot, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);

    grid on;

    title(sprintf('Terzpegel: %s, Position %d', data.variante, data.position), 'FontSize', 14, 'Interpreter', 'none');
    xlabel('Frequenz [Hz]', 'FontSize', 12);
    ylabel('Pegel [dBFS]', 'FontSize', 12);

    % X-Achse
    x_labels = arrayfun(@(x) sprintf('%g', x), data.f_terz, 'UniformOutput', false);
    set(gca, 'XTick', 1:length(data.f_terz));
    set(gca, 'XTickLabel', x_labels);
    xtickangle(45);
    
    xlim([0, length(data.f_terz) + 1]);
    ylim(y_limits);

    set(gcf, 'Color', 'w');

    % Export
    outputFileName = fullfile(outputPlotDir, sprintf('Terzpegel_%s_Pos%d.png', data.variante, data.position));
    saveas(fig, outputFileName);
    saveas(fig, strrep(outputFileName, '.png', '.fig'));

    close(fig);
end

fprintf('Fertig. Plots in "%s".\n', outputPlotDir);


%% Helper

function [L_dBFS, f_terz] = getTerzpegel(variante, position, dataDir, allFiles)
    % Lädt Spektraldaten aus Result-Struct

    posStr = num2str(position);
    fname = '';

    % Suche Datei
    searchPattern_exact = sprintf('Proc_%s_Pos%s.mat', variante, posStr);
    for i = 1:numel(allFiles)
        if strcmp(allFiles{i}, searchPattern_exact)
            fname = allFiles{i};
            break;
        end
    end

    % Fallback Regex
    if isempty(fname)
        pattern = sprintf('^Proc_%s.*Pos%s\\.mat$', regexptranslate('escape', variante), posStr);
        for i = 1:numel(allFiles)
             if ~isempty(regexp(allFiles{i}, pattern, 'once'))
                fname = allFiles{i};
                break;
            end
        end
    end

    % Standard-Werte (Fallback)
    f_terz = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
    L_dBFS = NaN(1, 13);

    if isempty(fname)
        return;
    end

    try
        S = load(fullfile(dataDir, fname));

        if ~isfield(S, 'Result')
            return;
        end

        Result = S.Result;

        L_dBFS = Result.freq.terz_dbfs;
        f_terz = Result.freq.f_center;

        L_dBFS(isinf(L_dBFS)) = NaN;

    catch ME
        return;
    end
end