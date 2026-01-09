function gridData = calc_heatmap_grid(dataMap, t_ms, fs, FS_global_ref)
    % Erzeugt 4x4 Grid für Heatmap-Darstellung
    gridData = NaN(4, 4);
    win_samp = round(5e-3 * fs); % 5ms Fenster
    idx_start = round(t_ms/1000 * fs) + 1;
    
    % Lambda für RMS-Abruf
    get_val = @(k) get_rms_db(dataMap, k, idx_start, win_samp, FS_global_ref);
    
    % Grid befüllen
    for c=1:4, gridData(1,c) = get_val(num2str(c)); end
    
    for c=1:4, gridData(2,c) = get_val(num2str(c+4)); end
    
    for c=1:4, gridData(3,c) = get_val(num2str(c+8)); end
    
    gridData(4,1) = get_val('Q1');
    gridData(4,2) = get_val('13');
    gridData(4,3) = get_val('14');
    gridData(4,4) = get_val('15');
end

function val = get_rms_db(dataMap, key, idx_start, win_samp, FS_global_ref)
    val = NaN;
    if isKey(dataMap, key)
        ir = dataMap(key);
        if ~isempty(ir)
            % Indizes berechnen
            idx_end = idx_start + win_samp - 1;
            eff_start = max(1, idx_start);
            eff_end = min(length(ir), idx_end);
            
            if eff_start <= eff_end
                seg = ir(eff_start:eff_end);
                % RMS im Fenster
                rms_val = sqrt(sum(seg.^2) / win_samp);
                val = 20*log10((rms_val + eps) / FS_global_ref);
            else
                val = -100;
            end
        else
            val = -100;
        end
    end
end