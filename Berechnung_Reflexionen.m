%% Berechnung_Wandreflexionen.m
% Berechnet die Laufzeiten der 1. bis 3. Wandreflexion für eine Messposition.
%
% Geometrie:
% - Quelle bei (0,0,0) [x, y, z] -> [Längs, Höhe, Breite]
% - Wände bei Breite z = +/- 0.75 m (Abstand 1.5 m)
% - Messpositionen definiert durch x (Längs) und y (Höhe), z=0 (mittig)

clear; clc;

%% 1. Konfiguration
c = 343.2; % Schallgeschwindigkeit bei 20°C [m/s]
wall_dist = 0.75; % Abstand zur Wand [m]
width = 2 * wall_dist; % Breite der Schlucht [m]

% Zu analysierende Position (Hier anpassen oder leer lassen für Auswahl)
target_pos_id = 15; 

%% 2. Positionen definieren (aus Darstellung_Pegel_ueber_Entfernung.m)
positions_info = struct();
% Reihe 1
positions_info(1).pos = 1;  positions_info(1).x = 0;   positions_info(1).y = 1.2;
positions_info(2).pos = 2;  positions_info(2).x = 0.3;   positions_info(2).y = 1.2;
positions_info(3).pos = 3;  positions_info(3).x = 0.6;   positions_info(3).y = 1.2;
positions_info(4).pos = 4;  positions_info(4).x = 1.2;   positions_info(4).y = 1.2;
% Reihe 2
positions_info(5).pos = 5;  positions_info(5).x = 0;   positions_info(5).y = 0.6;
positions_info(6).pos = 6;  positions_info(6).x = 0.3;   positions_info(6).y = 0.6;
positions_info(7).pos = 7;  positions_info(7).x = 0.6;   positions_info(7).y = 0.6;
positions_info(8).pos = 8;  positions_info(8).x = 1.2;   positions_info(8).y = 0.6;
% Reihe 3
positions_info(9).pos = 9;   positions_info(9).x = 0;   positions_info(9).y = 0.3;
positions_info(10).pos = 10; positions_info(10).x = 0.3;  positions_info(10).y = 0.3;
positions_info(11).pos = 11; positions_info(11).x = 0.6;  positions_info(11).y = 0.3;
positions_info(12).pos = 12; positions_info(12).x = 1.2;  positions_info(12).y = 0.3;
% Reihe 4
positions_info(13).pos = 13; positions_info(13).x = 0.3;  positions_info(13).y = 0;
positions_info(14).pos = 14; positions_info(14).x = 0.6;  positions_info(14).y = 0;
positions_info(15).pos = 15; positions_info(15).x = 1.2;  positions_info(15).y = 0;

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
for n = 1:3
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
