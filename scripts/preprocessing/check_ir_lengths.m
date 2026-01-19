%% check_ir_lengths.m
% Skript zum Überprüfen der Längen aller verarbeiteten Impulsantworten
% in 'processed/Proc_*.mat'.

clear; clc;

% Pfad anpassen falls nötig
procDir = 'processed';

if ~exist(procDir, 'dir')
    error('Ordner "%s" existiert nicht.', procDir);
end

files = dir(fullfile(procDir, 'Proc_*.mat'));
if isempty(files)
    error('Keine Proc-Dateien in "%s" gefunden.', procDir);
end

fprintf('Analysiere %d Dateien in "%s"...\n', length(files), procDir);

fileData = struct('name', {}, 'len', {});

for i = 1:length(files)
    fname = files(i).name;
    fpath = fullfile(files(i).folder, fname);
    
    try
        % Lade Datei
        tmp = load(fpath, 'Result');
        if isfield(tmp, 'Result') && isfield(tmp.Result, 'time') && isfield(tmp.Result.time, 'ir')
            len = length(tmp.Result.time.ir);
            fileData(end+1).name = fname;
            fileData(end).len = len;
        end
    catch ME
        fprintf('Fehler bei %s: %s\n', fname, ME.message);
    end
end

if isempty(fileData)
    fprintf('Keine gültigen IRs gefunden.\n');
    return;
end

% Sortieren nach Länge
[~, idx] = sort([fileData.len]);
sortedData = fileData(idx);

% Annahme fs=500kHz für Zeitanzeige
fs = 500e3; 

fprintf('\n=== Längen der Impulsantworten (Aufsteigend) ===\n');
fprintf('%-40s | %10s | %10s\n', 'Dateiname', 'Samples', 'Sekunden');
fprintf('%s\n', repmat('-', 1, 66));

for i = 1:length(sortedData)
    fprintf('%-40s | %10d | %10.4f\n', ...
        sortedData(i).name, sortedData(i).len, sortedData(i).len/fs);
end