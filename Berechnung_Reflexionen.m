%% Berechnung_Wandreflexionen.m
% Berechnet die Laufzeiten der 1. bis 7. Wandreflexion für eine Messposition.
%
% Geometrie:
% - Quelle bei (0,0,0) [x, y, z] -> [Längs, Höhe, Breite]
% - Wände bei Breite z = +/- 0.75 m (Abstand 1.5 m)
% - Messpositionen definiert durch x (Längs) und y (Höhe), z=0 (mittig)

clear; clc;
addpath('functions');

%% 1. Konfiguration
c = 343.2; % Schallgeschwindigkeit bei 20°C [m/s]
wall_dist = 0.70; % Abstand zur Wand [m]
width = 2 * wall_dist; % Breite der Schlucht [m]

% Zu analysierende Position (Hier anpassen oder leer lassen für Auswahl)
target_pos_id = 14; 

%% 2. Positionen definieren
positions_info = get_geometry();

%% 3. Auswahl der Position
if isempty(target_pos_id)
    fprintf('Verfügbare Positionen:\n');
    for i = 1:length(positions_info)
        fprintf('  Pos %d: x=%.1f m, y=%.1f m\n', positions_info(i).pos, positions_info(i).x, positions_info(i).y);
    end
    userInput = input('\nBitte Nummer der Messposition eingeben (z.B. 4): ', 's');
    target_pos_id = str2double(userInput);
end

% Position suchen
idx = find([positions_info.pos] == target_pos_id);
if isempty(idx)
    error('Position %d nicht gefunden.', target_pos_id);
end

P = positions_info(idx);
fprintf('\n--- Analyse für Position %d ---\n', P.pos);
fprintf('Koordinaten: x=%.2f m (Längs), y=%.2f m (Höhe)\n', P.x, P.y);
fprintf('Annahme: Empfänger mittig (z=0), Wände bei z=+/-%.2f m\n', wall_dist);
fprintf('Schallgeschwindigkeit: %.1f m/s\n', c);

%% 4. Berechnung der Laufzeiten

% Direktschall (Hypotenuse in x-y Ebene)
dist_dir = sqrt(P.x^2 + P.y^2);
t_dir = dist_dir / c;

fprintf('\nDirektschall:\n');
fprintf('  Weg: %.3f m\n', dist_dir);
fprintf('  Zeit: %.4f ms\n', t_dir * 1000);

% Reflexionen (Spiegelquellen-Methode)
% Die Spiegelquellen liegen seitlich versetzt um n * Breite
% n=1: 1. Reflexion (1x Breite Versatz)
% n=2: 2. Reflexion (2x Breite Versatz)
% n=3: 3. Reflexion (3x Breite Versatz)

fprintf('\nWandreflexionen (Seitlich):\n');
for n = 1:7
    % Lateraler Versatz der Spiegelquelle
    lat_offset = n * width; 
    
    % Gesamtdistanz (3D Pythagoras: x^2 + y^2 + z_mirror^2)
    dist_refl = sqrt(P.x^2 + P.y^2 + lat_offset^2);
    
    % Laufzeit
    t_refl = dist_refl / c;
    
    % Verzögerung zum Direktschall (Delay)
    dt = t_refl - t_dir;
    
    % Einfallswinkel zur Normalen
    angle_deg = atan2(dist_dir, lat_offset) * 180 / pi;
    
    fprintf('%d. Reflexion:\n', n);
    fprintf('  Weg:  %.3f m\n', dist_refl);
    fprintf('  Zeit: %.4f ms\n', t_refl * 1000);
    fprintf('  Delta: +%.4f ms (ggü. Direkt)\n', dt * 1000);
    fprintf('  Winkel: %.1f Grad (zur Normalen)\n', angle_deg);
end

fprintf('\nFertig.\n');
