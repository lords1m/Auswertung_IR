%% ============================================================
%  Terzpegel-Auswertung für ausgewählte Einzelmessungen
%
%  Dieses Skript ermöglicht es, gezielt einzelne oder mehrere
%  Messpunkte (Position und Variante) auszuwählen und deren
%  Terzspektren gemeinsam in einem einzigen Plot darzustellen.
%
%  UPDATE: Angepasst an neue Datenstruktur (Result-Struktur)
% ============================================================

clear;
clc;
close all;

% Stelle sicher, dass wir im richtigen Verzeichnis sind
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end
addpath('functions'); % Helper-Funktionen laden
fprintf('Arbeitsverzeichnis: %s\n', pwd);

%% ---------------- Einstellungen (anpassen) ----------------

% --- Messungen zum Plotten auswählen ---
% Fügen Sie hier jede gewünschte Kombination hinzu.
% - Für eine Einzelmessung: { 'Varianten-Name', Positions-Nummer }
% - Für eine ganze Variante: { 'Varianten-Name', [] } (leere Klammern)
messungen = { ...
    {'Variante_1', 1}, ...       % Plot-Beispiel: Alle Positionen ([])von Variante 1
    %{'Variante_2', []}, ...
   % {'Variante_3', []}, ... 
   % {'Variante_4', []}, ...       % Plot-Beispiel: Nur Position 1 von Variante 2
};

% --- Allgemeine Einstellungen ---
dataDir = 'processed'; % Datenordner mit allen .mat-Dateien
outputPlotDir = 'Plots'; % Ausgabeordner für den Plot
selectedPositions = 1:14; % Wenn eine ganze Variante geplottet wird, werden diese Positionen verwendet

% --- Physikalische & Plot-Parameter ---
fs = 500e3; % 500 kHz Abtastrate
y_limits = [-70, 10]; % Feste Y-Achsen-Grenzen für Vergleichbarkeit aller Plots

%% ---------------- Setup & Dateiprüfung ----------------
if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputPlotDir,'dir'), mkdir(outputPlotDir); end

% Suche alle Proc_*.mat Dateien (neue Datenstruktur)
dirInfo = dir(fullfile(dataDir, 'Proc_*.mat'));
matFiles = {dirInfo.name};
if isempty(matFiles), error('Keine Proc_*.mat-Dateien im Ordner "%s" gefunden!', dataDir); end

fprintf('Gefundene Dateien: %d\n', numel(matFiles));

%% ---------------- Schritt 1: Alle Daten laden und globale Y-Achsen-Range bestimmen ----------------
all_L_dBFS = []; % Sammel-Array für die Y-Achsen-Limits
all_plot_data = {}; % Speichert alle zu plottenden Messungen

fprintf('\nLade alle ausgewählten Messungen...\n');
for i = 1:numel(messungen)
    variante = messungen{i}{1};
    position_spec = messungen{i}{2};

    positions_to_plot = position_spec;
    if isempty(position_spec)
        % Fall: Ganze Variante plotten
        positions_to_plot = selectedPositions;
        fprintf('  Verarbeite ganze Variante: %s (Positionen %d-%d)\n', variante, min(positions_to_plot), max(positions_to_plot));
    end

    for j = 1:numel(positions_to_plot)
        pos = positions_to_plot(j);

        if isempty(position_spec)
             % Kein Log-Output für jede einzelne Position bei "ganzer Variante"
        else
             fprintf('  Lese ein: %s, Pos %d\n', variante, pos);
        end

        % Terzpegel für diese eine Messung laden (neue Struktur)
        [L_dBFS, f_terz] = getTerzpegel(variante, pos, dataDir, matFiles);

        if ~all(isnan(L_dBFS))
            % Speichere Daten für späteren Plot
            plot_entry = struct();
            plot_entry.variante = variante;
            plot_entry.position = pos;
            plot_entry.L_dBFS = L_dBFS;
            plot_entry.f_terz = f_terz;
            all_plot_data{end+1} = plot_entry;

            % Sammle alle Daten für globale Y-Achsen-Range
            all_L_dBFS = [all_L_dBFS; L_dBFS];
        else
            warning('Keine gültigen Daten für %s, Pos %d erhalten. Wird im Plot ausgelassen.', variante, pos);
        end
    end
end

if isempty(all_L_dBFS)
    error('Keine einzige der ausgewählten Messungen konnte verarbeitet werden. Es wird kein Plot erstellt.');
end

