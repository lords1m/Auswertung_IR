function [ir_out, pipeline_info] = process_ir_pipeline(ir_in, varargin)
% PROCESS_IR_PIPELINE Zentrale Pipeline für alle IR-Verarbeitungsschritte
%
% Syntax:
%   [ir_out, info] = process_ir_pipeline(ir_in)
%   [ir_out, info] = process_ir_pipeline(ir_in, 'ParameterName', Value, ...)
%
% Beschreibung:
%   Diese zentrale Funktion orchestriert alle Schritte zur Verarbeitung
%   einer Impulsantwort in der korrekten Reihenfolge:
%
%   1. DC-Offset Entfernung
%   2. Truncation (Start/Ende finden, optional feste Länge)
%   3. Normalisierung (optional)
%   4. Windowing (optional, für FFT-Analysen)
%   5. Filterung (optional, für frequenzselektive Analysen)
%   6. Auto-Save (optional)
%
% Eingabe-Parameter:
%   ir_in               - Eingabe-Impulsantwort (Vektor)
%
% Name-Value Parameter:
%   'RemoveDC'          - DC-Offset entfernen (default: true)
%   'Truncate'          - IR truncaten (default: true)
%   'TruncateLength'    - Feste Länge in Samples, 0=dynamisch (default: 0)
%   'Normalize'         - Normalisieren auf Max=1 (default: false)
%   'NormalizeTo'       - Normalisierung auf spezifischen Wert (default: 1.0)
%   'Window'            - Fenstertyp: 'none', 'hanning', 'hamming', 'blackman' (default: 'none')
%   'Filter'            - Filterung anwenden (default: false)
%   'FilterType'        - 'bandpass', 'lowpass', 'highpass' (default: 'bandpass')
%   'FilterOrder'       - Filter-Ordnung (default: 4)
%   'FilterFreq'        - Filter-Frequenzen [f_low f_high] oder [f_cutoff] (default: [4000 63000])
%   'SamplingRate'      - Abtastrate in Hz (default: 500000)
%   'AutoSave'          - Automatisch speichern (default: false)
%   'SavePath'          - Pfad für Auto-Save (erforderlich wenn AutoSave=true)
%   'Verbose'           - Debug-Ausgaben (default: false)
%
% Ausgabe:
%   ir_out              - Verarbeitete Impulsantwort
%   pipeline_info       - Struct mit Informationen über jeden Verarbeitungsschritt
%
% Beispiele:
%   % Minimale Verarbeitung (nur DC-Removal + Truncation)
%   ir_processed = process_ir_pipeline(ir_raw);
%
%   % Vollständige Verarbeitung mit fester Länge
%   [ir_out, info] = process_ir_pipeline(ir_raw, ...
%       'TruncateLength', 15000, ...
%       'Normalize', true, ...
%       'AutoSave', true, ...
%       'SavePath', 'processed/IR_01.mat');
%
%   % Für FFT-Reflexionsfaktor-Analyse mit Hanning-Fenster
%   ir_fft = process_ir_pipeline(ir_raw, ...
%       'Window', 'hanning', ...
%       'Truncate', false);
%
%   % Für Terzband-Analyse mit Bandpass-Filter
%   ir_terz = process_ir_pipeline(ir_raw, ...
%       'Filter', true, ...
%       'FilterType', 'bandpass', ...
%       'FilterFreq', [8000 16000], ...
%       'FilterOrder', 8);
%
% Siehe auch: process_ir_modifications, truncate_ir, extract_ir

