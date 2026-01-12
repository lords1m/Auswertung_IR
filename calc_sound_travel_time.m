% CALC_SOUND_TRAVEL_TIME Berechnet die Laufzeit von Schall über eine Strecke
%
% Dieses Skript berechnet die Laufzeit von Schallwellen über eine gegebene
% Strecke unter Berücksichtigung von Temperatur und Luftfeuchte.
%
% Hinweis:
%   Die Schallgeschwindigkeit hängt hauptsächlich von der Temperatur ab.
%   Der Einfluss der Luftfeuchte ist gering (< 0.5% bei normalen Bedingungen).
%   Die Frequenz hat KEINEN Einfluss auf die Schallgeschwindigkeit in Luft
%   (im hörbaren Bereich und bei Ultraschall bis ~100 kHz).
%
% Physikalischer Hintergrund:
%   Die Schallgeschwindigkeit in Luft wird approximiert durch:
%   c ≈ 331.3 + 0.606*T [m/s]  (für trockene Luft)
%
%   Genauere Formel nach Cramer (1993) berücksichtigt auch Luftfeuchte:
%   c = 331.3 * sqrt(T_kel/273.15) * (1 + 0.0016*h)
%   wobei h der Feuchteanteil ist.

% Author: Claude Code
% Date: 2026-01-11

clear; clc;

%% ========================================================================
%  EINGABEN - Hier anpassen!
%  ========================================================================

% Strecke(n) in Metern [m]
% Kann ein einzelner Wert oder ein Vektor sein
s = 0.2;              % Beispiel: 1.4 m
% s = [1, 2, 5, 10, 20];  % Beispiel: mehrere Strecken

% Temperatur in Grad Celsius [°C]
T = 20;               % Standard: 20°C

% Luftfeuchte in Prozent [%]
LF = 29;              % Standard: 50%

%% ========================================================================
%  Berechnung - Nicht ändern!
%  ========================================================================

if s < 0
    error('Strecke s muss positiv sein!');
end

%% Schallgeschwindigkeit berechnen
% Methode 1: Einfache Näherung (nur Temperaturabhängigkeit)
% c_simple = 331.3 + 0.606 * T;

% Methode 2: Genauere Berechnung nach Cramer (1993) mit Luftfeuchte
T_kel = 273.15 + T;
T_0 = 293.15;      % 20°C in Kelvin (Referenztemperatur)
T_01 = 273.16;     % Tripelpunkt Wasser
p_a = 101.325;     % Luftdruck in kPa (Standard)
p_r = 101.325;     % Referenzdruck

% Sättigungsdampfdruck berechnen (Antoine-Gleichung)
C = -6.8346 * (T_01 / T_kel)^1.261 + 4.6151;
psat_div_pr = 10^C;

% Feuchteanteil h berechnen
h = (LF/100) * psat_div_pr / (p_a/p_r);

% Schallgeschwindigkeit mit Feuchtekorrektur
c_sound = 331.3 * sqrt(T_kel / 273.15) * (1 + 0.0016 * h);

%% Laufzeit berechnen
% t = s / c  in Sekunden
% t_ms = t * 1000  in Millisekunden
t_ms = (s ./ c_sound) * 1000;

%% Ausgabe
fprintf('\n=== Schall-Laufzeit-Berechnung ===\n');
fprintf('Bedingungen:\n');
fprintf('  Temperatur:    %.1f °C\n', T);
fprintf('  Luftfeuchte:   %.1f %%\n', LF);
fprintf('  Luftdruck:     %.1f kPa\n', p_a);
fprintf('\nErgebnis:\n');
fprintf('  Schallgeschwindigkeit: %.2f m/s\n', c_sound);

if length(s) == 1
    fprintf('  Strecke:               %.2f m\n', s);
    fprintf('  Laufzeit:              %.3f ms\n', t_ms);
    fprintf('  Laufzeit:              %.6f s\n', t_ms/1000);
else
    fprintf('\nStrecke [m]    Laufzeit [ms]    Laufzeit [s]\n');
    fprintf('------------------------------------------------\n');
    for i = 1:length(s)
        fprintf('%10.2f     %12.3f     %11.6f\n', s(i), t_ms(i), t_ms(i)/1000);
    end
end

fprintf('\n--- Wichtiger Hinweis ---\n');
fprintf('Die Frequenz hat KEINEN Einfluss auf die Schallgeschwindigkeit in Luft!\n');
fprintf('Alle Frequenzen (4 kHz - 63 kHz) breiten sich mit der gleichen\n');
fprintf('Geschwindigkeit von %.2f m/s aus.\n', c_sound);