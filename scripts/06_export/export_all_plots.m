function export_all_plots()
    % EXPORT_ALL_PLOTS Exportiert automatisch alle Plots wie im interactive_plotter
    % Erstellt für jede Messung aus dem 'processed' Ordner alle verfügbaren
    % Darstellungen (außer Heatmap) und speichert sie als PNG-Dateien

    % =====================================================================
    % KONFIGURATION - Hier anpassen!
    % =====================================================================

    % Welche Varianten sollen exportiert werden?
    % Optionen:
    %   - 'all'          : Alle Varianten
    %   - {'V1', 'V2'}   : Nur spezifische Varianten (Zellenarray)
    %   - 'Variante1'    : Einzelne Variante (String)
    exportVarianten = 'all';

    % Welche Plot-Typen sollen exportiert werden?
    % 1 = Spektrum, 2 = Impulsantwort, 3 = ETC, 4 = EDC,
    % 5 = Pegel vs Entfernung, 6 = 3D Scatter, 8 = RT60
    exportPlotTypes = [1, 2, 3, 4, 5, 6, 8];  % Alle außer Heatmap (7)
    % Beispiele:
    %   [1, 8]           : Nur Spektrum und RT60
    %   [1, 2, 3, 4]     : Nur Zeitbereich-Plots
    %   [5, 6]           : Nur räumliche Plots

    % =====================================================================

    % Repository-Pfade initialisieren (navigiert zum Root)
if exist('../../functions', 'dir')
    cd('../../.');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');
init_repo_paths();
    procDir = 'processed';
    dataDir = 'data';
    outputDir = 'exported_plots';

    % Output-Ordner erstellen
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
        fprintf('Erstelle Ausgabe-Ordner: %s\n', outputDir);
    end

    % Prüfe ob processed Ordner existiert
    if ~exist(procDir, 'dir')
        error('Ordner "processed" nicht gefunden. Bitte erst step1 ausführen.');
    end

    % Globale Referenz laden (wie in interactive_plotter)
    FS_global_ref = 1.0;
    procFiles = dir(fullfile(procDir, 'Proc_*.mat'));
    if isempty(procFiles)
        error('Keine verarbeiteten Dateien im Ordner "processed" gefunden.');
    end

    try
        tmpLoad = load(fullfile(procDir, procFiles(1).name), 'Result');
        if isfield(tmpLoad.Result.meta, 'FS_global_used')
            FS_global_ref = tmpLoad.Result.meta.FS_global_used;
        end
    catch
    end

    % --- Y-Achsen-Einstellungen pro Plot-Typ ---
    ySettings = containers.Map('KeyType', 'double', 'ValueType', 'any');
    ySettings(1) = [-30, 10];    % Spektrum
    ySettings(2) = [-1.1, 1.1];  % IR
    ySettings(3) = [-60, 5];     % ETC
    ySettings(4) = [-60, 5];     % EDC
    ySettings(5) = [-30, 20];    % Pegel vs Dist
    ySettings(6) = [-30, 20];    % 3D
    ySettings(8) = [0, 0.4];     % RT60

    % Plot-Typ-Namen für Dateinamen
    plotTypeNames = {
        'Spektrum',
        'Impulsantwort',
        'ETC',
        'EDC',
        'Pegel_vs_Entfernung',
        '3D_Scatter',
        'Heatmap',  % Wird übersprungen
        'RT60'
    };

    % Frequenzfilter: Nur 4 kHz - 63 kHz
    useFreqFilter = true;

    % --- Varianten-Filter anwenden ---
    if ischar(exportVarianten) && strcmp(exportVarianten, 'all')
        % Alle Dateien
        filesToProcess = procFiles;
        variantenList = {'Alle'};
    else
        % Nur bestimmte Varianten
        if ischar(exportVarianten)
            variantenList = {exportVarianten}; % In Zellenarray konvertieren
        else
            variantenList = exportVarianten;
        end

        filesToProcess = [];
        for v = 1:length(variantenList)
            varName = variantenList{v};
            matchedFiles = dir(fullfile(procDir, sprintf('Proc_%s_*.mat', varName)));
            filesToProcess = [filesToProcess; matchedFiles]; %#ok<AGROW>
        end

        if isempty(filesToProcess)
            error('Keine Dateien für die angegebenen Varianten gefunden: %s', strjoin(variantenList, ', '));
        end
    end

    % --- Alle Dateien durchgehen ---
    fprintf('=== Export-Konfiguration ===\n');
    fprintf('Varianten: %s\n', strjoin(variantenList, ', '));
    fprintf('Plot-Typen: ');
    for pt = exportPlotTypes
        fprintf('%s ', plotTypeNames{pt});
    end
    fprintf('\n');
    fprintf('Anzahl zu verarbeitende Dateien: %d\n\n', length(filesToProcess));

    for fileIdx = 1:length(filesToProcess)
        filename = filesToProcess(fileIdx).name;
        fprintf('Verarbeite %s (%d/%d)...\n', filename, fileIdx, length(filesToProcess));

        % Daten laden
        R = loadData(filename, procDir);

        % Basisname für Ausgabedateien (ohne "Proc_" und ".mat")
        baseName = cleanName(filename);

        % --- Gewählte Plot-Typen durchgehen ---
        for plotType = exportPlotTypes

            % Figur erstellen (unsichtbar für Performance)
            fig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1000 700]);
            ax = axes(fig, 'Position', [0.1 0.1 0.85 0.85]);
            hold(ax, 'on'); grid(ax, 'on');

            % Y-Achsen-Grenzen
            yLimits = ySettings(plotType);

            try
                switch plotType
                    case 1 % SPEKTRUM (Terz)
                        plot_spectrum(ax, R, filename, useFreqFilter, yLimits, FS_global_ref);

                    case 2 % IMPULSANTWORT
                        plot_ir(ax, R, filename, yLimits, FS_global_ref);

                    case 3 % ETC
                        plot_etc(ax, R, filename, yLimits);

                    case 4 % EDC
                        plot_edc(ax, R, filename, yLimits);

                    case 5 % PEGEL ÜBER ENTFERNUNG
                        plot_level_vs_distance(ax, R, yLimits, procDir);

                    case 6 % 3D SCATTER
                        plot_3d_scatter(ax, R, yLimits, procDir);

                    case 8 % RT60
                        plot_rt60(ax, R, filename, yLimits, procDir);
                end

                % Speichern
                outputFilename = sprintf('%s_%s.png', baseName, plotTypeNames{plotType});
                outputPath = fullfile(outputDir, outputFilename);
                exportgraphics(fig, outputPath, 'Resolution', 300);
                fprintf('  ✓ %s\n', plotTypeNames{plotType});

            catch ME
                fprintf('  ✗ %s - Fehler: %s\n', plotTypeNames{plotType}, ME.message);
            end

            close(fig);
        end
        fprintf('\n');
    end

    fprintf('Export abgeschlossen! Plots gespeichert in: %s\n', outputDir);
