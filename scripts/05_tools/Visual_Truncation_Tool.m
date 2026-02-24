function Visual_Truncation_Tool()
    % VISUAL_TRUNCATION_TOOL
    % Interaktives Tool zum visuellen Schneiden von Impulsantworten.
    %
    % Funktionen:
    % - Lädt .mat Dateien aus 'dataraw' oder 'processed'.
    % - Visualisiert die Impulsantwort (Zeitbereich).
    % - Erlaubt das Verschieben von Start- und End-Markern per Maus.
    % - Berechnet Pegel (Peak, RMS, Energie) für den ausgewählten Bereich in Echtzeit.
    % - Exportiert die geschnittene IR.

    %% Setup & Pfade
    scriptDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(scriptDir)); % Zwei Ebenen nach oben

    % Zum Repository-Root wechseln und functions hinzufügen
    currentDir = pwd;
    cd(repoRoot);
    addpath('functions');
init_repo_paths();

    % Standard-Verzeichnisse
    dirsToCheck = {'dataraw', 'processed'};
    fileList = {};
    fullPaths = {};
    
    % Dateien suchen
    for i = 1:length(dirsToCheck)
        d = fullfile(baseDir, dirsToCheck{i});
        if exist(d, 'dir')
            files = dir(fullfile(d, '*.mat'));
            for k = 1:length(files)
                % Prefix für Übersichtlichkeit
                prefix = ['[' dirsToCheck{i} '] '];
                fileList{end+1} = [prefix, files(k).name]; %#ok<AGROW>
                fullPaths{end+1} = fullfile(files(k).folder, files(k).name); %#ok<AGROW>
            end
        end
    end

    %% GUI Variablen
    currentIR = [];
    currentFS = 500e3; % Default
    currentMeta = struct();
    tVec = [];
    
    % Dragging State
    dragState = struct('active', false, 'target', '', 'lastPos', 0);
    
    % Marker Positionen (in ms)
    posStart = 0;
    posEnd = 0;

    %% GUI Erstellung
    f = figure('Name', 'IR Truncation & Level Analyzer', ...
               'NumberTitle', 'off', ...
               'Position', [100, 100, 1200, 700], ...
               'Color', 'w', ...
               'WindowButtonDownFcn', @onMouseDown, ...
               'WindowButtonUpFcn', @onMouseUp, ...
               'WindowButtonMotionFcn', @onMouseMove);

    % Layout
    layout = uigridlayout(f, [1, 2]);
    layout.ColumnWidth = {250, '1x'};

    % Linkes Panel (Dateiliste & Infos)
    pnlLeft = uipanel(layout, 'Title', 'Dateiauswahl');
    pnlLeft.Layout.Row = 1; pnlLeft.Layout.Column = 1;
    
    lstFiles = uicontrol(pnlLeft, 'Style', 'listbox', ...
        'Units', 'normalized', 'Position', [0.05 0.62 0.9 0.36], ...
        'String', fileList, ...
        'Callback', @onFileSelect);

    % Axis Controls
    pnlAxes = uipanel(pnlLeft, 'Title', 'Achsen-Grenzen', ...
        'Units', 'normalized', 'Position', [0.05 0.48 0.9 0.12]);
    
    uicontrol(pnlAxes, 'Style', 'text', 'String', 'X [ms]:', ...
        'Units', 'normalized', 'Position', [0.02 0.55 0.25 0.3], 'HorizontalAlignment', 'left');
    hEditXMin = uicontrol(pnlAxes, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.3 0.6 0.3 0.3], 'Callback', @onAxisChange);
    hEditXMax = uicontrol(pnlAxes, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.65 0.6 0.3 0.3], 'Callback', @onAxisChange);

    uicontrol(pnlAxes, 'Style', 'text', 'String', 'Y:', ...
        'Units', 'normalized', 'Position', [0.02 0.15 0.25 0.3], 'HorizontalAlignment', 'left');
    hEditYMin = uicontrol(pnlAxes, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.3 0.2 0.3 0.3], 'Callback', @onAxisChange);
    hEditYMax = uicontrol(pnlAxes, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.65 0.2 0.3 0.3], 'Callback', @onAxisChange);

    % Truncation Controls
    pnlTrunc = uipanel(pnlLeft, 'Title', 'Fenster / Truncation', ...
        'Units', 'normalized', 'Position', [0.05 0.32 0.9 0.14]);
    
    uicontrol(pnlTrunc, 'Style', 'text', 'String', 'Start [ms]:', ...
        'Units', 'normalized', 'Position', [0.02 0.68 0.3 0.22], 'HorizontalAlignment', 'left');
    hEditStart = uicontrol(pnlTrunc, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.35 0.7 0.6 0.22], 'Callback', @onTruncStartChange);
        
    uicontrol(pnlTrunc, 'Style', 'text', 'String', 'Ende [ms]:', ...
        'Units', 'normalized', 'Position', [0.02 0.38 0.3 0.22], 'HorizontalAlignment', 'left');
    hEditEnd = uicontrol(pnlTrunc, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.35 0.4 0.6 0.22], 'Callback', @onTruncEndChange);
        
    uicontrol(pnlTrunc, 'Style', 'text', 'String', 'Länge [ms]:', ...
        'Units', 'normalized', 'Position', [0.02 0.08 0.3 0.22], 'HorizontalAlignment', 'left');
    hEditLen = uicontrol(pnlTrunc, 'Style', 'edit', 'String', '', ...
        'Units', 'normalized', 'Position', [0.35 0.1 0.6 0.22], 'Callback', @onTruncLenChange);

    uicontrol(pnlLeft, 'Style', 'text', 'String', 'Ergebnisse (Auswahl):', ...
        'Units', 'normalized', 'Position', [0.05 0.28 0.9 0.03], ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'left');

    lblStats = uicontrol(pnlLeft, 'Style', 'text', 'String', 'Bitte Datei laden...', ...
        'Units', 'normalized', 'Position', [0.05 0.12 0.9 0.15], ...
        'HorizontalAlignment', 'left', 'BackgroundColor', [0.95 0.95 0.95], ...
        'FontName', 'Monospaced');

    btnSave = uicontrol(pnlLeft, 'Style', 'pushbutton', 'String', 'Auswahl Speichern / Exportieren', ...
        'Units', 'normalized', 'Position', [0.05 0.02 0.9 0.08], ...
        'Callback', @onSave, 'Enable', 'off');

    % Rechtes Panel (Plot)
    pnlRight = uipanel(layout, 'Title', 'Visualisierung');
    pnlRight.Layout.Row = 1; pnlRight.Layout.Column = 2;
    
    ax = axes(pnlRight, 'Units', 'normalized', 'Position', [0.08 0.15 0.88 0.8]);
    grid(ax, 'on'); hold(ax, 'on');
    xlabel(ax, 'Zeit [ms]'); ylabel(ax, 'Amplitude');
    title(ax, 'Impulsantwort');

    % Marker Linien (Initial unsichtbar)
    hLineStart = xline(ax, 0, 'g-', 'Start', 'LineWidth', 2, 'Alpha', 0.8, 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'left');
    hLineEnd = xline(ax, 0, 'r-', 'Ende', 'LineWidth', 2, 'Alpha', 0.8, 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');
    
    % Füllfläche für Auswahl
    hFill = patch(ax, [0 0 0 0], [0 0 0 0], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');

    % Zoom Toolbar aktivieren
    zoom(f, 'on');
    pan(f, 'on');
    
    % Initialer Load falls Dateien vorhanden
    if ~isempty(fileList)
        onFileSelect([], []);
    end

    %% Callbacks

    function onFileSelect(~, ~)
        idx = lstFiles.Value;
        if isempty(idx) || idx > length(fullPaths), return; end
        
        filepath = fullPaths{idx};
        try
            loadData(filepath);
            updatePlot();
            % Reset Markers to useful defaults (e.g. 5% to 95% of energy or simple time)
            tMax = tVec(end);
            posStart = 0; 
            posEnd = tMax;
            
            % Intelligenter Start: Suche erstes Überschreiten von Threshold
            absIR = abs(currentIR);
            thresh = max(absIR) * 0.01; % -40dB
            idxStart = find(absIR > thresh, 1, 'first');
            if ~isempty(idxStart)
                posStart = max(0, tVec(idxStart) - 0.5); % 0.5ms Vorlauf
            end
            
            updateMarkers();
            calculateStats();
            btnSave.Enable = 'on';
        catch ME
            errordlg(['Fehler beim Laden: ' ME.message], 'Load Error');
        end
    end

    function onMouseDown(~, ~)
        % Prüfen ob Klick in der Nähe einer Linie war
        pt = get(ax, 'CurrentPoint');
        xClick = pt(1,1);
        
        % Toleranz in X-Achsen-Einheiten (ms)
        xLim = get(ax, 'XLim');
        tol = (xLim(2) - xLim(1)) * 0.02; % 2% der Breite
        
        distStart = abs(xClick - posStart);
        distEnd = abs(xClick - posEnd);
        
        if distStart < tol && distStart <= distEnd
            dragState.active = true;
            dragState.target = 'start';
            disableZoom(); % Zoom stört beim Draggen
        elseif distEnd < tol
            dragState.active = true;
            dragState.target = 'end';
            disableZoom();
        end
    end

    function onMouseMove(~, ~)
        if dragState.active
            pt = get(ax, 'CurrentPoint');
            xNew = pt(1,1);
            
            % Constraints
            tMax = tVec(end);
            xNew = max(0, min(tMax, xNew));
            
            if strcmp(dragState.target, 'start')
                posStart = min(xNew, posEnd); % Start darf nicht hinter Ende
            else
                posEnd = max(xNew, posStart); % Ende darf nicht vor Start
            end
            
            updateMarkers();
            calculateStats();
        end
    end

    function onMouseUp(~, ~)
        if dragState.active
            dragState.active = false;
            enableZoom();
        end
    end

    function onAxisChange(~, ~)
        xMin = str2double(get(hEditXMin, 'String'));
        xMax = str2double(get(hEditXMax, 'String'));
        yMin = str2double(get(hEditYMin, 'String'));
        yMax = str2double(get(hEditYMax, 'String'));
        
        if ~isnan(xMin) && ~isnan(xMax) && xMax > xMin
            xlim(ax, [xMin xMax]);
        end
        if ~isnan(yMin) && ~isnan(yMax) && yMax > yMin
            ylim(ax, [yMin yMax]);
        end
        updateMarkers();
    end

    function onTruncStartChange(~, ~)
        val = str2double(get(hEditStart, 'String'));
        if isnan(val) || isempty(tVec), return; end
        tMax = tVec(end);
        posStart = max(0, min(tMax, val));
        % Ensure End >= Start
        if posEnd < posStart, posEnd = posStart; end
        updateMarkers();
        calculateStats();
    end

    function onTruncEndChange(~, ~)
        val = str2double(get(hEditEnd, 'String'));
        if isnan(val) || isempty(tVec), return; end
        tMax = tVec(end);
        posEnd = max(0, min(tMax, val));
        % Ensure Start <= End
        if posStart > posEnd, posStart = posEnd; end
        updateMarkers();
        calculateStats();
    end

    function onTruncLenChange(~, ~)
        val = str2double(get(hEditLen, 'String'));
        if isnan(val) || val < 0 || isempty(tVec), return; end
        tMax = tVec(end);
        posEnd = min(tMax, posStart + val);
        updateMarkers();
        calculateStats();
    end

    function onSave(~, ~)
        % Export Dialog
        [file, path] = uiputfile('*.mat', 'Geschnittene IR speichern');
        if isequal(file, 0), return; end
        
        % Daten extrahieren
        [idxS, idxE] = getIndices();
        ir_cut = currentIR(idxS:idxE);
        
        % Speichern
        Result = struct();
        Result.time.ir = ir_cut;
        Result.meta = currentMeta; % Metadaten erhalten
        Result.meta.fs = currentFS;
        Result.meta.original_indices = [idxS, idxE];
        Result.meta.original_file = fullPaths{lstFiles.Value};
        
        save(fullfile(path, file), 'Result');
        msgbox(sprintf('Gespeichert!\nLänge: %d Samples (%.2f ms)', length(ir_cut), length(ir_cut)/currentFS*1000), 'Erfolg');
    end

    %% Helper Functions

    function loadData(filepath)
        D = load(filepath);
        
        % Versuche IR zu finden (Logik aus interactive_plotter adaptiert)
        ir = [];
        fs = 500e3; % Default
        meta = struct();
        
        if isfield(D, 'Result') && isfield(D.Result, 'time') && isfield(D.Result.time, 'ir')
            % Processed Format
            ir = D.Result.time.ir;
            if isfield(D.Result.meta, 'fs'), fs = D.Result.meta.fs; end
            if isfield(D.Result, 'meta'), meta = D.Result.meta; end
        elseif isfield(D, 'RiR')
            ir = D.RiR;
        elseif isfield(D, 'RIR')
            ir = D.RIR;
        elseif isfield(D, 'aufn')
            ir = D.aufn;
        else
            % Fallback: Suche größtes numerisches Array
            fns = fieldnames(D);
            maxLen = 0;
            for i=1:length(fns)
                val = D.(fns{i});
                if isnumeric(val) && numel(val) > maxLen
                    ir = val;
                    maxLen = numel(val);
                end
            end
        end
        
        if isempty(ir)
            error('Keine Impulsantwort in Datei gefunden.');
        end
        
        currentIR = double(ir(:));
        % DC Removal (zentrale Funktion)
        currentIR = process_ir_modifications(currentIR, 'RemoveDC', true, 'AutoSave', false);
        currentFS = fs;
        currentMeta = meta;
        tVec = (0:length(currentIR)-1) / currentFS * 1000; % ms
    end

    function updatePlot()
        cla(ax);
        plot(ax, tVec, currentIR, 'b-');
        
        % Update Axis Fields
        xl = xlim(ax);
        yl = ylim(ax);
        set(hEditXMin, 'String', sprintf('%.2f', xl(1)));
        set(hEditXMax, 'String', sprintf('%.2f', xl(2)));
        set(hEditYMin, 'String', sprintf('%.2f', yl(1)));
        set(hEditYMax, 'String', sprintf('%.2f', yl(2)));
        
        % Marker neu zeichnen (Handles gehen bei cla verloren)
        hLineStart = xline(ax, posStart, 'g-', 'Start', 'LineWidth', 2, 'Alpha', 0.8, 'LabelVerticalAlignment', 'bottom');
        hLineEnd = xline(ax, posEnd, 'r-', 'Ende', 'LineWidth', 2, 'Alpha', 0.8, 'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'right');
        
        yLim = get(ax, 'YLim');
        hFill = patch(ax, [posStart posEnd posEnd posStart], [yLim(1) yLim(1) yLim(2) yLim(2)], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
        
        title(ax, sprintf('Impulsantwort (%d Samples)', length(currentIR)));
    end

    function updateMarkers()
        set(hLineStart, 'Value', posStart);
        set(hLineEnd, 'Value', posEnd);
        
        % Update Fill Area
        yLim = get(ax, 'YLim');
        set(hFill, 'XData', [posStart posEnd posEnd posStart]);
        set(hFill, 'YData', [yLim(1) yLim(1) yLim(2) yLim(2)]);
        
        % Update Text Fields
        set(hEditStart, 'String', sprintf('%.3f', posStart));
        set(hEditEnd, 'String', sprintf('%.3f', posEnd));
        set(hEditLen, 'String', sprintf('%.3f', posEnd - posStart));
    end

    function [idxS, idxE] = getIndices()
        % Konvertiere ms zu Samples
        idxS = max(1, round(posStart / 1000 * currentFS) + 1);
        idxE = min(length(currentIR), round(posEnd / 1000 * currentFS) + 1);
        if idxS > idxE, idxS = idxE; end
    end

    function calculateStats()
        [idxS, idxE] = getIndices();
        
        if isempty(currentIR) || idxS == idxE
            set(lblStats, 'String', 'Keine Auswahl');
            return;
        end
        
        segment = currentIR(idxS:idxE);
        
        % Metriken
        peak_val = max(abs(segment));
        peak_db = 20*log10(peak_val + eps);
        
        rms_val = rms(segment);
        rms_db = 20*log10(rms_val + eps);
        
        energy = sum(segment.^2);
        
        len_ms = (idxE - idxS + 1) / currentFS * 1000;
        len_s = len_ms / 1000;
        f_min = 0;
        if len_s > 0, f_min = 1/len_s; end
        
        % Text Update
        txt = sprintf([...
            'Fenster: %.2f ms bis %.2f ms\n' ...
            'Dauer:   %.2f ms (%d Samples)\n' ...
            'Min. Freq (1/T): %.1f Hz\n\n' ...
            'L_Peak:  %.2f dB\n' ...
            'L_RMS:   %.2f dB\n' ...
            'Energie: %.4e'], ...
            posStart, posEnd, len_ms, length(segment), ...
            f_min, peak_db, rms_db, energy);
            
        set(lblStats, 'String', txt);
    end

    function disableZoom()
        zoom(f, 'off');
        pan(f, 'off');
    end

    function enableZoom()
        zoom(f, 'on');
        pan(f, 'on');
    end
end
