%% Heatmap Video Generator
% Erstellt Videos der Energieausbreitung im Raum.

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
outputVideoDir = 'Videos';
fs = 500e3;

% Video Settings
videoFPS = 30;
timeStep_ms = 0.05; % 1 Sample @ 500kHz (Maximale Zeitauflösung)
windowSize_ms = 0.5; % Erhöht auf 0.5ms (2 Perioden @ 4kHz) für glatten RMS
maxDuration_s = 0.05;
cLim = [-50 0];
peakHoldTime_s = 1.0; % Peak-Hold Zeit in Sekunden

% Grid Layout
positionsLayout = {
    'M1',  'M2',  'M3',  'M4';
    'M5',  'M6',  'M7',  'M8';
    'M9',  'M10', 'M11', 'M12';
    'Q1',  'M13', 'M14', 'M15';
};

%% Setup
if ~exist(dataDir, 'dir'), error('Datenordner "%s" nicht gefunden!', dataDir); end
if ~exist(outputVideoDir,'dir'), mkdir(outputVideoDir); end

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

if ~exist('variantNames', 'var')
    variantNames = {};
end

if isempty(variantNames)
    warning('Keine Varianten in "%s" gefunden. Prüfen Sie den Pfad oder führen Sie step1 aus.', dataDir);
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

