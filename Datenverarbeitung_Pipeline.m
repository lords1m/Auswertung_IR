%% ========================================================================
%% DATENVERARBEITUNGS-PIPELINE
%% Vollständige Dokumentation der Verarbeitungsschritte in korrekter Reihenfolge
%% ========================================================================
%
% Dieses Skript dokumentiert die komplette Verarbeitungspipeline für
% Raumimpulsantworten (RIR) im Ultraschallbereich.
%
% VERWENDUNGSZWECK:
% - Dokumentation aller Verarbeitungsschritte
% - Nachvollziehbare Darstellung der Datenverarbeitung
% - Referenz für Analyse und Reproduzierbarkeit
%
% ========================================================================

clear; clc; close all;

%% ========================================================================
%% SCHRITT 1: INITIALISIERUNG UND KONFIGURATION
%% ========================================================================
% Zweck: Arbeitsumgebung vorbereiten und Parameter festlegen

fprintf('========================================\n');
fprintf('SCHRITT 1: INITIALISIERUNG\n');
fprintf('========================================\n\n');

% 1.1 Arbeitsverzeichnis setzen
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
    fprintf('1.1 Arbeitsverzeichnis: %s\n', scriptDir);
end

% 1.2 Funktionspfad hinzufügen
addpath('functions');
fprintf('1.2 Funktionsordner hinzugefügt: functions/\n');

% 1.3 Verzeichnisstruktur definieren
dataDir = 'dataraw';           % Rohdaten-Ordner
procDir = 'processed';         % Ausgabe-Ordner für verarbeitete Daten
fprintf('1.3 Rohdaten-Ordner: %s\n', dataDir);
fprintf('1.3 Ausgabe-Ordner: %s\n', procDir);

% 1.4 Messparameter festlegen
fs = 500e3;                    % Abtastrate: 500 kHz
fprintf('1.4 Abtastrate: %.0f Hz (%.0f kHz)\n', fs, fs/1000);

% 1.5 Verarbeitungsoptionen
use_fixed_length = true;       % Feste Länge für alle IRs verwenden
fixed_duration_s = 0.03;       % Gewünschte Länge in Sekunden
fixed_samples = round(fixed_duration_s * fs);
fprintf('1.5 IR-Länge: %s\n', ...
    use_fixed_length ? sprintf('Fest (%.3f s = %d Samples)', fixed_duration_s, fixed_samples) : 'Dynamisch');

% 1.6 Ordnerstruktur prüfen und erstellen
if ~exist(dataDir, 'dir')
    error('FEHLER: Rohdaten-Ordner "%s" existiert nicht!', dataDir);
end
fprintf('1.6 Rohdaten-Ordner gefunden: %s\n', dataDir);

if ~exist(procDir, 'dir')
    mkdir(procDir);
    fprintf('1.6 Ausgabe-Ordner erstellt: %s\n', procDir);
end

% 1.7 Unterordner für detaillierte Ausgaben erstellen
dirTime = fullfile(procDir, 'Time_Domain');
dirFreq = fullfile(procDir, 'Frequency_Domain');

if ~exist(dirTime, 'dir')
    mkdir(dirTime);
    fprintf('1.7 Unterordner erstellt: %s\n', dirTime);
end

if ~exist(dirFreq, 'dir')
    mkdir(dirFreq);
    fprintf('1.7 Unterordner erstellt: %s\n', dirFreq);
end

fprintf('\n>>> SCHRITT 1 ABGESCHLOSSEN <<<\n\n');


%% ========================================================================
%% SCHRITT 2: GLOBALE REFERENZERMITTLUNG
%% ========================================================================
% Zweck: Höchsten Amplitudenwert über alle Messungen finden
%        Dieser dient als Referenz für dBFS-Berechnungen

fprintf('========================================\n');
fprintf('SCHRITT 2: GLOBALE REFERENZERMITTLUNG\n');
fprintf('========================================\n\n');

