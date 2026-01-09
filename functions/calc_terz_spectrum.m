function [L_dBFS, L_sum, f_mitten] = calc_terz_spectrum(ir, fs, FS_global, dist, T, LF)
    % Wenn keine Eingaben: Debug-Modus (zeigt Bandgrenzen)
    if nargin == 0
        fprintf('--- Terzband-Grenzen Check (IEC 61260, Basis 10) ---\n');
        fprintf('%-10s %-10s %-10s %-10s\n', 'Nominal', 'Exact', 'Lower', 'Upper');
        
        indices = 6:18; % 4 kHz bis 63 kHz (relativ zu 1kHz)
        f_exact_debug = 1000 * 10.^(indices/10);
        f_nom_debug = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
        
        for k = 1:length(f_exact_debug)
            fc = f_exact_debug(k);
            fl = fc * 10^(-1/20);
            fu = fc * 10^(1/20);
            fprintf('%-10g %-10.1f %-10.1f %-10.1f\n', f_nom_debug(k), fc, fl, fu);
        end
        L_dBFS = []; L_sum = []; f_mitten = f_nom_debug;
        return;
    end

    if nargin < 3, FS_global = 1.0; end
    if nargin < 4, dist = 0; end
    if nargin < 5, T = 20; end
    if nargin < 6, LF = 50; end

    % 1. FFT
    N = length(ir);
    N_fft = 2^nextpow2(N); 
    X = fft(ir, N_fft);
    freqs = (0:N_fft-1) * (fs / N_fft);
    
    % --- Luftdämpfungskorrektur ---
    if dist > 0
        % Parameter: 101.325 kPa, T, LF
        [~, A_lin, ~] = airabsorb(101.325, fs, N_fft, T, LF, dist);
        
        % Korrektur anwenden (Multiplikation, da A_lin > 1 die Dämpfung repräsentiert)
        % Wir wollen den Verlust "rückgängig" machen.
        X = X .* A_lin(:); % A_lin muss Spaltenvektor sein
    end
    
    % Nur positive Frequenzen
    valid_idx = 1:floor(N_fft/2)+1;
    X = X(valid_idx);
    freqs = freqs(valid_idx);
    
    % Energie-Dichte (Parseval-Korrektur)
    X_mag_sq = (abs(X).^2) / N; 
    
    % 2. Terz-Definition (Standard-Mittenfrequenzen nach IEC 61260, 4 kHz - 63 kHz)
    f_mitten = [4000 5000 6300 8000 10000 12500 16000 20000 25000 31500 40000 50000 63000];
    
    % Exakte Frequenzen für die Berechnung der Grenzen (Basis 10)
    % Indizes relativ zu 1000 Hz (Index 0): 4k ist Index 6, 63k ist Index 18
    indices = 6:18;
    f_exact = 1000 * 10.^(indices/10);
                
    L_dBFS = NaN(size(f_mitten));
    energy_sum = 0;
    
    for k = 1:length(f_mitten)
        fc = f_exact(k);
        fl = fc * 10^(-1/20);
        fu = fc * 10^(1/20);
        
        if fl > fs/2, break; end
        
        idx = freqs >= fl & freqs <= fu;
        
        if any(idx)
            band_energy = sum(X_mag_sq(idx));
            energy_sum = energy_sum + band_energy;
            L_dBFS(k) = 10 * log10(band_energy / (FS_global^2 + eps));
        else
            L_dBFS(k) = -Inf;
        end
    end
    
    % 3. Summenpegel direkt aus der aufsummierten Energie berechnen
    if energy_sum <= 0
        L_sum = -Inf;
    else
        L_sum = 10 * log10(energy_sum / (FS_global^2 + eps));
    end
end