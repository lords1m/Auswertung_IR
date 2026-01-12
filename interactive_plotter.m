function interactive_plotter()
    % GUI zur Analyse und zum Vergleich von Messdaten.
    
    % Config
    addpath('functions');
    procDir = 'processed';
    dataDir = 'dataraw';
    if ~exist(procDir, 'dir'), errordlg('Ordner "processed" fehlt.', 'Fehler'); return; end
    
    fileList = {}; 
    isPlaying = false;
    heatmapCache = struct('variante1', '', 'data1', [], 'variante2', '', 'data2', []);

    % Default Y-Achsen
    lastPlotType = 1;
    ySettings = containers.Map('KeyType', 'double', 'ValueType', 'any');
    ySettings(1) = [-30, 10];    % Spektrum
    ySettings(2) = [-1.1, 1.1];  % IR
    ySettings(3) = [-60, 5];     % ETC
    ySettings(4) = [-60, 5];     % EDC
    ySettings(5) = [-30, 20];     % Pegel vs Dist
    ySettings(6) = [-30, 20];     % 3D
    ySettings(7) = [-60, 0];     % Heatmap (Threshold)
    ySettings(8) = [0, 0.4];     % RT60

    % Referenz laden
    FS_global_ref = 1.0;
    procFiles = dir(fullfile(procDir, 'Proc_*.mat'));
    if ~isempty(procFiles)
        try
            tmpLoad = load(fullfile(procDir, procFiles(1).name), 'Result');
            if isfield(tmpLoad.Result.meta, 'FS_global_used')
                FS_global_ref = tmpLoad.Result.meta.FS_global_used;
            end
        catch
        end
    end

    % GUI Aufbau
    f = figure('Name', 'Akustik Auswertung', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 700], 'Color', 'w');
    pnlControl = uipanel(f, 'Position', [0.01 0.01 0.25 0.98], 'Title', 'Einstellungen');

    % Modus
    uicontrol(pnlControl, 'Style', 'text', 'Position', [10 660 200 20], 'String', 'Modus:', 'HorizontalAlignment', 'left');
    hMode = uicontrol(pnlControl, 'Style', 'popupmenu', 'Position', [10 635 200 25], ...
                      'String', {'Einzelansicht', 'Vergleich (Differenz)'}, ...
                      'Callback', @updateVisibility);

    % Messung 1
    uicontrol(pnlControl, 'Style', 'text', 'Position', [10 605 200 20], 'String', 'Messung 1 (Referenz):', 'HorizontalAlignment', 'left');
    hSource1 = uicontrol(pnlControl, 'Style', 'popupmenu', 'Position', [10 580 200 25], ...
                      'String', {'Processed (Proc_*.mat)', 'Raw (Data/*.mat)'}, ...
                      'Callback', @updateFile1List);
    
    hFile1 = uicontrol(pnlControl, 'Style', 'listbox', 'Position', [10 430 200 140], ...
                       'String', fileList, 'Callback', @updatePlot);

    % Messung 2
    lblFile2 = uicontrol(pnlControl, 'Style', 'text', 'Position', [10 400 200 20], 'String', 'Messung 2 (Vergleich):', 'HorizontalAlignment', 'left');
    
    hSource2 = uicontrol(pnlControl, 'Style', 'popupmenu', 'Position', [10 375 200 25], ...
                      'String', {'Processed (Proc_*.mat)', 'Raw (Data/*.mat)'}, ...
                      'Callback', @updateFile2List, 'Enable', 'off');
                      
    hFile2 = uicontrol(pnlControl, 'Style', 'listbox', 'Position', [10 225 200 140], ...
                       'String', fileList, 'Callback', @updatePlot, 'Enable', 'off');

    % Plot Typ
    uicontrol(pnlControl, 'Style', 'text', 'Position', [10 205 200 15], 'String', 'Darstellung:', 'HorizontalAlignment', 'left');
    hType = uicontrol(pnlControl, 'Style', 'popupmenu', 'Position', [10 180 200 25], ...
                      'String', {'Frequenzspektrum (Terz)', 'Impulsantwort (Zeit)', 'Energie über Zeit (ETC)', 'Energy Decay Curve (EDC)', 'Pegel über Entfernung', '3D Scatter (Raum)', 'Heatmap (Raumzeit)', 'Nachhallzeit (RT60) über Frequenz'}, ...
                      'Callback', @onTypeChange);

    % Frequenzfilter Checkbox
    hFilterFreq = uicontrol(pnlControl, 'Style', 'checkbox', 'Position', [10 155 200 20], ...
                            'String', 'Nur 4 kHz - 63 kHz', 'Value', 1, ...
                            'Callback', @updatePlot);
                            
    % Luftdämpfung Checkbox
    hShowAirAbs = uicontrol(pnlControl, 'Style', 'checkbox', 'Position', [10 90 200 20], ...
                            'String', 'Luftdämpfung anzeigen', 'Value', 0, ...
                            'Callback', @updatePlot, 'Visible', 'off');

    % Achsengrenzen - Y-Achse
    hLblYAxis = uicontrol(pnlControl, 'Style', 'text', 'Position', [10 135 80 15], 'String', 'Y-Achse:', 'HorizontalAlignment', 'left', 'FontSize', 8);
    hLblYMin = uicontrol(pnlControl, 'Style', 'text', 'Position', [10 115 30 15], 'String', 'Min:', 'HorizontalAlignment', 'left', 'FontSize', 8);
    hYMin = uicontrol(pnlControl, 'Style', 'edit', 'Position', [40 115 35 20], 'String', '-30', 'Callback', @updatePlot);
    hLblYMax = uicontrol(pnlControl, 'Style', 'text', 'Position', [80 115 30 15], 'String', 'Max:', 'HorizontalAlignment', 'left', 'FontSize', 8);
    hYMax = uicontrol(pnlControl, 'Style', 'edit', 'Position', [110 115 35 20], 'String', '10', 'Callback', @updatePlot);
    hFixedScale = uicontrol(pnlControl, 'Style', 'checkbox', 'Position', [150 115 60 20], ...
                            'String', 'Fix', 'Value', 1, 'Callback', @updatePlot, 'FontSize', 8);

    % Energie-Modus Checkbox (für Pegel über Entfernung)
    hEnergyMode = uicontrol(pnlControl, 'Style', 'checkbox', 'Position', [10 90 200 20], ...
                            'String', 'Energie (Linear) statt dB', 'Value', 0, ...
                            'Callback', @updatePlot);

    % Heatmap Controls
    lblTime = uicontrol(pnlControl, 'Style', 'text', 'Position', [10 155 200 15], ...
                        'String', 'Zeit: 0.0 ms', 'Visible', 'off', 'HorizontalAlignment', 'left');
    hSliderTime = uicontrol(pnlControl, 'Style', 'slider', 'Position', [10 135 200 20], ...
                            'Min', -5, 'Max', 100, 'Value', 0, 'Visible', 'off', ...
                            'SliderStep', [0.001 0.05], ...
                            'Callback', @updateHeatmapFrame);

    lblThreshold = uicontrol(pnlControl, 'Style', 'text', 'Position', [10 90 50 20], ...
                             'String', 'Min dB:', 'Visible', 'off', 'HorizontalAlignment', 'left');
    hEditThreshold = uicontrol(pnlControl, 'Style', 'edit', 'Position', [65 90 50 20], ...
                               'String', '-60', 'Visible', 'off', ...
                               'Callback', @updatePlot);

    hBtnPlay = uicontrol(pnlControl, 'Style', 'pushbutton', 'Position', [10 60 200 25], ...
                         'String', 'Play Animation', 'Visible', 'off', ...
                         'Callback', @playAnimation);

    % Speichern Button
    uicontrol(pnlControl, 'Style', 'pushbutton', 'Position', [10 35 200 25], ...
              'String', 'Plot speichern', 'Callback', @savePlot);

    updateFile1List();
    updateFile2List();


    function updateFile1List(~, ~)
        updateListGeneric(hSource1, hFile1);
        updatePlot();
    end

    function updateFile2List(~, ~)
        updateListGeneric(hSource2, hFile2);
        updatePlot();
    end

    function updateListGeneric(hSrc, hList)
        if hSrc.Value == 1
            searchDir = procDir;
            pattern = 'Proc_*.mat';
        else
            searchDir = dataDir;
            pattern = '*.mat';
        end
        
        newList = {};
        if ~exist(searchDir, 'dir')
             newList = {'Ordner nicht gefunden'};
        else
             files = dir(fullfile(searchDir, pattern));
             if isempty(files)
                 newList = {'Keine Dateien'};
             else
                 newList = {files.name};
             end
        end
        set(hList, 'String', newList, 'Value', 1);
    end

    function updateVisibility(~, ~)
        mode = hMode.Value;
        if mode == 1 % Einzel
            set(hFile2, 'Enable', 'off');
            set(hSource2, 'Enable', 'off');
            set(lblFile2, 'Enable', 'off');
        else % Vergleich
            set(hFile2, 'Enable', 'on');
            set(hSource2, 'Enable', 'on');
            set(lblFile2, 'Enable', 'on');
        end
        updatePlot();
    end

    function onTypeChange(~, ~)
        newType = hType.Value;
        if newType == lastPlotType, return; end
        
        currMin = str2double(get(hYMin, 'String'));
        currMax = str2double(get(hYMax, 'String'));
        if ~isnan(currMin) && ~isnan(currMax)
            ySettings(lastPlotType) = [currMin, currMax];
        end
        
        newVals = ySettings(newType);
        set(hYMin, 'String', num2str(newVals(1)));
        set(hYMax, 'String', num2str(newVals(2)));
        
        lastPlotType = newType;
        updatePlot();
    end

    function updatePlot(~, ~)
        list1 = get(hFile1, 'String');
        list2 = get(hFile2, 'String');
        
        if isempty(list1) || strcmp(list1{1}, 'Keine Dateien'), cla(findobj(f, 'Type', 'axes')); return; end

        idx1 = hFile1.Value;
        name1 = list1{idx1};
        R1 = loadData(name1, hSource1.Value);

        isCompare = (hMode.Value == 2);
        R2 = [];
        if isCompare
            if isempty(list2) || strcmp(list2{1}, 'Keine Dateien'), return; end
            idx2 = hFile2.Value;
            name2 = list2{idx2};
            R2 = loadData(name2, hSource2.Value);
        end

        plotType = hType.Value; % 1=Spec, 2=IR, 3=ETC
        useFreqFilter = hFilterFreq.Value;
        useFixedScale = hFixedScale.Value;
        useEnergyMode = hEnergyMode.Value;

        % Achsengrenzen
        yMin = str2double(get(hYMin, 'String'));
        yMax = str2double(get(hYMax, 'String'));

        % Validierung
        if isnan(yMin) || isnan(yMax)
            defaults = ySettings(plotType);
            if isnan(yMin), yMin = defaults(1); set(hYMin, 'String', num2str(yMin)); end
            if isnan(yMax), yMax = defaults(2); set(hYMax, 'String', num2str(yMax)); end
        end
        
        ySettings(plotType) = [yMin, yMax];

        % UI Sichtbarkeit
        if plotType == 7 % Heatmap
            set(hSliderTime, 'Visible', 'on');
            set(lblTime, 'Visible', 'on');
            set(hBtnPlay, 'Visible', 'on');
            set(lblThreshold, 'Visible', 'on');
            set(hEditThreshold, 'Visible', 'on');
            set(hFixedScale, 'Visible', 'off');
            set(hFilterFreq, 'Visible', 'off');
            set(hYMin, 'Visible', 'off');
            set(hYMax, 'Visible', 'off');
            set(hLblYAxis, 'Visible', 'off');
            set(hLblYMin, 'Visible', 'off');
            set(hLblYMax, 'Visible', 'off');
            set(hEnergyMode, 'Visible', 'off');
        else
            set(hSliderTime, 'Visible', 'off');
            set(lblTime, 'Visible', 'off');
            set(hBtnPlay, 'Visible', 'off');
            set(lblThreshold, 'Visible', 'off');
            set(hEditThreshold, 'Visible', 'off');
            set(hFixedScale, 'Visible', 'on');
            set(hFilterFreq, 'Visible', 'on');
            if plotType == 1, set(hShowAirAbs, 'Visible', 'on'); else, set(hShowAirAbs, 'Visible', 'off'); end
            set(hYMin, 'Visible', 'on');
            set(hYMax, 'Visible', 'on');
            set(hLblYAxis, 'Visible', 'on');
            set(hLblYMin, 'Visible', 'on');
            set(hLblYMax, 'Visible', 'on');
            
            if plotType == 5 || plotType == 6
                set(hEnergyMode, 'Visible', 'on');
            else
                set(hEnergyMode, 'Visible', 'off');
            end
        end

        % Axes Reset
        delete(findobj(f, 'Type', 'axes'));

        if plotType == 1 && isCompare
            ax1 = axes(f, 'Position', [0.32 0.55 0.65 0.38]); 
            ax2 = axes(f, 'Position', [0.32 0.10 0.65 0.35]);
        else
            ax = axes(f, 'Position', [0.32 0.1 0.65 0.85]);
            grid(ax, 'on'); hold(ax, 'on');
        end

        % Plotting
        switch plotType
            case 1 % SPEKTRUM (Terz)
                f_vec = R1.freq.f_center;
                y1 = R1.freq.terz_dbfs;
                
                if useFreqFilter
                    mask = (f_vec >= 4000) & (f_vec <= 64000);
                else
                    mask = true(size(f_vec));
                end
                
                f_sub = f_vec(mask);
                y1_sub = y1(mask);
                
                y1_plot = [y1_sub, y1_sub(end)];
                x_plot = (1:length(y1_plot)) - 0.5;
                
                x_labels = arrayfun(@(x) sprintf('%g', x), f_sub, 'UniformOutput', false);
                x_ticks = 1:length(f_sub);
                
                if isCompare
                    y2 = R2.freq.terz_dbfs;
                    y2_sub = y2(mask);
                    y2_plot = [y2_sub, y2_sub(end)];
                    
                    axes(ax1); 
                    name1_leg = sprintf('%s (L_{sum}=%.1f dB)', cleanName(name1), R1.freq.sum_level);
                    name2_leg = sprintf('%s (L_{sum}=%.1f dB)', cleanName(name2), R2.freq.sum_level);
                    
                    stairs(x_plot, y1_plot, 'b-', 'LineWidth', 1.5, 'DisplayName', name1_leg); hold on;
                    stairs(x_plot, y2_plot, 'r-', 'LineWidth', 1.5, 'DisplayName', name2_leg);
                    grid on; legend show; ylabel('Pegel [dBFS]'); title('Frequenzgang Vergleich');
                    set(gca, 'XTick', x_ticks, 'XTickLabel', x_labels);
                    xtickangle(45);
                    xlim([0 length(f_sub)+1]);
                    if useFixedScale
                        ylim([yMin yMax]);
                    end
                    
                    axes(ax2);
                    diff_y = y2_sub - y1_sub;
                    bar(x_ticks, diff_y, 'FaceColor', [0.5 0.5 0.5], 'BarWidth', 1);
                    grid on; ylabel('Differenz [dB]'); xlabel('Frequenz [Hz]');
                    title('Differenz (Messung 2 - Messung 1)');
                    set(gca, 'XTick', x_ticks, 'XTickLabel', x_labels);
                    xtickangle(45);
                    xlim([0 length(f_sub)+1]);
                    
                    % Luftdämpfung Plotten (Overlay)
                    if hShowAirAbs.Value && isfield(R1, 'info') && isfield(R1.info, 'distance') && R1.info.distance > 0
                        axes(ax1); % Auf obere Achse wechseln
                        yyaxis right;
                        
                        T_plot = 20; LF_plot = 50;
                        if isfield(R1.meta, 'T'), T_plot = R1.meta.T; end
                        if isfield(R1.meta, 'LF'), LF_plot = R1.meta.LF; end
                        [A_dB_plot, ~, f_air] = airabsorb(101.325, R1.meta.fs, 8192, T_plot, LF_plot, R1.info.distance);
                        
                        A_dB_terz = interp1(f_air, A_dB_plot, f_sub, 'linear', 'extrap');
                        
                        plot(x_plot(1:end-1)+0.5, A_dB_terz, 'k--', 'LineWidth', 1, 'DisplayName', sprintf('Luftdämpfung (%.2fm)', R1.info.distance));
                        ylabel('Dämpfung [dB]');
                        ax1.YAxis(2).Color = 'k';
                        legend('show'); % Legende aktualisieren
                        
                        yyaxis left;
                    end
                else
                    stairs(x_plot, y1_plot, 'b-', 'LineWidth', 2);
                    grid on; xlabel('Frequenz [Hz]'); ylabel('Pegel [dBFS]');
                    title(sprintf('Spektrum: %s (L_{sum} = %.1f dB)', cleanName(name1), R1.freq.sum_level));
                    set(gca, 'XTick', x_ticks, 'XTickLabel', x_labels);
                    xtickangle(45);
                    xlim([0 length(f_sub)+1]);
                    if useFixedScale
                        ylim([yMin yMax]);
                    end
                    
                    if hShowAirAbs.Value && isfield(R1, 'info') && isfield(R1.info, 'distance') && R1.info.distance > 0
                        yyaxis right
                        T_plot = 20; LF_plot = 50;
                        if isfield(R1.meta, 'T'), T_plot = R1.meta.T; end
                        if isfield(R1.meta, 'LF'), LF_plot = R1.meta.LF; end
                        [A_dB_plot, ~, f_air] = airabsorb(101.325, R1.meta.fs, 8192, T_plot, LF_plot, R1.info.distance);
                        A_dB_terz = interp1(f_air, A_dB_plot, f_sub, 'linear', 'extrap');
                        
                        plot(x_plot(1:end-1)+0.5, A_dB_terz, 'k--', 'LineWidth', 1.5, 'DisplayName', sprintf('Luftdämpfung (%.2fm)', R1.info.distance));
                        ylabel('Dämpfung [dB]');
                        ax.YAxis(2).Color = 'k';
                        legend show;
                        yyaxis left
                    end
                end

            case 2 % IMPULSANTWORT (Zeit)
                t1 = (0:length(R1.time.ir)-1) / R1.meta.fs * 1000; % ms
                
                if isCompare
                    t2 = (0:length(R2.time.ir)-1) / R2.meta.fs * 1000;
                    plot(t1, R1.time.ir, 'b', 'DisplayName', cleanName(name1));
                    plot(t2, R2.time.ir, 'r', 'DisplayName', cleanName(name2));
                    legend show;
                    title('Impulsantworten Vergleich');
                else
                    if all(R1.time.ir == 0)
                        text(0.5, 0.5, 'Keine Zeitdaten (Average File)', 'Units', 'normalized', 'HorizontalAlignment', 'center');
                    else
                        plot(t1, R1.time.ir, 'b');
                    end
                    title(['Impulsantwort: ' cleanName(name1)]);
                    infoStr = sprintf('Truncation: Idx %d bis %d\nEnergieanteil: %.1f%%', ...
                        R1.time.metrics.idx_start, R1.time.metrics.idx_end, R1.time.metrics.energy_share*100);
                    text(0.05, 0.9, infoStr, 'Units', 'normalized', 'BackgroundColor', 'w');
                end
                xlabel('Zeit [ms]'); ylabel('Amplitude');
                grid on;
                if useFixedScale
                    ylim([-FS_global_ref, FS_global_ref] * 1.1);
                end

            case 3 % ENERGIE ÜBER ZEIT (ETC)
                etc1 = 20*log10(abs(R1.time.ir) + eps);
                t1 = (0:length(etc1)-1) / R1.meta.fs * 1000;
                
                maxVal1 = max(etc1);
                
                if isCompare
                    etc2 = 20*log10(abs(R2.time.ir) + eps);
                    t2 = (0:length(etc2)-1) / R2.meta.fs * 1000;
                    maxVal2 = max(etc2);
                    globalMax = max(maxVal1, maxVal2);
                    
                    plot(t1, etc1, 'b', 'DisplayName', cleanName(name1));
                    plot(t2, etc2, 'r', 'DisplayName', cleanName(name2));
                    legend show;
                    ylim([globalMax-60, globalMax+5]);
                    title('Energie-Zeit-Kurve (ETC) Vergleich');
                else
                    plot(t1, etc1, 'b');
                    ylim([maxVal1-60, maxVal1+5]);
                    title(['Energie-Zeit-Kurve (ETC): ' cleanName(name1)]);
                end
                xlabel('Zeit [ms]'); ylabel('Pegel [dB]');
                grid on;
                if useFixedScale
                    ylim([yMin yMax]);
                end

            case 4 % ENERGY DECAY CURVE (EDC)
                edc1 = calc_edc(R1.time.ir);
                t1 = (0:length(edc1)-1) / R1.meta.fs * 1000;
                
                if isCompare
                    edc2 = calc_edc(R2.time.ir);
                    t2 = (0:length(edc2)-1) / R2.meta.fs * 1000;
                    
                    plot(t1, edc1, 'b', 'DisplayName', cleanName(name1));
                    plot(t2, edc2, 'r', 'DisplayName', cleanName(name2));
                    legend show;
                    title('Energy Decay Curve (EDC) Vergleich');
                else
                    plot(t1, edc1, 'b');
                    title(['Energy Decay Curve (EDC): ' cleanName(name1)]);
                end
                xlabel('Zeit [ms]'); ylabel('Pegel [dB]');
                grid on;
                if useFixedScale
                    ylim([yMin yMax]);
                end

            case 5 % PEGEL ÜBER ENTFERNUNG
                [dist1, lev1, ~] = get_variant_levels(R1.meta.variante, hSource1.Value, useEnergyMode);
                
                scatter(dist1, lev1, 60, 'b', 'filled', 'DisplayName', strrep(R1.meta.variante, '_', ' ')); hold on;
                
                if ~isempty(dist1)
                    [dist_ideal, L_ideal] = calc_ideal_curve(dist1, lev1, useEnergyMode);
                    plot(dist_ideal, L_ideal, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Ideal 1/r');
                end
                
                if isCompare
                    [dist2, lev2, ~] = get_variant_levels(R2.meta.variante, hSource2.Value, useEnergyMode);
                    scatter(dist2, lev2, 60, 'r', 'filled', 'DisplayName', strrep(R2.meta.variante, '_', ' '));
                end
                
                xlabel('Entfernung von Quelle [m]'); 
                if useEnergyMode
                    ylabel('Energie (linear)');
                    title('Energieabfall über Entfernung');
                else
                    ylabel('Summenpegel [dBFS]');
                    title('Pegelabfall über Entfernung');
                end
                grid on; legend show;
                
                if useFixedScale && ~useEnergyMode
                    ylim([yMin yMax]);
                end
                
                text(0.02, 0.05, 'Punkte zeigen Messpositionen 1-15', 'Units', 'normalized', 'FontSize', 8, 'Color', [0.5 0.5 0.5]);

            case 6 % 3D SCATTER (RAUM)
                geo = get_geometry();
                
                [dist1, lev1, pos1] = get_variant_levels(R1.meta.variante, hSource1.Value, useEnergyMode);
                x1 = []; y1 = [];
                for p = pos1
                    g = geo([geo.pos] == p);
                    if ~isempty(g), x1(end+1) = g.x; y1(end+1) = g.y; end
                end
                
                scatter3(x1, y1, lev1, 80, 'b', 'filled', 'DisplayName', strrep(R1.meta.variante, '_', ' ')); hold on;
                
                for i = 1:length(x1)
                    text(x1(i), y1(i), lev1(i), sprintf('  P%d', pos1(i)), 'FontSize', 8);
                end

                if isCompare
                    [dist2, lev2, pos2] = get_variant_levels(R2.meta.variante, hSource2.Value, useEnergyMode);
                    x2 = []; y2 = [];
                    for p = pos2
                        g = geo([geo.pos] == p);
                        if ~isempty(g), x2(end+1) = g.x; y2(end+1) = g.y; end
                    end
                    scatter3(x2, y2, lev2, 80, 'r', 'filled', 'DisplayName', strrep(R2.meta.variante, '_', ' '));
                    
                    common = intersect(pos1, pos2);
                    for p = common
                        i1 = find(pos1 == p);
                        i2 = find(pos2 == p);
                        plot3([x1(i1) x1(i1)], [y1(i1) y1(i1)], [lev1(i1) lev2(i2)], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
                    end
                end
                
                z_source = max(lev1); 
                if isCompare && ~isempty(lev2), z_source = max(z_source, max(lev2)); end
                scatter3(0, 0, z_source, 100, 'k', 'filled', 'DisplayName', 'Quelle');
                
                grid on; view(45, 30);
                xlabel('X [m]'); ylabel('Y [m]');
                if useEnergyMode
                    zlabel('Energie (linear)');
                    title('Räumliche Energieverteilung');
                else
                    zlabel('Pegel [dBFS]');
                    title('Räumliche Pegelverteilung');
                end
                legend show;
                
                if useFixedScale && ~useEnergyMode
                    zlim([yMin yMax]);
                end

            case 7 % HEATMAP (RAUMZEIT)
                t_ms = get(hSliderTime, 'Value');
                set(lblTime, 'String', sprintf('Zeit: %.1f ms', t_ms));
                
                data1 = get_heatmap_data(R1.meta.variante, 1);
                grid1 = calc_heatmap_grid(data1, t_ms, R1.meta.fs, FS_global_ref);
                
                min_db = str2double(get(hEditThreshold, 'String'));
                if isnan(min_db), min_db = -60; end
                cLim = [min_db 0]; 
                
                if isCompare
                    data2 = get_heatmap_data(R2.meta.variante, 2);
                    grid2 = calc_heatmap_grid(data2, t_ms, R2.meta.fs, FS_global_ref);
                    
                    axes(ax1);
                    imagesc(grid1);
                    colormap(ax1, jet); caxis(ax1, cLim); colorbar;
                    title(sprintf('%s (%.1f ms)', strrep(R1.meta.variante,'_',' '), t_ms));
                    axis square; axis off;
                    add_heatmap_labels(grid1, min_db);
                    
                    axes(ax2);
                    imagesc(grid2);
                    colormap(ax2, jet); caxis(ax2, cLim); colorbar;
                    title(sprintf('%s (%.1f ms)', strrep(R2.meta.variante,'_',' '), t_ms));
                    axis square; axis off;
                    add_heatmap_labels(grid2, min_db);
                else
                    imagesc(grid1);
                    colormap(jet); caxis(cLim); colorbar;
                    title(sprintf('Energieverteilung: %s @ %.1f ms', strrep(R1.meta.variante,'_',' '), t_ms));
                    axis square; axis off;
                    add_heatmap_labels(grid1, min_db);
                end

            case 8 % NACHHALLZEIT (RT60) ÜBER FREQUENZ
                if isfield(R1.freq, 't30') && ~isempty(R1.freq.t30)
                    t30_1 = R1.freq.t30;
                    f_vec = R1.freq.t30_freqs;
                else
                    [t30_1, f_vec] = calc_rt60_spectrum(R1.time.ir, R1.meta.fs);
                end
                
                t30_1_plot = [t30_1, t30_1(end)];
                x_plot = (1:length(t30_1_plot)) - 0.5;
                
                [avg_t30_1, ~] = get_avg_rt60(R1.meta.variante, hSource1.Value);
                avg_t30_1_plot = [avg_t30_1, avg_t30_1(end)];
                
                % X-Achse Labels
                x_idx = 1:length(f_vec);
                x_labels = arrayfun(@(x) sprintf('%g', x), f_vec, 'UniformOutput', false);
                
                if isCompare
                    if isfield(R2.freq, 't30') && ~isempty(R2.freq.t30), t30_2 = R2.freq.t30;
                    else, [t30_2, ~] = calc_rt60_spectrum(R2.time.ir, R2.meta.fs); end
                    
                    t30_2_plot = [t30_2, t30_2(end)];
                    [avg_t30_2, ~] = get_avg_rt60(R2.meta.variante, hSource2.Value);
                    avg_t30_2_plot = [avg_t30_2, avg_t30_2(end)];
                    
                    stairs(x_plot, t30_1_plot, 'b-', 'LineWidth', 1.5, 'DisplayName', cleanName(name1)); hold on;
                    stairs(x_plot, avg_t30_1_plot, 'b--', 'LineWidth', 1, 'DisplayName', ['Ø ' strrep(R1.meta.variante, '_', ' ')]);
                    stairs(x_plot, t30_2_plot, 'r-', 'LineWidth', 1.5, 'DisplayName', cleanName(name2));
                    stairs(x_plot, avg_t30_2_plot, 'r--', 'LineWidth', 1, 'DisplayName', ['Ø ' strrep(R2.meta.variante, '_', ' ')]);
                    legend show;
                    title('Nachhallzeit RT60 Vergleich');
                else
                    stairs(x_plot, t30_1_plot, 'b-', 'LineWidth', 2, 'DisplayName', cleanName(name1)); hold on;
                    stairs(x_plot, avg_t30_1_plot, 'k--', 'LineWidth', 1.5, 'DisplayName', ['Ø ' strrep(R1.meta.variante, '_', ' ')]);
                    legend show;
                    title(['Nachhallzeit RT60: ' cleanName(name1)]);
                end
                
                set(gca, 'XTick', x_idx, 'XTickLabel', x_labels);
                xtickangle(45);
                xlim([0 length(f_vec)+1]);
                
                xlabel('Frequenz [Hz]'); ylabel('Nachhallzeit RT60 [s]');
                grid on; 
                if useFixedScale, ylim([0 0.4]); end
        end
    end

    function R = loadData(filename, sourceType)
        if sourceType == 1
            % Processed
            tmp = load(fullfile(procDir, filename));
            R = tmp.Result;
            
            % Distanz nachtragen (wichtig für Luftdämpfung)
            if ~isfield(R, 'info') || ~isfield(R.info, 'distance')
                dist = 0;
                geo = get_geometry();
                if isfield(R.meta, 'type') && strcmp(R.meta.type, 'Receiver')
                    posNum = str2double(R.meta.position);
                    if ~isnan(posNum)
                        idx = find([geo.pos] == posNum);
                        if ~isempty(idx), dist = geo(idx).distance; end
                    end
                end
                R.info.distance = dist;
            end
        else
            % Raw Data
            filepath = fullfile(dataDir, filename);
            [S, meta] = load_and_parse_file(filepath);
            ir = extract_ir(S);
            if isempty(ir), ir = zeros(100,1); end
            ir = ir - mean(ir); % DC-Offset entfernen für konsistente Darstellung
            
            R.time.ir = ir;
            R.time.metrics.idx_start = 1;
            R.time.metrics.idx_end = length(ir);
            R.time.metrics.energy_share = 1;
            R.meta = meta;
            if ~isfield(R.meta, 'fs'), R.meta.fs = 500e3; end
            
            % Distanz ermitteln (auch für Processed wichtig für Plot)
            dist = 0;
            geo = get_geometry();
            if isfield(meta, 'type') && strcmp(meta.type, 'Receiver')
                posNum = str2double(meta.position);
                if ~isnan(posNum)
                    idx = find([geo.pos] == posNum);
                    if ~isempty(idx), dist = geo(idx).distance; end
                end
            end
            R.info.distance = dist;
            
            % Distanz für Luftdämpfung ermitteln
            % (Bereits oben berechnet)
            
            % T und LF auslesen (für Raw Data)
            T_val = 20; LF_val = 50;
            if isfield(S, 'T') && ~isempty(S.T), T_val = mean(S.T); end
            if isfield(S, 'Lf') && ~isempty(S.Lf), LF_val = mean(S.Lf);
            elseif isfield(S, 'LF') && ~isempty(S.LF), LF_val = mean(S.LF); end
            
            R.meta.T = T_val;
            R.meta.LF = LF_val;
            
            [L_terz, L_sum, f_center] = calc_terz_spectrum(R.time.ir, R.meta.fs, FS_global_ref, R.info.distance, T_val, LF_val);
            R.freq.f_center = f_center;
            R.freq.terz_dbfs = L_terz;
            R.freq.sum_level = L_sum;
        end
    end

    function [avg_vals, f_vec] = get_avg_rt60(variante, sourceType)
        % Berechnet durchschnittliche RT60
        f_vec = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
        sum_t30 = zeros(size(f_vec));
        count_t30 = zeros(size(f_vec));
        
        if sourceType == 1 % Processed
            files = dir(fullfile(procDir, sprintf('Proc_%s_Pos*.mat', variante)));
        else % Raw
            files = dir(fullfile(dataDir, sprintf('*%s*.mat', variante)));
        end
        
        for i = 1:length(files)
            try
                if sourceType == 1
                    D = load(fullfile(files(i).folder, files(i).name), 'Result');
                    ir = D.Result.time.ir;
                    fs_loc = D.Result.meta.fs;
                else
                    [S, meta] = load_and_parse_file(fullfile(files(i).folder, files(i).name));
                    if ~strcmp(meta.variante, variante), continue; end
                    ir = extract_ir(S);
                    if isempty(ir), continue; end
                    ir = ir - mean(ir);
                    fs_loc = 500e3;
                end
                
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

    function [dist, levels, positions] = get_variant_levels(variante, sourceType, energyMode)
        geo = get_geometry();
        dist = []; levels = []; positions = [];
        
        if sourceType == 1 % Processed
            files = dir(fullfile(procDir, sprintf('Proc_%s_Pos*.mat', variante)));
        else % Raw
            files = dir(fullfile(dataDir, sprintf('*%s*.mat', variante)));
        end
        
        for i = 1:length(files)
            try
                if sourceType == 1
                    D = load(fullfile(files(i).folder, files(i).name), 'Result');
                    meta = D.Result.meta;
                    if energyMode
                        val = D.Result.time.metrics.energy;
                    else
                        val = D.Result.freq.sum_level;
                    end
                else
                    [S, meta] = load_and_parse_file(fullfile(files(i).folder, files(i).name));
                    if ~strcmp(meta.variante, variante), continue; end
                    
                    ir = extract_ir(S);
                    if isempty(ir), continue; end
                    if energyMode
                        val = sum((ir - mean(ir)).^2);
                    else
                        val = 20*log10(rms(ir - mean(ir)) / FS_global_ref + eps);
                    end
                end
                
                posNum = str2double(meta.position);
                if isnan(posNum), continue; end
                
                idx = find([geo.pos] == posNum);
                if ~isempty(idx)
                    d = geo(idx).distance;
                    if d > 0 % Quelle (d=0) ausschließen für Log-Plot
                        dist(end+1) = d;
                        levels(end+1) = val;
                        positions(end+1) = posNum;
                    end
                end
            catch
            end
        end
    end

    function savePlot(~, ~)
        [filename, pathname] = uiputfile({'*.png', 'PNG Bild (*.png)'; '*.pdf', 'PDF Dokument (*.pdf)'; '*.fig', 'MATLAB Figur (*.fig)'}, 'Plot speichern als...');
        if isequal(filename, 0), return; end
        savePath = fullfile(pathname, filename);
        
        f_temp = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1000 700]);
        new_ax = copyobj(findobj(f, 'Type', 'axes'), f_temp);
        
        colormap(f_temp, colormap(f));
        
        % Layout Anpassung
        for i = 1:length(new_ax)
            try
                pos = get(new_ax(i), 'Position');
                new_x = max(0.05, pos(1) - 0.22); % Verschiebe nach links statt Breite zu erzwingen
                set(new_ax(i), 'Position', [new_x, pos(2), pos(3), pos(4)]);
            catch
            end
        end
        
        try
            if endsWith(filename, '.fig')
                savefig(f_temp, savePath);
            elseif exist('exportgraphics', 'file')
                exportgraphics(f_temp, savePath, 'Resolution', 300);
            else
                saveas(f_temp, savePath);
            end
        catch
        end
        delete(f_temp);
    end

    % Heatmap Helper
    function updateHeatmapFrame(~, ~)
        updatePlot();
    end

    function playAnimation(~, ~)
        if isPlaying
            isPlaying = false;
            set(hBtnPlay, 'String', 'Play Animation');
            return;
        end

        isPlaying = true;
        set(hBtnPlay, 'String', 'Pause Animation');

        t_min = get(hSliderTime, 'Min');
        t_max = get(hSliderTime, 'Max');
        step = 0.5; % ms pro Frame
        
        t_curr = get(hSliderTime, 'Value');
        if t_curr >= t_max - step, t_curr = t_min; end
        
        for t = t_curr:step:t_max
            if ~isPlaying || ~isvalid(f), break; end
            set(hSliderTime, 'Value', t);
            updatePlot();
            drawnow;
            pause(0.05);
        end
        
        if isPlaying && isvalid(hBtnPlay)
            isPlaying = false;
            set(hBtnPlay, 'String', 'Play Animation');
        end
    end

    function dataMap = get_heatmap_data(variante, slot)
        % Lädt IRs für Heatmap (Cached)
        if slot == 1 && strcmp(heatmapCache.variante1, variante)
            dataMap = heatmapCache.data1; return;
        elseif slot == 2 && strcmp(heatmapCache.variante2, variante)
            dataMap = heatmapCache.data2; return;
        end
        
        dataMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
        
        files = dir(fullfile(procDir, sprintf('Proc_%s_*.mat', variante)));
        
        for i = 1:length(files)
            try
                tmp = load(fullfile(files(i).folder, files(i).name), 'Result');
                meta = tmp.Result.meta;
                
                key = '';
                if strcmp(meta.type, 'Source')
                    key = 'Q1';
                else
                    pNum = str2double(meta.position);
                    if ~isnan(pNum)
                        key = num2str(pNum);
                    else
                        digits = regexp(meta.position, '\d+', 'match');
                        if ~isempty(digits), key = digits{1}; end
                    end
                end
                
                if ~isempty(key)
                    dataMap(key) = tmp.Result.time.ir;
                end
            catch
            end
        end
        
        if slot == 1
            heatmapCache.variante1 = variante; heatmapCache.data1 = dataMap;
        else
            heatmapCache.variante2 = variante; heatmapCache.data2 = dataMap;
        end
    end

    function add_heatmap_labels(gridData, threshold)
        layoutLabels = {
            'M1', 'M2', 'M3', 'M4';
            'M5', 'M6', 'M7', 'M8';
            'M9', 'M10', 'M11', 'M12';
            'Q1', 'M13', 'M14', 'M15'
        };
        [rows, cols] = size(layoutLabels);
        for r = 1:rows
            for c = 1:cols
                val = gridData(r,c);
                lbl = layoutLabels{r,c};
                if ~isnan(val) && val > threshold
                    text(c, r, sprintf('%s\n%.0f', lbl, val), ...
                        'HorizontalAlignment', 'center', 'Color', 'k', 'FontSize', 8, 'FontWeight', 'bold');
                else
                    text(c, r, lbl, ...
                        'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5], 'FontSize', 8);
                end
            end
        end
    end

    function s = cleanName(filename)
        s = strrep(filename, 'Proc_', '');
        s = strrep(s, 'Time_', '');
        s = strrep(s, '.mat', '');
        s = strrep(s, '_', ' ');
    end

    % Raw Data Helper
    function [S, meta] = load_and_parse_file(filepath)
        [~, fname, ~] = fileparts(filepath);
        S = load(filepath);
        meta = struct();
        meta.filename = fname;
        
        tokens = regexp(fname, '^(.*?)[_,]Pos[_,]?(\w+)', 'tokens', 'once', 'ignorecase');
        if ~isempty(tokens)
            meta.variante = tokens{1};
            meta.position = tokens{2};
            meta.type = 'Receiver';
        else
            tokens = regexp(fname, '^(.*?)[_,]Quelle', 'tokens', 'once', 'ignorecase');
            if ~isempty(tokens)
                meta.variante = tokens{1};
                meta.position = 'Q1';
                meta.type = 'Source';
            else
                meta.variante = 'Unknown';
                meta.position = '0';
                meta.type = 'Unknown';
            end
        end
    end

    function ir = extract_ir(S)
        ir = [];
        if isfield(S,'RiR') && ~isempty(S.RiR), ir = double(S.RiR(:));
        elseif isfield(S,'RIR') && ~isempty(S.RIR), ir = double(S.RIR(:));
        elseif isfield(S,'aufn') && ~isempty(S.aufn), ir = double(S.aufn(:));
        else
            fns = fieldnames(S);
            for f = 1:numel(fns)
                fname = fns{f};
                if startsWith(fname, '__'), continue; end
                v = S.(fname);
                if isnumeric(v) && numel(v) > 1000, ir = double(v(:)); return; end
            end
        end
    end
end