end

% =========================================================================
% PLOT FUNKTIONEN
% =========================================================================

function plot_spectrum(ax, R, filename, useFreqFilter, yLimits, FS_global_ref)
    f_vec = R.freq.f_center;
    y = R.freq.terz_dbfs;

    % Filter anwenden (4k - 63k)
    if useFreqFilter
        mask = (f_vec >= 4000) & (f_vec <= 64000);
    else
        mask = true(size(f_vec));
    end

    f_sub = f_vec(mask);
    y_sub = y(mask);

    % Stairs Plot vorbereiten
    y_plot = [y_sub, y_sub(end)];
    x_plot = (1:length(y_plot)) - 0.5;

    % Plot
    stairs(ax, x_plot, y_plot, 'b-', 'LineWidth', 2);

    % Achsenbeschriftung
    x_labels = arrayfun(@(x) sprintf('%g', x), f_sub, 'UniformOutput', false);
    x_ticks = 1:length(f_sub);

    set(ax, 'XTick', x_ticks, 'XTickLabel', x_labels);
    xtickangle(ax, 45);
    xlim(ax, [0 length(f_sub)+1]);
    ylim(ax, yLimits);

    xlabel(ax, 'Frequenz [Hz]');
    ylabel(ax, 'Pegel [dBFS]');
    title(ax, sprintf('Spektrum: %s (L_{sum} = %.1f dB)', cleanName(filename), R.freq.sum_level));
    grid(ax, 'on');
end