% 2.1 Alle .mat Dateien im Rohdaten-Ordner finden
files = dir(fullfile(dataDir, '*.mat'));
fprintf('2.1 Anzahl gefundene Dateien: %d\n', length(files));

if isempty(files)
    error('FEHLER: Keine .mat Dateien im Ordner "%s" gefunden!', dataDir);
end

% 2.2 Maximale Amplitude über alle Dateien suchen
FS_global = 0;
fprintf('2.2 Durchsuche alle Dateien nach maximaler Amplitude...\n');

for i = 1:length(files)
    try
        filepath = fullfile(files(i).folder, files(i).name);
        S = load(filepath);

        % Impulsantwort extrahieren
        ir = extract_ir(S);

        if ~isempty(ir)
            max_amp = max(abs(ir));
            if max_amp > FS_global
                FS_global = max_amp;
                fprintf('    [%d/%d] Neue maximale Amplitude: %.5f (Datei: %s)\n', ...
                    i, length(files), FS_global, files(i).name);
            end
        end
    catch ME
        fprintf('    [%d/%d] WARNUNG: Fehler beim Laden von %s: %s\n', ...
            i, length(files), files(i).name, ME.message);
    end
end

% 2.3 Fallback, falls keine gültige Amplitude gefunden wurde
if FS_global == 0
    FS_global = 1;
    fprintf('2.3 WARNUNG: Keine gültigen Amplituden gefunden. Verwende Fallback: FS_global = 1\n');
else
    fprintf('2.3 Globaler Referenzpegel festgelegt: FS_global = %.5f\n', FS_global);
end

fprintf('\n>>> SCHRITT 2 ABGESCHLOSSEN <<<\n\n');


%% ========================================================================
%% SCHRITT 3: GEOMETRIEDATEN LADEN
%% ========================================================================
% Zweck: Raumgeometrie für Distanzberechnungen bereitstellen

fprintf('========================================\n');
fprintf('SCHRITT 3: GEOMETRIEDATEN LADEN\n');
fprintf('========================================\n\n');

% 3.1 Geometrie aus Funktion laden
geo = get_geometry();
fprintf('3.1 Geometriedaten geladen: %d Positionen definiert\n', length(geo));

% 3.2 Geometrie-Informationen anzeigen
fprintf('3.2 Positionsübersicht:\n');
fprintf('    %-8s %-8s %-8s %-12s\n', 'Position', 'X [m]', 'Y [m]', 'Distanz [m]');
fprintf('    %s\n', repmat('-', 1, 44));
for i = 1:length(geo)
    fprintf('    %-8d %-8.2f %-8.2f %-12.3f\n', ...
        geo(i).pos, geo(i).x, geo(i).y, geo(i).distance);
end

fprintf('\n>>> SCHRITT 3 ABGESCHLOSSEN <<<\n\n');


%% ========================================================================
%% SCHRITT 4: EINZELDATEI-VERARBEITUNG (HAUPTSCHLEIFE)
%% ========================================================================
% Zweck: Jede Rohdatei einzeln verarbeiten und Metriken berechnen

fprintf('========================================\n');
fprintf('SCHRITT 4: EINZELDATEI-VERARBEITUNG\n');
fprintf('========================================\n\n');

summary_data = {};
processed_count = 0;
skipped_count = 0;

