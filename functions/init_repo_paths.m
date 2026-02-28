function repoRoot = init_repo_paths()
% INIT_REPO_PATHS Initialisiert Pfade für das Repository
%
% Syntax:
%   repoRoot = init_repo_paths()
%
% Beschreibung:
%   Diese Funktion stellt sicher, dass:
%   1. Das aktuelle Arbeitsverzeichnis das Repository-Root ist
%   2. Der 'functions' Ordner zum MATLAB-Pfad hinzugefügt ist
%   3. Alle relativen Pfade (dataraw, processed, etc.) korrekt funktionieren
%
% Ausgabe:
%   repoRoot - Absoluter Pfad zum Repository-Root-Verzeichnis
%
% Verwendung:
%   Am Anfang jedes Scripts im Repository:
%   init_repo_paths();
%
% Hinweis:
%   Diese Funktion muss im 'functions' Ordner liegen und wird automatisch
%   das Repository-Root finden, egal von wo das aufrufende Script liegt.

% Autor: Repository Refactoring 2026-01-19
% Datum: 2026-01-19

    % Finde das Repository-Root anhand dieser Funktion
    thisFile = mfilename('fullpath');
    functionsDir = fileparts(thisFile);
    repoRoot = fileparts(functionsDir);

    % Wechsle zum Repository-Root
    currentDir = pwd;
    if ~strcmp(currentDir, repoRoot)
        cd(repoRoot);
        fprintf('Arbeitsverzeichnis gewechselt zu: %s\n', repoRoot);
    end

    % Füge functions-Ordner zum Pfad hinzu (falls noch nicht vorhanden)
    if ~contains(path, functionsDir)
        addpath(functionsDir);
        fprintf('functions-Ordner zum MATLAB-Pfad hinzugefügt.\n');
    end

    % Validierung: Prüfe ob wichtige Verzeichnisse existieren
    requiredDirs = {'functions', 'scripts', 'processed'};
    for i = 1:length(requiredDirs)
        if ~exist(fullfile(repoRoot, requiredDirs{i}), 'dir')
            warning('init_repo_paths:MissingDirectory', ...
                    'Verzeichnis nicht gefunden: %s', requiredDirs{i});
        end
    end

end
