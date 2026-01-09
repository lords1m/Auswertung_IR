function [ir_trunc, metrics] = truncate_ir(ir)
    % Schneidet IR zu (Start bei Impuls, Ende bei Rauschen)
    
    % DC entfernen
    ir = ir - mean(ir);
    
    N = length(ir);
    ir_abs = abs(ir);
    max_amp = max(ir_abs);
    
    if max_amp == 0
        ir_trunc = ir;
        metrics = struct('idx_start',1, 'idx_end',N, 'snr_db',0);
        return;
    end
    
    % Rauschpegel schätzen (letzte 10%)
    noise_section = ir_abs(ceil(N*0.9):end);
    if isempty(noise_section), noise_section = ir_abs(end); end
    
    mu_noise = mean(noise_section);
    std_noise = std(noise_section);
    
    % Schwellwert für Ende (6 Sigma oder min. -50dB)
    threshold_end = max(mu_noise + 6*std_noise, max_amp * 0.003); 
    
    % Glättung für Hüllkurve
    window_size = 1000;
    if N > window_size
        env = movmean(ir_abs, window_size);
    else
        env = ir_abs;
    end
    
    % Ende finden
    [~, idx_peak] = max(env);
    min_silence_samples = 10000; 
    
    if idx_peak < N
        post_peak_env = env(idx_peak:end);
        local_max_future = movmax(post_peak_env, [0, min_silence_samples]);
        
        % Erster Punkt, ab dem Signal dauerhaft unter Schwelle bleibt
        idx_silence_start = find(local_max_future < threshold_end, 1, 'first');
        
        if ~isempty(idx_silence_start)
            idx_end = idx_peak + idx_silence_start - 1;
        else
            idx_end = find(env > threshold_end, 1, 'last');
            if isempty(idx_end), idx_end = N; end
        end
    else
        idx_end = N;
    end
    
    % Puffer am Ende
    idx_end = min(N, idx_end + 5000);
    
    % Start finden (1% Schwelle)
    threshold_start = max_amp * 0.01;
    idx_start = find(ir_abs > threshold_start, 1, 'first');
    
    if isempty(idx_start)
        idx_start = 1; 
    else
        % Pre-Roll
        idx_start = max(1, idx_start - 500);
    end
    
    if idx_end < idx_start, idx_end = N; end
    
    % Zuschnitt
    ir_trunc = ir(idx_start:idx_end);
    
    % Metriken
    metrics.idx_start = idx_start;
    metrics.idx_end = idx_end;
    metrics.original_len = N;
    metrics.snr_db = 20*log10(rms(ir_trunc) / (std_noise + eps));
    metrics.energy = sum(ir_trunc.^2);
    metrics.energy_total = sum(ir.^2);
    metrics.energy_share = metrics.energy / (metrics.energy_total + eps);
end