for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);

    fprintf('----------------------------------------\n');
    fprintf('[%d/%d] Verarbeite: %s\n', i, length(files), files(i).name);
    fprintf('----------------------------------------\n');

    % ====================================================================
    % 4.1 DATEI LADEN UND METADATEN PARSEN
    % ====================================================================
    fprintf('4.1 Datei laden und parsen...\n');

    [S, meta] = load_and_parse_file(filepath);

    if isempty(S) || isempty(meta.variante)
        fprintf('    [SKIP] Datei konnte nicht geparst werden\n');
        skipped_count = skipped_count + 1;
        continue;
    end

    fprintf('    - Variante: %s\n', meta.variante);
    fprintf('    - Typ: %s\n', meta.type);
    fprintf('    - Position: %s\n', meta.position);

    % ====================================================================
    % 4.2 UMGEBUNGSPARAMETER AUSLESEN
    % ====================================================================
    fprintf('4.2 Umgebungsparameter auslesen...\n');

    % Standardwerte
    T_val = 20;    % Temperatur in °C
    LF_val = 50;   % Luftfeuchte in %

    % Aus Datei auslesen (falls vorhanden)
    if isfield(S, 'T') && ~isempty(S.T)
        T_val = mean(S.T);
    end

    if isfield(S, 'Lf') && ~isempty(S.Lf)
        LF_val = mean(S.Lf);
    elseif isfield(S, 'LF') && ~isempty(S.LF)
        LF_val = mean(S.LF);
    end

    fprintf('    - Temperatur: %.1f °C\n', T_val);
    fprintf('    - Luftfeuchte: %.1f %%\n', LF_val);

    % ====================================================================
    % 4.3 IMPULSANTWORT EXTRAHIEREN
    % ====================================================================
    fprintf('4.3 Impulsantwort extrahieren...\n');

    ir_raw = extract_ir(S);

    if isempty(ir_raw)
        fprintf('    [SKIP] Keine Impulsantwort extrahierbar\n');
        skipped_count = skipped_count + 1;
        continue;
    end

    fprintf('    - Rohdaten: %d Samples (%.3f s)\n', ...
        length(ir_raw), length(ir_raw)/fs);

    % ====================================================================
    % 4.4 IMPULSANTWORT TRUNKIEREN
    % ====================================================================
    fprintf('4.4 Impulsantwort trunkieren...\n');

    % Trunkierung durchführen
    target_samples = 0;
    if use_fixed_length
        target_samples = fixed_samples;
    end

    [ir_trunc, metrics] = truncate_ir(ir_raw, target_samples);

    fprintf('    - DC-Offset entfernt\n');
    fprintf('    - Onset erkannt bei Sample: %d\n', metrics.idx_start);
    fprintf('    - Ende bei Sample: %d\n', metrics.idx_end);
    fprintf('    - Trunkierte Länge: %d Samples (%.3f s)\n', ...
        length(ir_trunc), length(ir_trunc)/fs);
    fprintf('    - SNR: %.2f dB\n', metrics.snr_db);
    fprintf('    - Energieanteil: %.2f %%\n', metrics.energy_share * 100);

    % ====================================================================
    % 4.5 DISTANZ ZUR QUELLE ERMITTELN
    % ====================================================================
    fprintf('4.5 Distanz zur Quelle ermitteln...\n');

    dist = 0;

    if strcmp(meta.type, 'Receiver')
        posNum = str2double(meta.position);

        if ~isnan(posNum)
            idx = find([geo.pos] == posNum);

            if ~isempty(idx)
                dist = geo(idx).distance;
                fprintf('    - Distanz: %.3f m (Position %d)\n', dist, posNum);
                fprintf('    - Koordinaten: (%.2f, %.2f) m\n', ...
                    geo(idx).x, geo(idx).y);
            else
                fprintf('    - WARNUNG: Position %d nicht in Geometrie definiert\n', posNum);
            end
        end
    else
        fprintf('    - Distanz: 0 m (Quellmessung)\n');
    end

    % ====================================================================
    % 4.6 TERZSPEKTRUM BERECHNEN
    % ====================================================================
    fprintf('4.6 Terzspektrum berechnen...\n');

    % Berechnung mit Luftdämpfungskorrektur
    [L_terz, L_sum, f_center] = calc_terz_spectrum(ir_trunc, fs, FS_global, dist, T_val, LF_val);

    fprintf('    - Frequenzbereich: %.1f kHz - %.1f kHz\n', ...
        f_center(1)/1000, f_center(end)/1000);
    fprintf('    - Anzahl Terzbänder: %d\n', length(f_center));
    fprintf('    - Summenpegel: %.2f dBFS\n', L_sum);

    if dist > 0
        fprintf('    - Luftdämpfung korrigiert für %.3f m\n', dist);
    end

    % ====================================================================
    % 4.7 NACHHALLZEIT (T30) BERECHNEN
    % ====================================================================
    fprintf('4.7 Nachhallzeit (T30) berechnen...\n');

    [t30_vals, t30_freqs] = calc_rt60_spectrum(ir_trunc, fs, T_val, LF_val);

    if ~isempty(t30_vals)
        valid_t30 = sum(isfinite(t30_vals));
        fprintf('    - T30 für %d von %d Bändern berechnet\n', ...
            valid_t30, length(t30_vals));

        if valid_t30 > 0
            t30_mean = mean(t30_vals(isfinite(t30_vals)));
            fprintf('    - Durchschnittliche T30: %.3f s\n', t30_mean);
        end
    else
        fprintf('    - WARNUNG: Keine T30-Werte berechnet\n');
    end

    % ====================================================================
    % 4.8 ERGEBNISSE SPEICHERN
    % ====================================================================
    fprintf('4.8 Ergebnisse speichern...\n');

    % Dateinamen-Tag erstellen
    if strcmp(meta.type, 'Source')
        nameTag = sprintf('%s_Quelle', meta.variante);
    else
        nameTag = sprintf('%s_Pos%s', meta.variante, meta.position);
    end

    % 4.8.1 Zeitbereich speichern
    save(fullfile(dirTime, ['Time_' nameTag '.mat']), ...
        'ir_trunc', 'metrics', 'meta');
    fprintf('    - Zeitbereich: Time_%s.mat\n', nameTag);

    % 4.8.2 Frequenzbereich speichern
    save(fullfile(dirFreq, ['Spec_' nameTag '.mat']), ...
        'L_terz', 'L_sum', 'f_center', 't30_vals', 'meta');
    fprintf('    - Frequenzbereich: Spec_%s.mat\n', nameTag);

    % 4.8.3 Result-Struktur erstellen und speichern
    Result = struct();

    % Metadaten
    Result.meta = meta;
    Result.meta.fs = fs;
    Result.meta.FS_global_used = FS_global;
    Result.meta.T = T_val;
    Result.meta.LF = LF_val;

    % Zeitbereich
    Result.time.ir = ir_trunc;
    Result.time.metrics = metrics;

    % Frequenzbereich
    Result.freq.f_center = f_center;
    Result.freq.terz_dbfs = L_terz;
    Result.freq.sum_level = L_sum;
    Result.freq.t30 = t30_vals;
    Result.freq.t30_freqs = t30_freqs;

    % Hauptdatei speichern
    if strcmp(meta.type, 'Source')
        saveName = sprintf('Proc_%s_Quelle.mat', meta.variante);
    else
        saveName = sprintf('Proc_%s_Pos%s.mat', meta.variante, meta.position);
    end

    save(fullfile(procDir, saveName), 'Result');
    fprintf('    - Hauptdatei: %s\n', saveName);

    % Zur Zusammenfassung hinzufügen
    summary_data(end+1,:) = {meta.variante, meta.position, L_sum, ...
                             metrics.snr_db, saveName};

    processed_count = processed_count + 1;
    fprintf('    [OK] Datei erfolgreich verarbeitet\n\n');