%% Video Erstellung
for v = 1:numel(variantNames)
    variante = variantNames{v};
    fprintf('Verarbeite: %s\n', variante);
    
    % Daten laden
    [rows, cols] = size(positionsLayout);
    irs = load_variant_irs_local(dataDir, matFiles, variante, positionsLayout);
    
    % Zeitvektor
    dt = timeStep_ms / 1000;
    winLen = windowSize_ms / 1000;
    
    currentMaxLen = 0;
    for r=1:rows, for c=1:cols, currentMaxLen = max(currentMaxLen, length(irs{r,c})); end, end
    duration = min(maxDuration_s, currentMaxLen / fs);
    timePoints = 0:dt:duration;
    
    if isempty(timePoints)
        continue;
    end
    
    % Video Init
    videoName = fullfile(outputVideoDir, ['Heatmap_' variante '.mp4']);
    vObj = VideoWriter(videoName, 'MPEG-4');
    vObj.FrameRate = videoFPS;
    open(vObj);
    
    fig = figure('Visible', 'off', 'Position', [100, 100, 600, 500], 'Color', 'w');
    
    % Patch-Objekt für Felder mit Abständen erstellen
    boxSize = 0.7; % Größe der Felder (0.5 = 50% Lücke)
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
        'FaceVertexCData', NaN(rows*cols, 1), ...
        'FaceColor', 'flat', 'EdgeColor', 'none');
    
    % Custom Colormap: Hellgrün -> Orange
    nC = 1024;
    r = linspace(0.6, 1, nC)';
    g = linspace(1, 0.5, nC)';
    b = linspace(0.6, 0, nC)';
    colormap([r, g, b]);
    caxis(cLim);
    cb = colorbar;
    cb.Label.String = 'L_{eq} [dBFS]';
    axis ij; axis equal; axis on;
    xlim([0.5, cols+0.5]); ylim([0.5, rows+0.5]);
    set(gca, 'XTick', [], 'YTick', []);
    xlabel('Längsrichtung'); ylabel('Höhe');
    
    hTitle = title('', 'FontSize', 14);
    
    hText = gobjects(rows, cols);
    for r=1:rows, for c=1:cols, hText(r,c) = text(c, r, '', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold'); end, end

    % Peak-Hold Tracking initialisieren
    peakValues = ones(rows, cols) * cLim(1); % Initialisiere mit Minimum
    peakTimes = zeros(rows, cols); % Zeitpunkt des letzten Peaks
    lastValues = ones(rows, cols) * cLim(1); % Vorheriger Wert für Peak-Erkennung

    % Frames rendern
    nFrames = length(timePoints);
    reverseStr = '';
    tStart = tic;
    
    for t_idx = 1:nFrames
        t_start = timePoints(t_idx);
        t_end = t_start + winLen;
        
        idx_start = round(t_start * fs) + 1;
        idx_end = round(t_end * fs);
        
        gridData = NaN(rows, cols);
        
        for r = 1:rows
            for c = 1:cols
                ir = irs{r,c};
                if isempty(ir) || idx_start > length(ir)
                    val = cLim(1); % Hintergrund statt NaN (vermeidet Flackern)
                else
                    curr_idx_end = min(length(ir), idx_end);
                    segment = ir(idx_start:curr_idx_end);

                    val = 10 * log10((sum(segment.^2) + eps) / (MaxAmp_global^2));
                end
                if val < cLim(1), val = cLim(1); end

                % Heatmap verwendet aktuellen Wert (keine Peak-Hold)
                gridData(r,c) = val;

                % Peak-Erkennung: Neuer Peak wenn Wert steigt
                if val > lastValues(r,c)
                    % Neuer Peak erkannt
                    peakValues(r,c) = val;
                    peakTimes(r,c) = t_start;
                end

                lastValues(r,c) = val;
            end
        end
        
        % Daten für Patch aktualisieren (Zeilenweise linearisieren)
        % Faces wurden zeilenweise erstellt: (1,1), (1,2), (1,3), (1,4), (2,1), ...
        % gridData' transponiert und (:) linearisiert spaltenweise
        % Das ergibt: (1,1), (2,1), (3,1), (4,1), (1,2), ... = FALSCH
        % Wir brauchen zeilenweise Linearisierung ohne Transpose
        gridDataLinear = reshape(gridData.', 1, []).';
        set(hPatch, 'FaceVertexCData', gridDataLinear);
        set(hTitle, 'String', sprintf('%s\nZeit: %.3f s', strrep(variante,'_',' '), t_start));
        set(hTitle, 'String', sprintf('%s\nZeit: %.3f ms', strrep(variante,'_',' '), t_start * 1000));
          
        for r = 1:rows
            for c = 1:cols
                val = gridData(r,c); % Aktueller Wert für Farbbestimmung
                peakVal = peakValues(r,c); % Peak-Wert für Textanzeige
                pos = positionsLayout{r,c};

                % Nur anzeigen wenn Peak innerhalb der Hold-Zeit
                timeSincePeak = t_start - peakTimes(r,c);
                if timeSincePeak <= peakHoldTime_s && peakVal > cLim(1)
                    val_disp = round(peakVal / 3) * 3;

                    textColor = 'k';
                    % Textfarbe Schwarz (auf Hellgrün/Orange besser lesbar)

                    set(hText(r,c), 'String', sprintf('%s\n%.0f', pos, val_disp), 'Color', textColor, 'Visible', 'on');
                else
                    set(hText(r,c), 'Visible', 'off');
                end
            end
        end
        
        frame = getframe(fig);
        writeVideo(vObj, frame);
        
        % Fortschritt
        if mod(t_idx, 5) == 0 || t_idx == nFrames
            percent = t_idx / nFrames * 100;
            
            elapsed = toc(tStart);
            remTime = (elapsed / t_idx) * (nFrames - t_idx);
            
            msg = sprintf('    Fortschritt: %3.0f%% (%d/%d) - Restzeit: %02.0f:%02.0f', ...
                          percent, t_idx, nFrames, floor(remTime/60), mod(remTime, 60));
            fprintf([reverseStr, msg]);
            reverseStr = repmat('\b', 1, length(msg));
        end
    end
    fprintf('\n');
    
    close(vObj);
    close(fig);
end

%% Vergleichsvideo: Variante 1 vs Variante 4
v1_name = 'Variante_1';
v2_name = 'Variante_4';

if any(strcmpi(variantNames, v1_name)) && any(strcmpi(variantNames, v2_name))
    fprintf('Erstelle Vergleichsvideo: %s vs %s\n', v1_name, v2_name);
    
    [rows, cols] = size(positionsLayout);
    irs1 = load_variant_irs_local(dataDir, matFiles, v1_name, positionsLayout);
    irs2 = load_variant_irs_local(dataDir, matFiles, v2_name, positionsLayout);
    
    % Zeitvektor (Maximum aus beiden)
    currentMaxLen = 0;
    for r=1:rows, for c=1:cols
        currentMaxLen = max([currentMaxLen, length(irs1{r,c}), length(irs2{r,c})]); 
    end, end
    
    dt = timeStep_ms / 1000;
    winLen = windowSize_ms / 1000;
    duration = min(maxDuration_s, currentMaxLen / fs);
    timePoints = 0:dt:duration;
    
    if ~isempty(timePoints)
        videoName = fullfile(outputVideoDir, ['Heatmap_Comparison_' v1_name '_' v2_name '.mp4']);
        vObj = VideoWriter(videoName, 'MPEG-4');
        vObj.FrameRate = videoFPS;
        open(vObj);
        
        fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 500], 'Color', 'w');
        
        % --- Setup Plot 1 ---
        ax1 = subplot(1,2,1);
        [hPatch1, hText1, hTitle1] = setup_heatmap_axes(ax1, rows, cols, cLim, v1_name);
        
        % --- Setup Plot 2 ---
        ax2 = subplot(1,2,2);
        [hPatch2, hText2, hTitle2] = setup_heatmap_axes(ax2, rows, cols, cLim, v2_name);
        
        % Peak-Hold Tracking Init
        peakValues1 = ones(rows, cols) * cLim(1); peakTimes1 = zeros(rows, cols); lastValues1 = peakValues1;
        peakValues2 = ones(rows, cols) * cLim(1); peakTimes2 = zeros(rows, cols); lastValues2 = peakValues2;
        
        nFrames = length(timePoints);
        reverseStr = '';
        tStart = tic;
        
        for t_idx = 1:nFrames
            t_start = timePoints(t_idx);
            t_end = t_start + winLen;
            idx_start = round(t_start * fs) + 1;
            idx_end = round(t_end * fs);
            
            % Update 1
            [gridData1, peakValues1, peakTimes1, lastValues1] = calc_heatmap_frame(irs1, rows, cols, idx_start, idx_end, cLim, MaxAmp_global, peakValues1, peakTimes1, lastValues1, t_start);
            update_heatmap_vis(hPatch1, hText1, hTitle1, gridData1, peakValues1, peakTimes1, t_start, peakHoldTime_s, cLim, positionsLayout, v1_name);
            
            % Update 2
            [gridData2, peakValues2, peakTimes2, lastValues2] = calc_heatmap_frame(irs2, rows, cols, idx_start, idx_end, cLim, MaxAmp_global, peakValues2, peakTimes2, lastValues2, t_start);
            update_heatmap_vis(hPatch2, hText2, hTitle2, gridData2, peakValues2, peakTimes2, t_start, peakHoldTime_s, cLim, positionsLayout, v2_name);
            
            frame = getframe(fig);
            writeVideo(vObj, frame);
            
            if mod(t_idx, 10) == 0 || t_idx == nFrames
                percent = t_idx / nFrames * 100;
                elapsed = toc(tStart);
                remTime = (elapsed / t_idx) * (nFrames - t_idx);
                msg = sprintf('    Fortschritt (Vergleich): %3.0f%% (%d/%d)', percent, t_idx, nFrames);
                fprintf([reverseStr, msg]);
                reverseStr = repmat('\b', 1, length(msg));
            end
        end
        fprintf('\n');
        close(vObj);
        close(fig);
    end
