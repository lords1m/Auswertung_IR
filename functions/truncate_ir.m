function [ir_trunc, metrics] = truncate_ir(ir, fixed_length_samples)
    % Schneidet IR zu (Start bei Impuls, Ende bei Rauschen)
    % Optional: fixed_length_samples erzwingt eine feste Länge ab Start (mit Padding)
    
    if nargin < 2, fixed_length_samples = 0; end
    
    % Input Validierung
    if isempty(ir) || ~isnumeric(ir)
        ir_trunc = [];
        metrics = struct('idx_start',1, 'idx_end',1, 'snr_db',0, 'energy',0, 'energy_total',0, 'energy_share',0, 'original_len',0);
        return;
    end
    
    % DC entfernen (zentrale Funktion)
    ir = process_ir_modifications(ir, 'RemoveDC', true, 'AutoSave', false);
    
    N = length(ir);
    ir_abs = abs(ir);
    [max_amp, idx_peak] = max(ir_abs);
    
    if max_amp == 0
        ir_trunc = ir;
        metrics = struct('idx_start',1, 'idx_end',N, 'snr_db',0, 'energy',0, 'energy_total',0, 'energy_share',0, 'original_len',N);
        return;
    end
    
    % Rauschpegel schätzen (letzte 10%)
    noise_section = ir_abs(ceil(N*0.9):end);
    if isempty(noise_section), noise_section = ir_abs(end); end
    
    mu_noise = mean(noise_section);
    std_noise = std(noise_section);
    
    % Start finden: Rückwärtssuche vom Peak (Robustheit gegen Rauschen am Anfang)
    threshold_start = max_amp * 0.02;
    
    if idx_peak > 1
        idx_below = find(ir_abs(1:idx_peak) < threshold_start, 1, 'last');
        if isempty(idx_below), idx_onset = 1; else, idx_onset = idx_below + 1; end
    else
        idx_onset = 1;
    end
    
    % Pre-Roll (500 Samples)
    idx_start = max(1, idx_onset - 250);
    
    if fixed_length_samples > 0
        % --- Modus: Feste Länge ---
        idx_end = idx_start + fixed_length_samples - 1;
        
        if idx_end <= N
            ir_trunc = ir(idx_start:idx_end);
        else
            % Padding mit Nullen, falls Signal zu kurz ist
            padding = zeros(idx_end - N, 1);
            ir_trunc = [ir(idx_start:end); padding];
        end
    else
        % --- Modus: Dynamisches Ende (Original) ---
        threshold_end = max(mu_noise + 6*std_noise, max_amp * 0.003); 
        window_size = 1000;
        if N > window_size, env = movmean(ir_abs, window_size); else, env = ir_abs; end
        
        min_silence_samples = 10000; 
        
        if idx_peak < N
            post_peak_env = env(idx_peak:end);
            local_max_future = movmax(post_peak_env, [0, min_silence_samples]);
            idx_silence_start = find(local_max_future < threshold_end, 1, 'first');
            if ~isempty(idx_silence_start), idx_end = idx_peak + idx_silence_start - 1;
            else, idx_end = find(env > threshold_end, 1, 'last'); if isempty(idx_end), idx_end = N; end, end
        else, idx_end = N; end
        
        idx_end = min(N, idx_end + 5000); % Puffer
        if idx_end < idx_start, idx_end = N; end
        ir_trunc = ir(idx_start:idx_end);
    end
    
    % Metriken
    metrics.idx_start = idx_start;
    metrics.idx_end = idx_end;
    metrics.original_len = N;
    metrics.snr_db = 20*log10(rms(ir_trunc) / (std_noise + eps));
    metrics.energy = sum(ir_trunc.^2);
    metrics.energy_total = sum(ir.^2);
    metrics.energy_share = metrics.energy / (metrics.energy_total + eps);
end