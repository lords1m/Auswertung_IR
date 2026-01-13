%% Heatmap Video Generator
% Erstellt Videos der Energieausbreitung im Raum.

clear;
clc;
close all;

% Arbeitsverzeichnis
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end
addpath('functions');

%% Einstellungen
dataDir = 'processed';
outputVideoDir = 'Videos';
fs = 500e3;

% Video Settings
videoFPS = 60;
timeStep_ms = 0.002; % 1 Sample @ 500kHz (Maximale Zeitauflösung)
windowSize_ms = 0.5; % Erhöht auf 0.5ms (2 Perioden @ 4kHz) für glatten RMS
maxDuration_s = 0.015;
cLim = [-50 0];

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
    irs = cell(rows, cols);
    
    for r = 1:rows
        for c = 1:cols
            posName = positionsLayout{r, c};
            filePath = find_mat_file(dataDir, matFiles, variante, posName);
            
            if ~isempty(filePath)
                try
                    D = load(filePath, 'Result');
                    ir_trunc = D.Result.time.ir;
                    % Synchronisation zur absoluten Zeit (Padding am Anfang)
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
    
    fig = figure('Visible', 'off', 'Position', [100, 100, 600, 500]);
    
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
        'FaceVertexCData', NaN(rows*cols, 1), ...
        'FaceColor', 'flat', 'EdgeColor', 'none');
    
    % Custom Colormap: Hell (Weiß) zu Dunkel (Blau)
    nC = 1024; % Mehr Farbstufen für glatteren Übergang
    colormap([linspace(1, 0, nC)', linspace(1, 0, nC)', linspace(1, 0.5, nC)']);
    caxis(cLim);
    colorbar;
    axis ij; axis equal; axis off;
    xlim([0.5, cols+0.5]); ylim([0.5, rows+0.5]);
    
    hTitle = title('', 'FontSize', 14);
    
    hText = gobjects(rows, cols);
    for r=1:rows, for c=1:cols, hText(r,c) = text(c, r, '', 'HorizontalAlignment', 'center'); end, end
    
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
                    
                    rms_val = sqrt(mean(segment.^2));
                    val = 20 * log10((rms_val + eps) / MaxAmp_global);
                end
                if val < cLim(1), val = cLim(1); end
                gridData(r,c) = val;
            end
        end
        
        % Daten für Patch aktualisieren (Zeilenweise linearisieren)
        gridDataT = gridData.';
        set(hPatch, 'FaceVertexCData', gridDataT(:));
        set(hTitle, 'String', sprintf('%s\nZeit: %.3f s', strrep(variante,'_',' '), t_start));
        set(hTitle, 'String', sprintf('%s\nZeit: %.3f ms', strrep(variante,'_',' '), t_start * 1000));
          
        for r = 1:rows
            for c = 1:cols
                val = gridData(r,c);
                pos = positionsLayout{r,c};
                if ~isnan(val) && val > cLim(1)
                    val_disp = round(val / 3) * 3;
                    set(hText(r,c), 'String', sprintf('%s\n%.0f', pos, val_disp), 'Color', 'k', 'Visible', 'on');
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
fprintf('\nFertig.\n');

%% Helper
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