function edc_db = calc_edc(ir)
    % Berechnet Energy Decay Curve (Schroeder Integration)
    E = cumsum(ir(end:-1:1).^2);
    E = E(end:-1:1);
    
    % Normierung
    max_E = max(E);
    if max_E == 0
        edc_db = ones(size(ir)) * -100;
    else
        edc_db = 10*log10(E / max_E + eps);
    end
end