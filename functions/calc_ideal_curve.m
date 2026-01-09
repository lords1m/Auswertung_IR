function [d_line, L_line] = calc_ideal_curve(dist, levels, energyMode)
    % Berechnet ideale Abfallkurve (1/r bzw. 1/r^2)
    if isempty(dist), d_line=[]; L_line=[]; return; end
    
    min_d = min(dist);
    % Referenzwert bei kleinster Distanz ermitteln
    ref_mask = abs(dist - min_d) < 0.05;
    L_ref = mean(levels(ref_mask));
    
    d_line = linspace(min_d, max(dist)*1.1, 100);
    
    if energyMode
        % Energie ~ 1/r^2
        L_line = L_ref * (min_d ./ d_line).^2;
    else
        % Pegel ~ -20*log10(r)
        L_line = L_ref - 20*log10(d_line / min_d);
    end
end