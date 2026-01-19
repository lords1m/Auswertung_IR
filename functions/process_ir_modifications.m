function ir_out = process_ir_modifications(ir_in, varargin)
% PROCESS_IR_MODIFICATIONS Zentrale Funktion für IR-Modifikationen mit Auto-Save
%
% Syntax:
%   ir_out = process_ir_modifications(ir_in)
%   ir_out = process_ir_modifications(ir_in, 'RemoveDC', true)
%   ir_out = process_ir_modifications(ir_in, 'RemoveDC', true, 'AutoSave', true, 'FilePath', 'path/to/file.mat')
%
% Beschreibung:
%   Diese zentrale Funktion verwaltet alle IR-Modifikationen und bietet
%   automatische Speicherung bei Änderungen. Ersetzt duplizierten Code
%   an mehreren Stellen im Repository.
%
% Eingabe-Parameter:
%   ir_in           - Eingabe-Impulsantwort (Vektor)
%   'RemoveDC'      - Boolean: DC-Offset entfernen (Standard: true)
%   'AutoSave'      - Boolean: Automatisch speichern bei Änderung (Standard: false)
%   'FilePath'      - String: Pfad zur .mat Datei für Auto-Save (erforderlich wenn AutoSave=true)
%   'VarName'       - String: Name der Variable in .mat Datei (Standard: 'Result')
%   'Verbose'       - Boolean: Debug-Ausgaben anzeigen (Standard: false)
%
% Ausgabe:
%   ir_out          - Modifizierte Impulsantwort
%
% Beispiele:
%   % Nur DC-Removal
%   ir_clean = process_ir_modifications(ir_raw);
%
%   % DC-Removal mit Auto-Save
%   ir_clean = process_ir_modifications(ir_raw, 'RemoveDC', true, ...
%       'AutoSave', true, 'FilePath', 'processed/Time_XY.mat');
%
% Siehe auch: truncate_ir, extract_ir

% Autor: Refactored für zentrale IR-Verwaltung
% Datum: 2026-01-19

    % Parse Input-Parameter
    p = inputParser;
    addRequired(p, 'ir_in', @isnumeric);
    addParameter(p, 'RemoveDC', true, @islogical);
    addParameter(p, 'AutoSave', false, @islogical);
    addParameter(p, 'FilePath', '', @ischar);
    addParameter(p, 'VarName', 'Result', @ischar);
    addParameter(p, 'Verbose', false, @islogical);

    parse(p, ir_in, varargin{:});

    removeDC = p.Results.RemoveDC;
    autoSave = p.Results.AutoSave;
    filePath = p.Results.FilePath;
    varName = p.Results.VarName;
    verbose = p.Results.Verbose;

    % Validierung
    if autoSave && isempty(filePath)
        error('process_ir_modifications:MissingFilePath', ...
              'AutoSave aktiviert, aber kein FilePath angegeben!');
    end

    % Initialisierung
    ir_out = ir_in;
    modified = false;

    % --- DC-Offset Removal ---
    if removeDC
        dc_value = mean(ir_in);
        if abs(dc_value) > eps
            ir_out = ir_out - dc_value;
            modified = true;
            if verbose
                fprintf('  DC-Offset entfernt: %.6f\n', dc_value);
            end
        end
    end

    % --- Automatische Speicherung ---
    if autoSave && modified
        try
            % Prüfe ob Datei existiert
            if exist(filePath, 'file')
                % Lade existierende Datei
                data = load(filePath);

                % Update IR im Result struct (falls vorhanden)
                if isfield(data, varName) && isstruct(data.(varName))
                    data.(varName).ir = ir_out;

                    % Update Timestamp
                    data.(varName).last_modified = datetime('now');

                    % Speichern
                    Result = data.(varName);
                    save(filePath, 'Result', '-v7.3');

                    if verbose
                        fprintf('  Auto-Save erfolgreich: %s\n', filePath);
                    end
                else
                    warning('process_ir_modifications:InvalidStructure', ...
                            'Datei existiert, aber Variable "%s" nicht gefunden oder kein struct.', varName);
                end
            else
                % Neue Datei erstellen
                Result = struct();
                Result.ir = ir_out;
                Result.created = datetime('now');
                Result.last_modified = datetime('now');

                % Erstelle Verzeichnis falls nötig
                [filepath_dir, ~, ~] = fileparts(filePath);
                if ~exist(filepath_dir, 'dir')
                    mkdir(filepath_dir);
                end

                save(filePath, 'Result', '-v7.3');

                if verbose
                    fprintf('  Neue Datei erstellt und gespeichert: %s\n', filePath);
                end
            end

        catch ME
            warning('process_ir_modifications:SaveFailed', ...
                    'Auto-Save fehlgeschlagen: %s', ME.message);
        end
    end

end