end

fprintf('\nFertig.\n');

%% Helper
function irs = load_variant_irs_local(dataDir, matFiles, variante, positionsLayout)
    [rows, cols] = size(positionsLayout);
    irs = cell(rows, cols);
    for r = 1:rows
        for c = 1:cols
            posName = positionsLayout{r, c};
            filePath = find_mat_file(dataDir, matFiles, variante, posName);
            if ~isempty(filePath)
                try
                    D = load(filePath, 'Result');
                    ir_trunc = D.Result.time.ir;
                    if isfield(D.Result.time.metrics, 'idx_start')
                        pad = D.Result.time.metrics.idx_start - 1;
                        if pad > 0, ir_trunc = [zeros(pad, 1); ir_trunc]; end
                    end
                    irs{r,c} = ir_trunc;
                catch
                    irs{r,c} = [];
                end
            else
                irs{r,c} = [];
            end
        end
    end
end

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

function [hPatch, hText, hTitle] = setup_heatmap_axes(ax, rows, cols, cLim, titleStr)
    axes(ax);
    boxSize = 0.7; offset = boxSize / 2;
    vertices = []; faces = []; count = 0;
    for r = 1:rows
        for c = 1:cols
            count = count + 1;
            v = [c-offset, r-offset; c+offset, r-offset; c+offset, r+offset; c-offset, r+offset];
            vertices = [vertices; v];
            faces = [faces; (count-1)*4 + (1:4)];
        end
    end
    hPatch = patch('Vertices', vertices, 'Faces', faces, ...
        'FaceVertexCData', NaN(rows*cols, 1), ...
        'FaceColor', 'flat', 'EdgeColor', 'none');
    
    nC = 1024;
    r = linspace(0.6, 1, nC)';
    g = linspace(1, 0.5, nC)';
    b = linspace(0.6, 0, nC)';
    colormap(ax, [r, g, b]);
    caxis(ax, cLim);
    axis(ax, 'ij'); axis(ax, 'equal'); axis(ax, 'on');
    xlim(ax, [0.5, cols+0.5]); ylim(ax, [0.5, rows+0.5]);
    set(ax, 'XTick', [], 'YTick', []);
    
    hTitle = title(titleStr, 'FontSize', 14, 'Interpreter', 'none');
    hText = gobjects(rows, cols);
    for r=1:rows, for c=1:cols, hText(r,c) = text(c, r, '', 'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold'); end, end