function plot_ir(ax, R, filename, yLimits, FS_global_ref)
    t = (0:length(R.time.ir)-1) / R.meta.fs * 1000; % ms

    if all(R.time.ir == 0)
        text(ax, 0.5, 0.5, 'Keine Zeitdaten (Average File)', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center');
        return;
    end

    plot(ax, t, R.time.ir, 'b', 'LineWidth', 1);

    xlabel(ax, 'Zeit [ms]');
    ylabel(ax, 'Amplitude');
    title(ax, ['Impulsantwort: ' cleanName(filename)]);
    ylim(ax, [-FS_global_ref, FS_global_ref] * 1.1);
    grid(ax, 'on');

    % Info über Truncation
    infoStr = sprintf('Truncation: Idx %d bis %d\nEnergieanteil: %.1f%%', ...
        R.time.metrics.idx_start, R.time.metrics.idx_end, R.time.metrics.energy_share*100);
    text(ax, 0.05, 0.9, infoStr, 'Units', 'normalized', 'BackgroundColor', 'w');
end

function plot_etc(ax, R, filename, yLimits)
    etc = 20*log10(abs(R.time.ir) + eps);
    t = (0:length(etc)-1) / R.meta.fs * 1000;

    plot(ax, t, etc, 'b', 'LineWidth', 1);

    xlabel(ax, 'Zeit [ms]');
    ylabel(ax, 'Pegel [dB]');
    title(ax, ['Energie-Zeit-Kurve (ETC): ' cleanName(filename)]);
    ylim(ax, yLimits);
    grid(ax, 'on');
end

function plot_edc(ax, R, filename, yLimits)
    edc = calc_edc(R.time.ir);
    t = (0:length(edc)-1) / R.meta.fs * 1000;

    plot(ax, t, edc, 'b', 'LineWidth', 1);

    xlabel(ax, 'Zeit [ms]');
    ylabel(ax, 'Pegel [dB]');
    title(ax, ['Energy Decay Curve (EDC): ' cleanName(filename)]);
    ylim(ax, yLimits);
    grid(ax, 'on');
end

function plot_level_vs_distance(ax, R, yLimits, procDir)
    useEnergyMode = false; % dB Modus

    % Daten für diese Variante sammeln
    [dist, levels, ~] = get_variant_levels(R.meta.variante, procDir, useEnergyMode);

    if isempty(dist)
        text(ax, 0.5, 0.5, 'Keine Daten verfügbar', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center');
        return;
    end

    scatter(ax, dist, levels, 60, 'b', 'filled', 'DisplayName', strrep(R.meta.variante, '_', ' '));

    % Ideal Kurve berechnen
    [dist_ideal, L_ideal] = calc_ideal_curve(dist, levels, useEnergyMode);
    plot(ax, dist_ideal, L_ideal, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Ideal 1/r');

    xlabel(ax, 'Entfernung von Quelle [m]');
    ylabel(ax, 'Summenpegel [dBFS]');
    title(ax, 'Pegelabfall über Entfernung');
    ylim(ax, yLimits);
    grid(ax, 'on');
    legend(ax, 'show');

    text(ax, 0.02, 0.05, 'Punkte zeigen Messpositionen 1-15', ...
        'Units', 'normalized', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end

function plot_3d_scatter(ax, R, yLimits, procDir)
    useEnergyMode = false; % dB Modus
    geo = get_geometry();

    [dist, levels, positions] = get_variant_levels(R.meta.variante, procDir, useEnergyMode);

    if isempty(dist)
        text(ax, 0.5, 0.5, 'Keine Daten verfügbar', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center');
        return;
    end

    % X, Y Koordinaten extrahieren
    x = []; y = [];
    for p = positions
        g = geo([geo.pos] == p);
        if ~isempty(g)
            x(end+1) = g.x;
            y(end+1) = g.y;
        end
    end

    scatter3(ax, x, y, levels, 80, 'b', 'filled', 'DisplayName', strrep(R.meta.variante, '_', ' '));
    hold(ax, 'on');

    % Text Labels für Positionen
    for i = 1:length(x)
        text(ax, x(i), y(i), levels(i), sprintf('  P%d', positions(i)), 'FontSize', 8);
    end

    % Quelle visualisieren
    z_source = max(levels);
    scatter3(ax, 0, 0, z_source, 100, 'k', 'filled', 'DisplayName', 'Quelle');

    grid(ax, 'on');
    view(ax, 45, 30);
    xlabel(ax, 'X [m]');
    ylabel(ax, 'Y [m]');
    zlabel(ax, 'Pegel [dBFS]');
    title(ax, 'Räumliche Pegelverteilung');
    zlim(ax, yLimits);
    legend(ax, 'show');
end

function plot_rt60(ax, R, filename, yLimits, procDir)
    % RT60 Daten
    if isfield(R.freq, 't30') && ~isempty(R.freq.t30)
        t30 = R.freq.t30;
        f_vec = R.freq.t30_freqs;
    else
        [t30, f_vec] = calc_rt60_spectrum(R.time.ir, R.meta.fs);
    end

    % Stairs Plot vorbereiten
    t30_plot = [t30, t30(end)];
    x_plot = (1:length(t30_plot)) - 0.5;

    % Average berechnen
    [avg_t30, ~] = get_avg_rt60(R.meta.variante, procDir);
    avg_t30_plot = [avg_t30, avg_t30(end)];

    % Plot
    stairs(ax, x_plot, t30_plot, 'b-', 'LineWidth', 2, 'DisplayName', cleanName(filename));
    stairs(ax, x_plot, avg_t30_plot, 'k--', 'LineWidth', 1.5, 'DisplayName', ['Ø ' strrep(R.meta.variante, '_', ' ')]);

    % Achsenbeschriftung
    x_idx = 1:length(f_vec);
    x_labels = arrayfun(@(x) sprintf('%g', x), f_vec, 'UniformOutput', false);

    set(ax, 'XTick', x_idx, 'XTickLabel', x_labels);
    xtickangle(ax, 45);
    xlim(ax, [0 length(f_vec)+1]);
    ylim(ax, yLimits);

    xlabel(ax, 'Frequenz [Hz]');
    ylabel(ax, 'Nachhallzeit RT60 [s]');
    title(ax, ['Nachhallzeit RT60: ' cleanName(filename)]);
    grid(ax, 'on');
    legend(ax, 'show');
end

% =========================================================================
% HELPER FUNKTIONEN
% =========================================================================

function R = loadData(filename, procDir)
    tmp = load(fullfile(procDir, filename));
    R = tmp.Result;
end

function [avg_vals, f_vec] = get_avg_rt60(variante, procDir)
    % Berechnet durchschnittliche RT60 über alle Positionen einer Variante
    f_vec = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
    sum_t30 = zeros(size(f_vec));
    count_t30 = zeros(size(f_vec));

    files = dir(fullfile(procDir, sprintf('Proc_%s_Pos*.mat', variante)));

    for i = 1:length(files)
        try
            D = load(fullfile(files(i).folder, files(i).name), 'Result');
            ir = D.Result.time.ir;
            fs_loc = D.Result.meta.fs;

            [vals, ~] = calc_rt60_spectrum(ir, fs_loc);
            mask = ~isnan(vals);
            sum_t30(mask) = sum_t30(mask) + vals(mask);
            count_t30(mask) = count_t30(mask) + 1;
        catch
        end
    end
    avg_vals = sum_t30 ./ count_t30;
    avg_vals(count_t30 == 0) = NaN;
end

function [dist, levels, positions] = get_variant_levels(variante, procDir, energyMode)
    geo = get_geometry();
    dist = []; levels = []; positions = [];

    files = dir(fullfile(procDir, sprintf('Proc_%s_Pos*.mat', variante)));

    for i = 1:length(files)
        try
            D = load(fullfile(files(i).folder, files(i).name), 'Result');
            meta = D.Result.meta;
            if energyMode
                val = D.Result.time.metrics.energy;
            else
                val = D.Result.freq.sum_level;
            end

            % Position parsen
            posNum = str2double(meta.position);
            if isnan(posNum), continue; end

            % Geometrie finden
            idx = find([geo.pos] == posNum);
            if ~isempty(idx)
                d = geo(idx).distance;
                if d > 0 % Quelle (d=0) ausschließen
                    dist(end+1) = d;
                    levels(end+1) = val;
                    positions(end+1) = posNum;
                end
            end
        catch
        end
    end
end

function s = cleanName(filename)
    % Entfernt 'Proc_' und '.mat' für schönere Namen
    s = strrep(filename, 'Proc_', '');
    s = strrep(s, 'Time_', '');
    s = strrep(s, '.mat', '');
    s = strrep(s, '_', ' ');
end