end

fprintf('----------------------------------------\n');
fprintf('VERARBEITUNGSSTATISTIK:\n');
fprintf('----------------------------------------\n');
fprintf('Gesamt: %d Dateien\n', length(files));
fprintf('Verarbeitet: %d Dateien\n', processed_count);
fprintf('Übersprungen: %d Dateien\n', skipped_count);
fprintf('\n>>> SCHRITT 4 ABGESCHLOSSEN <<<\n\n');


%% ========================================================================
%% SCHRITT 5: ZUSAMMENFASSUNG ERSTELLEN
%% ========================================================================
% Zweck: Übersichtstabelle über alle verarbeiteten Dateien erstellen

fprintf('========================================\n');
fprintf('SCHRITT 5: ZUSAMMENFASSUNG ERSTELLEN\n');
fprintf('========================================\n\n');

if ~isempty(summary_data)
    % 5.1 Tabelle erstellen
    fprintf('5.1 Erstelle Zusammenfassungstabelle...\n');

    summary_table = cell2table(summary_data, ...
        'VariableNames', {'Variante', 'Position', 'SumLevel', 'SNR', 'File'});

    % 5.2 Sortieren
    summary_table = sortrows(summary_table, {'Variante', 'Position'});
    fprintf('    - Einträge: %d\n', height(summary_table));

    % 5.3 Speichern als .mat
    save(fullfile(procDir, 'Summary_Database.mat'), 'summary_table');
    fprintf('5.2 Gespeichert: Summary_Database.mat\n');

    % 5.4 Speichern als Excel
    writetable(summary_table, fullfile(procDir, 'Summary.xlsx'));
    fprintf('5.3 Gespeichert: Summary.xlsx\n');

    % 5.5 Vorschau anzeigen
    fprintf('\n5.4 Vorschau (erste 10 Einträge):\n');
    disp(summary_table(1:min(10, height(summary_table)), :));

    fprintf('\n>>> SCHRITT 5 ABGESCHLOSSEN <<<\n\n');
