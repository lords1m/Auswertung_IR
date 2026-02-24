%% Validierungsskript zur Überprüfung der Berechnungsergebnisse
%
% Dieses Skript durchsucht alle .mat-Dateien im 'processed'-Verzeichnis und
% dessen Unterverzeichnissen. Es führt Validierungsprüfungen für alle numerischen
% Variablen in jeder Datei durch, um potenzielle Probleme oder extreme
% Abweichungen in den berechneten Daten zu identifizieren.
%
% Die Ergebnisse werden im Command Window ausgegeben.

clc;
clear;
close all;

% Repository-Pfade initialisieren
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir), cd(scriptDir); end
if exist('../../functions', 'dir')
    cd('../..');
elseif exist('../functions', 'dir')
    cd('..');
end
addpath('functions');
init_repo_paths();

fprintf('Starte Validierung der Berechnungsergebnisse...\n');
fprintf('================================================\n\n');

%% Konfiguration
processed_data_path = 'processed'; % Hauptverzeichnis der verarbeiteten Daten
freq_domain_path = fullfile(processed_data_path, 'Frequency_Domain'); % Unterverzeichnis
outlier_threshold_std = 3; % Z-Score-Schwellenwert (Anzahl der Standardabweichungen)

%% Datensätze finden
fprintf('Suche nach *.mat-Dateien in:\n');
fprintf('- %s\n', processed_data_path);
fprintf('- %s\n\n', freq_domain_path);

% Finde Dateien im Hauptverzeichnis und im Frequency_Domain-Verzeichnis
file_list_root = dir(fullfile(processed_data_path, '*.mat'));
file_list_freq = dir(fullfile(freq_domain_path, '*.mat'));

% Da 'dir' keine vollen Pfade für den Ordner speichert, fügen wir sie hier hinzu
for k = 1:length(file_list_root)
    file_list_root(k).folder = processed_data_path;
end
for k = 1:length(file_list_freq)
    file_list_freq(k).folder = freq_domain_path;
end

% Kombiniere die Listen der beiden Verzeichnisse
file_list = [file_list_root; file_list_freq];

if isempty(file_list)
    fprintf('Keine relevanten .mat-Dateien in den Zielverzeichnissen gefunden.\n');
    return;
end

fprintf('Gefundene Dateien zur Überprüfung: %d\n\n', length(file_list));

total_issues_found = 0;

%% Schleife über alle gefundenen Dateien
for i = 1:length(file_list)
    file_path = fullfile(file_list(i).folder, file_list(i).name);
    fprintf('--- Überprüfe Datei: %s ---\n', file_path);
    
    try
        % Lade Daten aus der .mat-Datei in einen Struct
        data_struct = load(file_path);
        variable_names = fieldnames(data_struct);
        file_issues_found = 0;
        
        fprintf('  (i) Gefundene Variablen: %s\n', strjoin(variable_names, ', '));
        
        numeric_vars_checked = {};
        
        % Schleife über alle Variablen in der Datei
        for j = 1:length(variable_names)
            var_name = variable_names{j};
            var_data = data_struct.(var_name);
            
            % Prüfung nur für numerische, nicht-leere Arrays durchführen
            if isnumeric(var_data) && ~isempty(var_data)
                
                numeric_vars_checked{end+1} = var_name;
                
                % 1. Prüfung: Auf NaN und Inf prüfen
                nan_indices = find(isnan(var_data));
                inf_indices = find(isinf(var_data));
                
                if ~isempty(nan_indices)
                    file_issues_found = file_issues_found + 1;
                    fprintf('      [!] WARNUNG in Variable ''%s'': %d NaN-Werte gefunden.\n', var_name, length(nan_indices));
                end
                
                if ~isempty(inf_indices)
                    file_issues_found = file_issues_found + 1;
                    fprintf('      [!] WARNUNG in Variable ''%s'': %d Inf-Werte gefunden.\n', var_name, length(inf_indices));
                end
                
                % 2. Prüfung: Statistische Ausreißer
                % Bereinige Daten von NaN/Inf für die Statistik
                clean_data = var_data(~isnan(var_data) & ~isinf(var_data));
                
                if numel(clean_data) > 1 % statistische prüfung nur bei mehr als einem wert sinnvoll
                    mean_val = mean(clean_data, 'all');
                    std_val = std(clean_data, 0, 'all');
                    
                    % Vermeide Division durch Null, wenn alle Werte gleich sind
                    if std_val > 0
                        % Z-Score Berechnung
                        z_scores = abs((clean_data - mean_val) / std_val);
                        outlier_indices = find(z_scores > outlier_threshold_std);
                        
                        if ~isempty(outlier_indices)
                            file_issues_found = file_issues_found + 1;
                            num_outliers = length(outlier_indices);
                            extreme_values = clean_data(outlier_indices);
                            fprintf('      [!] WARNUNG in Variable ''%s'': %d statistische Ausreißer gefunden (Schwellenwert > %.1f StdAbw).\n', var_name, num_outliers, outlier_threshold_std);
                        end
                    end
                end
            end
        end
        
        if ~isempty(numeric_vars_checked)
            fprintf('  (i) Überprüfte numerische Variablen: %s\n', strjoin(numeric_vars_checked, ', '));
        else
            fprintf('  (i) Keine numerischen Variablen zur Überprüfung gefunden.\n');
        end

        if file_issues_found == 0
            fprintf('  (i) Keine Auffälligkeiten in dieser Datei gefunden.\n');
        else
            total_issues_found = total_issues_found + file_issues_found;
        end
        
    catch ME
        fprintf('  [X] FEHLER beim Lesen oder Verarbeiten der Datei: %s\n', file_path);
        fprintf('      Fehlermeldung: %s\n', ME.message);
        total_issues_found = total_issues_found + 1;
    end
    fprintf('\n');
end

fprintf('================================================\n');
if total_issues_found == 0
    fprintf('Validierung abgeschlossen. Keine Probleme gefunden.\n');
else
    fprintf('Validierung abgeschlossen. Insgesamt %d Probleme gefunden.\n', total_issues_found);
end
fprintf('================================================\n');
