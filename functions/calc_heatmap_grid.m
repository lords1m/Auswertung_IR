function gridData = calc_heatmap_grid(dataMap, t_ms, fs, FS_global_ref)
    % Erzeugt 4x4 Grid für Heatmap-Darstellung
    gridData = ones(4, 4) * -100; % Initialisiere mit Minimum statt NaN
    win_samp = round(5e-3 * fs); % 5ms Fenster
    idx_start = round(t_ms/1000 * fs) + 1;
    
    % Lambda für RMS-Abruf
    get_val = @(k) get_rms_db(dataMap, k, idx_start, win_samp, FS_global_ref);
    
    % Grid befüllen - Layout:
    % M1  M2  M3  M4
    % M5  M6  M7  M8
    % M9  M10 M11 M12
    % Q1  M13 M14 M15

    % Zeile 1: M1-M4 (Position 1-4)
    gridData(1,1) = get_val('1');
    gridData(1,2) = get_val('2');
    gridData(1,3) = get_val('3');
    gridData(1,4) = get_val('4');

    % Zeile 2: M5-M8 (Position 5-8)
    gridData(2,1) = get_val('5');
    gridData(2,2) = get_val('6');
    gridData(2,3) = get_val('7');
    gridData(2,4) = get_val('8');

    % Zeile 3: M9-M12 (Position 9-12)
    gridData(3,1) = get_val('9');
    gridData(3,2) = get_val('10');
    gridData(3,3) = get_val('11');
    gridData(3,4) = get_val('12');

    % Zeile 4: Q1, M13-M15 (Quelle + Position 13-15)
    gridData(4,1) = get_val('Q1');
    gridData(4,2) = get_val('13');
    gridData(4,3) = get_val('14');
    gridData(4,4) = get_val('15');
end

function val = get_rms_db(dataMap, key, idx_start, win_samp, FS_global_ref)
    val = -100; % Minimum statt NaN
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