else
    fprintf('[WARNUNG] Keine Daten zum Zusammenfassen vorhanden\n');
    fprintf('\n>>> SCHRITT 5 ÜBERSPRUNGEN <<<\n\n');
end


%% ========================================================================
%% SCHRITT 6: DURCHSCHNITTSWERTE PRO VARIANTE BERECHNEN
%% ========================================================================
% Zweck: Energetische Mittelung über alle Positionen einer Variante

fprintf('========================================\n');
fprintf('SCHRITT 6: DURCHSCHNITTSWERTE BERECHNEN\n');
fprintf('========================================\n\n');

if ~isempty(summary_data)
    % 6.1 Eindeutige Varianten finden
    unique_vars = unique(summary_table.Variante);
    fprintf('6.1 Gefundene Varianten: %d\n', length(unique_vars));

    for k = 1:length(unique_vars)
        v = unique_vars{k};
        fprintf('\n----------------------------------------\n');
        fprintf('Variante: %s\n', v);
        fprintf('----------------------------------------\n');

        % 6.2 Filter: Nur Receiver (keine Quellmessungen)
        mask = strcmp(summary_table.Variante, v) & ...
               ~strcmp(summary_table.Position, 'Quelle');
        subset = summary_table(mask, :);

        if isempty(subset)
            fprintf('[SKIP] Keine Receiver-Positionen gefunden\n');
            continue;
        end

        fprintf('6.2 Anzahl Positionen: %d\n', height(subset));

        % 6.3 Template laden (für Metadaten und Struktur)
        first_file = fullfile(procDir, subset.File{1});
        tmp = load(first_file);
        R_tmpl = tmp.Result;

        % 6.4 Energien summieren
        fprintf('6.3 Energetische Mittelung durchführen...\n');

        sum_E_terz = 0;
        sum_E_total = 0;
        n = height(subset);

        for j = 1:n
            D = load(fullfile(procDir, subset.File{j}));

            % Terzspektrum: dB → linear
            E_terz = 10.^(D.Result.freq.terz_dbfs / 10);
            E_terz(~isfinite(E_terz)) = 0;
            sum_E_terz = sum_E_terz + E_terz;

            % Summenpegel: dB → linear
            E_tot = 10^(D.Result.freq.sum_level / 10);
            if ~isfinite(E_tot)
                E_tot = 0;
            end
            sum_E_total = sum_E_total + E_tot;
        end

        % 6.5 Durchschnitt berechnen
        avg_E_terz = sum_E_terz / n;
        avg_E_total = sum_E_total / n;

        % 6.6 Zurück in dB konvertieren
        avg_terz_dB = 10 * log10(avg_E_terz + eps);
        avg_sum_dB = 10 * log10(avg_E_total + eps);

        fprintf('    - Durchschnittlicher Summenpegel: %.2f dBFS\n', avg_sum_dB);

        % 6.7 Result-Struktur erstellen
        Result = R_tmpl;
        Result.meta.position = 'Average';
        Result.meta.type = 'Average';

        Result.time.ir = zeros(100,1);  % Dummy (kein sinnvolles gemitteltes IR)
        Result.time.metrics.energy = avg_E_total * (Result.meta.FS_global_used^2);
        Result.time.metrics.snr_db = NaN;
        Result.time.metrics.idx_start = 1;
        Result.time.metrics.idx_end = 1;
        Result.time.metrics.energy_total = NaN;
        Result.time.metrics.energy_share = NaN;

        Result.freq.terz_dbfs = avg_terz_dB;
        Result.freq.sum_level = avg_sum_dB;
        Result.freq.t30 = [];  % T30-Mittelung ist komplex, hier leer lassen
        Result.freq.t30_freqs = [];

        % 6.8 Speichern
        saveName = sprintf('Proc_%s_Average.mat', v);
        save(fullfile(procDir, saveName), 'Result');
        fprintf('6.4 Gespeichert: %s\n', saveName);
    end

    fprintf('\n>>> SCHRITT 6 ABGESCHLOSSEN <<<\n\n');