end

function [gridData, peakValues, peakTimes, lastValues] = calc_heatmap_frame(irs, rows, cols, idx_start, idx_end, cLim, MaxAmp_global, peakValues, peakTimes, lastValues, t_start)
    gridData = NaN(rows, cols);
    for r = 1:rows
        for c = 1:cols
            ir = irs{r,c};
            if isempty(ir) || idx_start > length(ir)
                val = cLim(1);
            else
                curr_idx_end = min(length(ir), idx_end);
                segment = ir(idx_start:curr_idx_end);
                val = 10 * log10((sum(segment.^2) + eps) / (MaxAmp_global^2));
            end
            if val < cLim(1), val = cLim(1); end
            
            gridData(r,c) = val;
            
            if val > lastValues(r,c)
                peakValues(r,c) = val;
                peakTimes(r,c) = t_start;
            end
            lastValues(r,c) = val;
        end
    end
end

function update_heatmap_vis(hPatch, hText, hTitle, gridData, peakValues, peakTimes, t_start, peakHoldTime_s, cLim, positionsLayout, variante)
    gridDataLinear = reshape(gridData.', 1, []).';
    set(hPatch, 'FaceVertexCData', gridDataLinear);
    set(hTitle, 'String', sprintf('%s\n%.1f ms', strrep(variante,'_',' '), t_start * 1000));
    
    [rows, cols] = size(gridData);
    for r = 1:rows
        for c = 1:cols
            val = gridData(r,c);
            peakVal = peakValues(r,c);
            pos = positionsLayout{r,c};
            
            timeSincePeak = t_start - peakTimes(r,c);
            if timeSincePeak <= peakHoldTime_s && peakVal > cLim(1)
                val_disp = round(peakVal / 3) * 3;
                textColor = 'k';
                % if val < cLim(1)*0.75 || val > cLim(1)*0.25, textColor = 'w'; end
                set(hText(r,c), 'String', sprintf('%s\n%.0f', pos, val_disp), 'Color', textColor, 'Visible', 'on');
            else
                set(hText(r,c), 'Visible', 'off');
            end
        end
    end
end
