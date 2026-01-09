%% Heatmap Video Generator
% Erstellt Videos der Energieausbreitung im Raum.

clear;
clc;
close all;

% Arbeitsverzeichnis
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end

%% Einstellungen
dataDir = 'data';
outputVideoDir = 'Videos';
fs = 500e3;

% Video Settings
videoFPS = 20;
timeStep_ms = 0.05;
windowSize_ms = 0.01;
maxDuration_s = 0.1;
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

dirInfo = dir(fullfile(dataDir, '*.mat'));
matFiles = {dirInfo.name};

% Varianten identifizieren
variantNames = {};
for i = 1:numel(matFiles)
    tokens = regexp(matFiles{i}, '^(.*?)[_,]Pos', 'tokens', 'once', 'ignorecase');
    if isempty(tokens), tokens = regexp(matFiles{i}, '^(.*?)[_,]Quelle', 'tokens', 'once', 'ignorecase'); end
    if ~isempty(tokens), variantNames{end+1} = tokens{1}; end
end
variantNames = unique(variantNames);

%% Globale Referenz
MaxAmp_global = 0;
fprintf('Ermittle globale Referenz (Max Amplitude)...\n');
for i = 1:numel(matFiles)
    try
        S = load(fullfile(dataDir, matFiles{i}));
        ir = extractIR(S);
        if ~isempty(ir), MaxAmp_global = max(MaxAmp_global, max(abs(ir))); end
    catch, end
end
if MaxAmp_global == 0, MaxAmp_global = 1; end

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
                    S = load(filePath);
                    rawIR = extractIR(S);
                    [ir_trunc, ~, ~, ~, ~, ~] = truncateIR(rawIR);
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
    
    hImg = imagesc(NaN(rows, cols));
    colormap(jet);
    caxis(cLim);
    colorbar;
    axis square; axis off;
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
                    val = NaN;
                else
                    curr_idx_end = min(length(ir), idx_end);
                    segment = ir(idx_start:curr_idx_end);
                    
                    rms_val = sqrt(mean(segment.^2));
                    val = 20 * log10((rms_val + eps) / MaxAmp_global);
                end
                gridData(r,c) = val;
            end
        end
        
        set(hImg, 'CData', gridData);
        set(hTitle, 'String', sprintf('%s\nZeit: %.3f s', strrep(variante,'_',' '), t_start));
          
        for r = 1:rows
            for c = 1:cols
                val = gridData(r,c);
                pos = positionsLayout{r,c};
                if ~isnan(val) && val > cLim(1)
                    set(hText(r,c), 'String', sprintf('%s\n%.0f', pos, val), 'Color', 'k', 'Visible', 'on');
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
    if startsWith(posName, 'M')
        posNum = extractAfter(posName, 'M');
        pattern = ['^' regexptranslate('escape', variante) '(?i)[_,]Pos[_,]?0*' posNum '\.mat$'];
        idx = find(~cellfun(@isempty, regexp(allFiles, pattern, 'once')), 1);
        if ~isempty(idx), filePath = fullfile(dataDir, allFiles{idx}); end
    elseif startsWith(posName, 'Q')
        pattern = ['^' regexptranslate('escape', variante) '(?i)[_,]Quelle\.mat$'];
        idx = find(~cellfun(@isempty, regexp(allFiles, pattern, 'once')), 1);
        if ~isempty(idx), filePath = fullfile(dataDir, allFiles{idx}); end
    end
end

function ir = extractIR(S)
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

function [ir_trunc, start_idx, end_idx, E_ratio, SNR_dB, dynamic_range_dB] = truncateIR(ir)
    ir_abs = abs(ir);
    max_amp = max(ir_abs);
    start_idx = find(ir_abs > max_amp * 0.01, 1, 'first'); % Start bei 1% vom Max (empfindlicher)
    if isempty(start_idx), start_idx = 1; end
    ir_trunc = ir(start_idx:end); % Nur Start abschneiden, Ende behalten für Decay
    end_idx = length(ir); E_ratio=0; SNR_dB=0; dynamic_range_dB=0;
end