else
    fprintf('[WARNUNG] Keine Daten für Durchschnittsberechnung vorhanden\n');
    fprintf('\n>>> SCHRITT 6 ÜBERSPRUNGEN <<<\n\n');
end


%% ========================================================================
%% ZUSAMMENFASSUNG DER PIPELINE
%% ========================================================================

fprintf('========================================\n');
fprintf('PIPELINE ERFOLGREICH ABGESCHLOSSEN\n');
fprintf('========================================\n\n');

fprintf('DURCHGEFÜHRTE SCHRITTE:\n\n');

fprintf('1. INITIALISIERUNG\n');
fprintf('   - Arbeitsverzeichnis und Pfade konfiguriert\n');
fprintf('   - Ordnerstruktur erstellt\n');
fprintf('   - Parameter definiert (fs=%.0f kHz)\n\n', fs/1000);

fprintf('2. GLOBALE REFERENZERMITTLUNG\n');
fprintf('   - Maximale Amplitude: %.5f\n');
fprintf('   - Als FS_global für dBFS-Berechnung verwendet\n\n', FS_global);

fprintf('3. GEOMETRIEDATEN\n');
fprintf('   - %d Positionen geladen\n');
fprintf('   - Distanzen zur Quelle definiert\n\n', length(geo));

fprintf('4. EINZELDATEI-VERARBEITUNG\n');
fprintf('   - %d Dateien verarbeitet\n', processed_count);
fprintf('   - %d Dateien übersprungen\n', skipped_count);
fprintf('   Für jede Datei:\n');
fprintf('   4.1 Laden und Parsen (Variante, Position, Typ)\n');
fprintf('   4.2 Umgebungsparameter (Temperatur, Luftfeuchte)\n');
fprintf('   4.3 Impulsantwort extrahiert\n');
fprintf('   4.4 IR trunkiert (DC-Removal, Onset-Detektion)\n');
fprintf('   4.5 Distanz zur Quelle ermittelt\n');
fprintf('   4.6 Terzspektrum berechnet (mit Luftdämpfungskorrektur)\n');
fprintf('   4.7 Nachhallzeit T30 berechnet\n');
fprintf('   4.8 Ergebnisse gespeichert\n\n');

fprintf('5. ZUSAMMENFASSUNG\n');
fprintf('   - Summary_Database.mat erstellt\n');
fprintf('   - Summary.xlsx exportiert\n\n');

fprintf('6. DURCHSCHNITTSWERTE\n');
fprintf('   - Pro Variante über alle Positionen gemittelt\n');
fprintf('   - Energetische Mittelung durchgeführt\n');
fprintf('   - Average-Dateien erstellt\n\n');