% Autor: IR Processing Pipeline
% Datum: 2026-01-19

    %% Input Parser
    p = inputParser;
    addRequired(p, 'ir_in', @isnumeric);

    % Grundlegende Verarbeitung
    addParameter(p, 'RemoveDC', true, @islogical);
    addParameter(p, 'Truncate', true, @islogical);
    addParameter(p, 'TruncateLength', 0, @isnumeric);  % 0 = dynamisch

    % Normalisierung
    addParameter(p, 'Normalize', false, @islogical);
    addParameter(p, 'NormalizeTo', 1.0, @isnumeric);

    % Windowing
    addParameter(p, 'Window', 'none', @(x) ismember(x, {'none', 'hanning', 'hamming', 'blackman', 'bartlett'}));

    % Filterung
    addParameter(p, 'Filter', false, @islogical);
    addParameter(p, 'FilterType', 'bandpass', @(x) ismember(x, {'bandpass', 'lowpass', 'highpass'}));
    addParameter(p, 'FilterOrder', 4, @isnumeric);
    addParameter(p, 'FilterFreq', [4000 63000], @isnumeric);
    addParameter(p, 'SamplingRate', 500000, @isnumeric);

    % Auto-Save
    addParameter(p, 'AutoSave', false, @islogical);
    addParameter(p, 'SavePath', '', @ischar);

    % Debug
    addParameter(p, 'Verbose', false, @islogical);

    parse(p, ir_in, varargin{:});

    % Extrahiere Parameter
    opts = p.Results;

    %% Initialisierung
    ir_out = ir_in;
    pipeline_info = struct();
    pipeline_info.steps_executed = {};
    pipeline_info.original_length = length(ir_in);
    pipeline_info.original_max = max(abs(ir_in));

    if opts.Verbose
        fprintf('\n=== IR Processing Pipeline gestartet ===\n');
        fprintf('Original: %d Samples, Max=%.6f\n', length(ir_in), max(abs(ir_in)));
    end

    %% SCHRITT 1: DC-Offset Entfernung
    if opts.RemoveDC
        dc_before = mean(ir_out);
        ir_out = process_ir_modifications(ir_out, 'RemoveDC', true, 'AutoSave', false);

        pipeline_info.dc_offset_removed = true;
        pipeline_info.dc_value = dc_before;
        pipeline_info.steps_executed{end+1} = 'DC-Removal';

        if opts.Verbose
            fprintf('[1] DC-Offset entfernt: %.6f\n', dc_before);
        end
    end

    %% SCHRITT 2: Truncation
    if opts.Truncate
        [ir_out, trunc_metrics] = truncate_ir(ir_out, opts.TruncateLength);

        pipeline_info.truncation_applied = true;
        pipeline_info.truncation_metrics = trunc_metrics;
        pipeline_info.steps_executed{end+1} = 'Truncation';

        if opts.Verbose
            fprintf('[2] Truncation: %d → %d Samples (Start: %d, Ende: %d, SNR: %.2f dB)\n', ...
                    pipeline_info.original_length, length(ir_out), ...
                    trunc_metrics.idx_start, trunc_metrics.idx_end, trunc_metrics.snr_db);
        end
    end

    %% SCHRITT 3: Normalisierung
    if opts.Normalize
        max_val = max(abs(ir_out));
        if max_val > 0
            ir_out = ir_out * (opts.NormalizeTo / max_val);

            pipeline_info.normalization_applied = true;
            pipeline_info.normalization_factor = opts.NormalizeTo / max_val;
            pipeline_info.normalization_target = opts.NormalizeTo;
            pipeline_info.steps_executed{end+1} = 'Normalization';

            if opts.Verbose
                fprintf('[3] Normalisiert: Max %.6f → %.6f (Faktor: %.6f)\n', ...
                        max_val, opts.NormalizeTo, opts.NormalizeTo / max_val);
            end
        else
            warning('process_ir_pipeline:ZeroSignal', 'Signal ist Null, Normalisierung übersprungen');
        end
    end

    %% SCHRITT 4: Windowing
    if ~strcmp(opts.Window, 'none')
        N = length(ir_out);
        switch opts.Window
            case 'hanning'
                win = hanning(N);
            case 'hamming'
                win = hamming(N);
            case 'blackman'
                win = blackman(N);
            case 'bartlett'
                win = bartlett(N);
        end

        ir_out = ir_out(:) .* win(:);

        pipeline_info.window_applied = true;
        pipeline_info.window_type = opts.Window;
        pipeline_info.steps_executed{end+1} = sprintf('Windowing (%s)', opts.Window);

        if opts.Verbose
            fprintf('[4] Fensterung angewendet: %s\n', opts.Window);
        end
    end

    %% SCHRITT 5: Filterung
    if opts.Filter
        fs = opts.SamplingRate;

        % Normalisierte Frequenzen
        if strcmp(opts.FilterType, 'bandpass')
            if length(opts.FilterFreq) ~= 2
                error('process_ir_pipeline:InvalidFilterFreq', ...
                      'Bandpass benötigt [f_low f_high]');
            end
            Wn = opts.FilterFreq / (fs/2);
        else
            if length(opts.FilterFreq) ~= 1
                error('process_ir_pipeline:InvalidFilterFreq', ...
                      'Lowpass/Highpass benötigt [f_cutoff]');
            end
            Wn = opts.FilterFreq / (fs/2);
        end

        % Filter-Design
        if strcmp(opts.FilterType, 'bandpass')
            [b, a] = butter(opts.FilterOrder/2, Wn, 'bandpass');
        else
            [b, a] = butter(opts.FilterOrder, Wn, opts.FilterType);
        end

        % Anwenden (filtfilt für Null-Phasen-Verzerrung)
        ir_out = filtfilt(b, a, ir_out);

        pipeline_info.filter_applied = true;
        pipeline_info.filter_type = opts.FilterType;
        pipeline_info.filter_order = opts.FilterOrder;
        pipeline_info.filter_freq = opts.FilterFreq;
        pipeline_info.steps_executed{end+1} = sprintf('Filterung (%s, %d. Ordnung)', ...
                                                       opts.FilterType, opts.FilterOrder);

        if opts.Verbose
            fprintf('[5] Filter angewendet: %s, Ordnung %d, Freq: [', ...
                    opts.FilterType, opts.FilterOrder);
            fprintf('%.0f ', opts.FilterFreq);
            fprintf('] Hz\n');
        end
    end

    %% SCHRITT 6: Auto-Save
    if opts.AutoSave
        if isempty(opts.SavePath)
            error('process_ir_pipeline:MissingSavePath', ...
                  'AutoSave aktiviert, aber kein SavePath angegeben');
        end

        % Nutze process_ir_modifications für konsistentes Speichern
        % (wir übergeben die bereits verarbeitete IR, nur für Save)
        try
            % Lade existierende Datei falls vorhanden
            if exist(opts.SavePath, 'file')
                data = load(opts.SavePath);
                if isfield(data, 'Result')
                    data.Result.ir = ir_out;
                    data.Result.last_modified = datetime('now');
                    data.Result.pipeline_info = pipeline_info;
                    Result = data.Result;
                else
                    Result = create_result_struct(ir_out, pipeline_info);
                end
            else
                Result = create_result_struct(ir_out, pipeline_info);
            end

            % Speichern
            [filepath_dir, ~, ~] = fileparts(opts.SavePath);
            if ~exist(filepath_dir, 'dir') && ~isempty(filepath_dir)
                mkdir(filepath_dir);
            end
            save(opts.SavePath, 'Result', '-v7.3');

            pipeline_info.auto_saved = true;
            pipeline_info.save_path = opts.SavePath;
            pipeline_info.steps_executed{end+1} = 'Auto-Save';

            if opts.Verbose
                fprintf('[6] Auto-Save: %s\n', opts.SavePath);
            end
        catch ME
            warning('process_ir_pipeline:SaveFailed', ...
                    'Auto-Save fehlgeschlagen: %s', ME.message);
            pipeline_info.auto_saved = false;
            pipeline_info.save_error = ME.message;
        end
    end

    %% Abschluss
    pipeline_info.final_length = length(ir_out);
    pipeline_info.final_max = max(abs(ir_out));
    pipeline_info.processing_date = datetime('now');

    if opts.Verbose
        fprintf('\n=== Pipeline abgeschlossen ===\n');
        fprintf('Schritte ausgeführt: %d\n', length(pipeline_info.steps_executed));
        for i = 1:length(pipeline_info.steps_executed)
            fprintf('  [%d] %s\n', i, pipeline_info.steps_executed{i});
        end
        fprintf('Final: %d Samples, Max=%.6f\n\n', ...
                pipeline_info.final_length, pipeline_info.final_max);
    end
end

%% Hilfsfunktion: Result-Struct erstellen
function Result = create_result_struct(ir, info)
    Result = struct();
    Result.ir = ir;
    Result.pipeline_info = info;
    Result.created = datetime('now');
    Result.last_modified = datetime('now');
end
