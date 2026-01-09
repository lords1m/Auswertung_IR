%% export_all_metrics.m
% =========================================================================
%  export_all_metrics.m
%  Exportiert akustische Parameter (Pegel, Spektren, T30) aus 'processed'
%  in eine Excel-Datei.
% =========================================================================

clear; clc;

% --- Konfiguration ---
procDir = 'processed';
outputFile = 'Gesamt_Export_Metrics.xlsx';

% Prüfen ob Ordner existiert
if ~exist(procDir, 'dir')
    error('Ordner "%s" nicht gefunden. Bitte erst die Verarbeitung (Step 1) ausführen.', procDir);
end

% Dateien auflisten
files = dir(fullfile(procDir, 'Proc_*.mat'));
if isempty(files)
    error('Keine Proc_*.mat Dateien in "%s" gefunden.', procDir);
end

fprintf('Gefunden: %d Dateien. Starte Export...\n', length(files));

% --- Datencontainer ---
meta_data = {}; % Filename, Variante, Position
broadband_data = []; % Summenpegel, Energie
terz_data = []; % Matrix der Terzpegel
t30_data = []; % Matrix der T30 Werte

freq_vec = []; % Wird aus der ersten Datei gelesen

% --- Loop über alle Dateien ---
for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);
    
    try
        % Laden
        tmp = load(filepath, 'Result');
        R = tmp.Result;
        
        % Metadaten extrahieren
        fname = files(i).name;
        variante = R.meta.variante;
        position = R.meta.position;
        if isfield(R.meta, 'type') && strcmpi(R.meta.type, 'Source')
            position = 'Quelle';
        end
        
        % Breitband-Werte
        L_sum = R.freq.sum_level;
        if isfield(R.time.metrics, 'energy')
            E_lin = R.time.metrics.energy;
        else
            E_lin = sum(R.time.ir.^2);
        end
        
        % Terzspektrum
        L_terz = R.freq.terz_dbfs;
        if isempty(freq_vec)
            freq_vec = R.freq.f_center;
        end
        
        % T30 berechnen (falls nicht vorhanden)
        if isfield(R.freq, 't30') && ~isempty(R.freq.t30)
            t30_vals = R.freq.t30;
        else
            % On-the-fly Berechnung
            [t30_vals, ~] = calc_rt60_spectrum_local(R.time.ir, R.meta.fs);
        end
        
        % Daten sammeln
        meta_data(end+1, :) = {fname, variante, position};
        broadband_data(end+1, :) = [L_sum, E_lin];
        terz_data(end+1, :) = L_terz;
        t30_data(end+1, :) = t30_vals;
        
        if mod(i, 10) == 0
            fprintf('  Verarbeite Datei %d/%d...\n', i, length(files));
        end
        
    catch ME
        fprintf('  Fehler bei Datei %s: %s\n', files(i).name, ME.message);
    end
end

fprintf('Daten gesammelt. Erstelle Excel-Datei...\n');

% --- Tabellen erstellen ---

% 1. Übersichtstabelle (Meta + Breitband)
T_meta = cell2table(meta_data, 'VariableNames', {'Datei', 'Variante', 'Position'});
T_broadband = array2table(broadband_data, 'VariableNames', {'Summenpegel_dB', 'Energie_Linear'});
T_overview = [T_meta, T_broadband];

% Spaltennamen für Frequenzen generieren
freq_names = arrayfun(@(f) sprintf('Hz_%d', round(f)), freq_vec, 'UniformOutput', false);
freq_names = strrep(freq_names, '.', '_');

% 2. Terzpegel Tabelle
T_terz = array2table(terz_data, 'VariableNames', freq_names);
T_terz_complete = [T_meta, T_terz];

% 3. T30 Tabelle
[~, t30_freqs] = calc_rt60_spectrum_local([], 500e3); % Frequenzen holen
t30_names = arrayfun(@(f) sprintf('Hz_%d', round(f)), t30_freqs, 'UniformOutput', false);
T_t30 = array2table(t30_data, 'VariableNames', t30_names);
T_t30_complete = [T_meta, T_t30];

% --- Export ---
if exist(outputFile, 'file')
    delete(outputFile); % Alte Datei löschen
end

writetable(T_overview, outputFile, 'Sheet', 'Uebersicht');
writetable(T_terz_complete, outputFile, 'Sheet', 'Terzpegel_dB');
writetable(T_t30_complete, outputFile, 'Sheet', 'Nachhallzeit_T30_s');

fprintf('Export erfolgreich abgeschlossen: %s\n', fullfile(pwd, outputFile));


% --- Lokale Hilfsfunktionen ---
function [t60_vals, f_center] = calc_rt60_spectrum_local(ir, fs)
    f_center = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
    if isempty(ir), t60_vals = NaN(1, length(f_center)); return; end
    t60_vals = NaN(1, length(f_center));
    for k = 1:length(f_center)
        fc = f_center(k); fl = fc / 2^(1/6); fu = fc * 2^(1/6);
        if fu >= fs/2, continue; end
        try
            [b, a] = butter(4, [fl fu]/(fs/2), 'bandpass'); filt_ir = filtfilt(b, a, ir);
            E = cumsum(filt_ir(end:-1:1).^2); E = E(end:-1:1); edc_db = 10*log10(E / max(E) + eps);
            idx_start = find(edc_db <= -5, 1); idx_end_rel = find(edc_db(idx_start:end) <= -35, 1);
            if ~isempty(idx_end_rel), p = polyfit((0:idx_end_rel-1)'/fs, edc_db(idx_start:idx_start+idx_end_rel-1), 1); if p(1)<0, t60_vals(k) = -60/p(1); end; end
        catch, end
    end
end