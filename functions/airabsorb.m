function [A_dB, A_lin, f] = airabsorb(p_a, fs, N, T, LF, s, exportFile)

T_kel = 273.15 + T;
T_0 = 293.15;
T_01 = 273.16;
p_r = 101.325;

f = (0:N-1)' * (fs/N);


% Sättigungsdampfdruck 
C = -6.8346 * (T_01 / T_kel)^1.261 + 4.6151;
psat_div_pr = 10^C;

% Feuchteanteil h 
h = (LF/100) * psat_div_pr / (p_a/p_r);

%  Relaxationsfrequenzen 
f_rO = (p_a/p_r) * (24 + 4.04e4*h*((0.02+h)/(0.391+h)));
f_rN = (p_a/p_r) * (T_kel/T_0)^(-0.5) * ...
       (9 + 280*h * exp(-4.170*((T_kel/T_0)^(-1/3)-1)));

%  Absorptionskoeffizient alpha
alpha = 8.686 .* f.^2 .* (1.84e-11*(p_a/p_r)^(-1)*(T_kel/T_0)^(0.5) + ...
    (T_kel/T_0)^(-2.5) .* ( ...
        0.01275 .* exp(-2239.1 ./ T_kel) ./ (f_rO + (f.^2 ./ f_rO)) + ...
        0.1068  .* exp(-3352.0 ./ T_kel) ./ (f_rN + (f.^2 ./ f_rN)) ...
    ) ...
);

A_dB = alpha * s/100;
A_lin = 10.^(A_dB/20);

if nargin > 6 && ~isempty(exportFile)
    T_out = table(f, A_dB, A_lin, 'VariableNames', {'Frequency_Hz', 'Attenuation_dB', 'Attenuation_Linear'});
    writetable(T_out, exportFile);
end

end