% Globale Y-Achsen-Range (Festgelegt für Vergleichbarkeit)
% Falls Auto-Scaling gewünscht ist, kann dieser Block einkommentiert werden:
% validData = all_L_dBFS(~isnan(all_L_dBFS));
% if ~isempty(validData)
%     y_range = [floor(min(validData)/10)*10, ceil(max(validData)/10)*10];
% else
%     y_range = [-80, 0]; % Fallback
% end
y_range = y_limits;

fprintf('Globale Y-Achsen-Range: [%.1f, %.1f] dBFS\n', y_range(1), y_range(2));

%% ---------------- Schritt 2: Einzelne Plots für jede Position erstellen ----------------
fprintf('\nErstelle einzelne Plots für jede Position...\n');

for i = 1:numel(all_plot_data)
    data = all_plot_data{i};

    % Neuer Plot für jede Position
    fig = figure('Visible','on','Position',[100,100,1200,600]);

    % Stairs Diagramm (Index-basiert wie interactive_plotter)
    % Daten erweitern, damit der letzte Balken gezeichnet wird
    y_plot = [data.L_dBFS, data.L_dBFS(end)];
    x_plot = (1:length(y_plot)) - 0.5;
    
    stairs(x_plot, y_plot, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);

    grid on;

    % Achsen und Titel
    title(sprintf('Terzpegel: %s, Position %d', data.variante, data.position), 'FontSize', 14, 'Interpreter', 'none');
    xlabel('Frequenz [Hz]', 'FontSize', 12);
    ylabel('Pegel [dBFS]', 'FontSize', 12);

    % X-Achse Beschriftung (Standard Terzfrequenzen)
    x_labels = arrayfun(@(x) sprintf('%g', x), data.f_terz, 'UniformOutput', false);
    set(gca, 'XTick', 1:length(data.f_terz));
    set(gca, 'XTickLabel', x_labels);
    xtickangle(45);
    
    xlim([0, length(data.f_terz) + 1]);
    ylim(y_range); % Globale Y-Achsen-Range verwenden

    set(gcf, 'Color', 'w');

    % Speichern mit eindeutigem Dateinamen
    outputFileName = fullfile(outputPlotDir, sprintf('Terzpegel_%s_Pos%d.png', data.variante, data.position));
    saveas(fig, outputFileName);
    saveas(fig, strrep(outputFileName, '.png', '.fig'));

    fprintf('  Gespeichert: %s\n', outputFileName);

    close(fig); % Schließe Figure nach dem Speichern
end

fprintf('\nAlle %d Plots wurden erfolgreich erstellt und im Ordner "%s" gespeichert.\n', numel(all_plot_data), outputPlotDir);


%% ========================================================================
%  HILFSFUNKTIONEN
%  ========================================================================

%% ---------------- Hilfsfunktion zum Laden der Terzpegel (Einzelmessung) ----------------
function [L_dBFS, f_terz] = getTerzpegel(variante, position, dataDir, allFiles)
    % Lädt die bereits berechneten Terzpegel aus der Result-Struktur

    % Passende Datei finden (neue Namenskonvention: Proc_Variante_X_PosY.mat)
    posStr = num2str(position);
    fname = '';

    % Suche nach exaktem Match: Proc_VarianteX_PosY.mat
    searchPattern_exact = sprintf('Proc_%s_Pos%s.mat', variante, posStr);
    for i = 1:numel(allFiles)
        if strcmp(allFiles{i}, searchPattern_exact)
            fname = allFiles{i};
            break;
        end
    end

    % Wenn nicht gefunden, flexiblere Suche
    if isempty(fname)
        pattern = sprintf('^Proc_%s.*Pos%s\\.mat$', regexptranslate('escape', variante), posStr);
        for i = 1:numel(allFiles)
             if ~isempty(regexp(allFiles{i}, pattern, 'once'))
                fname = allFiles{i};
                break;
            end
        end
    end

    if isempty(fname)
        % Rückgabe mit NaN
        L_dBFS = NaN(1, 13); % Standard-Länge für Terzspektrum (IEC 61260)
        f_terz = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
        return;
    end

    % Lade Result-Struktur
    try
        S = load(fullfile(dataDir, fname));

        if ~isfield(S, 'Result')
            warning('Datei %s enthält keine Result-Struktur.', fname);
            L_dBFS = NaN(1, 13);
            f_terz = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
            return;
        end

        Result = S.Result;

        % Extrahiere Terzpegel und Frequenzen
        L_dBFS = Result.freq.terz_dbfs;
        f_terz = Result.freq.f_center;

        % Ersetze -Inf mit NaN für besseres Plotten
        L_dBFS(isinf(L_dBFS)) = NaN;

    catch ME
        warning('Fehler beim Laden von %s: %s', fname, ME.message);
        L_dBFS = NaN(1, 13);
        f_terz = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
        return;
    end
end