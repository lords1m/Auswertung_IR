function [t60_vals, f_center] = calc_rt60_spectrum(ir, fs, T, LF)
    % Berechnet T60-Werte in Terzbändern (4k - 63k)
    f_center = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
    
    % Exakte Frequenzen (Basis 10) für Filterdesign
    f_exact = 1000 * 10.^((6:18)/10);
    
    % Luftdämpfungskoeffizienten berechnen (für T60 Korrektur)
    if nargin < 3, T = 20; end
    if nargin < 4, LF = 50; end
    
    % Wir nutzen airabsorb mit s=100, um alpha (dB/m * 100 / 100 -> dB/m?) zu prüfen.
    % User Code: A_dB = alpha * s/100. 
    % Wir brauchen alpha in dB/m für T60 Formel.
    % Wenn wir s=100 setzen, ist A_dB = alpha.
    [A_dB_100m, ~, f_air] = airabsorb(101.325, fs, length(ir), T, LF, 100);
    
    t60_vals = NaN(size(f_center));
    
    for k = 1:length(f_exact)
        fc = f_exact(k);
        % Terzband-Grenzen
        fl = fc * 10^(-1/20); % Konsistent mit calc_terz_spectrum (Basis 10)
        fu = fc * 10^(1/20);
        
        if fu >= fs/2, continue; end
        
        try
            % Bandpass (Butterworth 4. Ordnung)
            [b, a] = butter(4, [fl fu]/(fs/2), 'bandpass');
            filt_ir = filtfilt(b, a, ir);
            
            % EDC
            edc_db = calc_edc(filt_ir);
            
            % T30 Auswertung (-5 dB bis -35 dB)
            idx_start = find(edc_db <= -5, 1, 'first');
            
            if ~isempty(idx_start)
                % Suche -35 dB Punkt
                idx_end_rel = find(edc_db(idx_start:end) <= -35, 1, 'first');
                
                if ~isempty(idx_end_rel)
                    idx_end = idx_start + idx_end_rel - 1;
                    
                % Regression
                y_segment = edc_db(idx_start:idx_end);
                x_segment = (0:length(y_segment)-1)' / fs; 
                
                if length(y_segment) > 5
                    p = polyfit(x_segment, y_segment, 1);
                    slope = p(1);
                    
                    if slope < 0
                        T_meas = -60 / slope;
                        
                        % T60 Korrektur: 1/T_room = 1/T_meas - 1/T_air
                        % T_air = 55.3 / (c * alpha_metric)
                        % alpha_metric [dB/m].
                        % Aus airabsorb(s=100): A_dB = alpha_code * 100/100 = alpha_code.
                        % Wir nehmen an, alpha_code ist die Dämpfung.
                        % Interpolieren auf Mittenfrequenz
                        idx_f = find(f_air >= fc, 1);
                        if isempty(idx_f), idx_f = length(f_air); end
                        alpha_val = A_dB_100m(idx_f); % Das ist alpha aus dem Code
                        
                        % Achtung: Der User-Code berechnet alpha. A_dB = alpha * s/100.
                        % Wenn s=100, A_dB = alpha.
                        % Ist alpha in dB/m? Die Formel 8.686*f^2... ist typisch für dB/m (ISO 9613).
                        % Aber der User teilt durch 100. Das deutet darauf hin, dass er s in m übergibt, 
                        % aber alpha vielleicht für 100m skaliert ist?
                        % Oder er will einfach alpha * s (Dämpfung über Strecke), und der Faktor 1/100 ist Teil seiner Formel?
                        % Wir nutzen den Wert so, wie er aus der Funktion kommt für 1m.
                        % A_dB(1m) = alpha * 1/100.
                        % Dämpfung m [dB/m] = A_dB(1m).
                        
                        m_air = alpha_val / 100; % Dämpfung pro Meter
                        
                        c = 343;
                        if m_air > 0
                            % Für Dämpfung in dB/m ist die Konstante 60 (nicht 55.3)
                            T_air = 60.0 / (c * m_air);
                            
                            % Korrektur anwenden (nur wenn T_meas < T_air)
                            if T_meas < T_air
                                t60_vals(k) = (T_meas * T_air) / (T_air - T_meas);
                            else
                                t60_vals(k) = T_meas; % Kann nicht korrigiert werden (Messfehler oder extrem)
                            end
                        else
                            t60_vals(k) = T_meas;
                        end
                    end
                end
                end
            end
        catch
        end
    end
end