fprintf('========================================\n');
fprintf('AUSGABEN:\n');
fprintf('========================================\n');
fprintf('Verarbeitete Daten: %s/\n', procDir);
fprintf('  - Proc_[Variante]_Pos[X].mat      (Einzelne Positionen)\n');
fprintf('  - Proc_[Variante]_Quelle.mat      (Quellmessungen)\n');
fprintf('  - Proc_[Variante]_Average.mat     (Durchschnittswerte)\n');
fprintf('  - Summary_Database.mat            (Übersichtstabelle)\n');
fprintf('  - Summary.xlsx                    (Excel-Export)\n');
fprintf('\nDetails:\n');
fprintf('  - %s/Time_*.mat                    (Zeitbereich)\n', dirTime);
fprintf('  - %s/Spec_*.mat                    (Frequenzbereich)\n\n', dirFreq);

fprintf('========================================\n');
fprintf('NÄCHSTE SCHRITTE:\n');
fprintf('========================================\n');
fprintf('- Verwende interactive_plotter.m für explorative Analyse\n');
fprintf('- Nutze step2_plot_example(alt).m für Variantenvergleiche\n');
fprintf('- Führe step3_aggregate_energy_spectra(alt).m für Excel-Exporte aus\n');
fprintf('- Analysiere mit Darstellung_*.m Skripten (Heatmaps, Pegel, etc.)\n\n');

fprintf('========================================\n\n');


%% ========================================================================
%% HILFS-INFORMATIONEN
%% ========================================================================
%
% DATEISTRUKTUR (Result-Struct):
% -------------------------------
% Result.meta
%   .variante           - Name der Variante (z.B. "Variante_1")
%   .position           - Position (z.B. "1", "Quelle", "Average")
%   .type               - Typ ("Receiver", "Source", "Average")
%   .fs                 - Abtastrate [Hz]
%   .FS_global_used     - Verwendeter Referenzpegel
%   .T                  - Temperatur [°C]
%   .LF                 - Luftfeuchte [%]
%
% Result.time
%   .ir                 - Trunkierte Impulsantwort [Samples]
%   .metrics.idx_start  - Start-Index der Trunkierung
%   .metrics.idx_end    - End-Index der Trunkierung
%   .metrics.snr_db     - Signal-Rausch-Verhältnis [dB]
%   .metrics.energy     - Energie der trunkierten IR
%   .metrics.energy_total - Gesamtenergie der Original-IR
%   .metrics.energy_share - Anteil der erhaltenen Energie
%
% Result.freq
%   .f_center           - Terz-Mittenfrequenzen [Hz]
%   .terz_dbfs          - Terzpegel [dBFS]
%   .sum_level          - Summenpegel [dBFS]
%   .t30                - Nachhallzeit T30 pro Band [s]
%   .t30_freqs          - Frequenzen für T30-Werte [Hz]
%
%
% FREQUENZBEREICH:
% ----------------
% Terzbänder nach IEC 61260 (Basis 10):
% - 4 kHz bis 63 kHz
% - 13 Terzbänder
% - Mittenfrequenzen: [4k 5k 6.3k 8k 10k 12.5k 16k 20k 25k 31.5k 40k 50k 63k]
%
%
% KORREKTUREN:
% ------------
% - DC-Offset: Wird automatisch entfernt (Mittelwert subtrahiert)
% - Luftdämpfung: Frequenzabhängige Korrektur basierend auf:
%   - Distanz zur Quelle
%   - Temperatur
%   - Luftfeuchte
%   - ISO 9613-1 Modell
%
%
% METRIKEN:
% ---------
% - dBFS: Dezibel relativ zu Full Scale (FS_global)
% - SNR: Signal-to-Noise Ratio
% - T30: Nachhallzeit basierend auf -5 dB bis -35 dB Abfall
% - EDC: Energy Decay Curve (Schroeder-Integration)
%
% ========================================================================
