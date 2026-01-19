% Analyse der aktuellen Geometrie und Korrektur des Distance Offsets

% Aktuelle Geometrie laden
geo = get_geometry();

fprintf('=== AKTUELLE GEOMETRIE ===\n\n');
fprintf('Angenommene Quell-Position: (0, 0)\n\n');

% Zeige alle Positionen
fprintf('Position | x [m] | y [m] | Distanz [m]\n');
fprintf('---------|-------|-------|------------\n');
for i = 1:length(geo)
    fprintf('   %2d    | %5.2f | %5.2f |   %5.3f\n', ...
        geo(i).pos, geo(i).x, geo(i).y, geo(i).distance);
end

% Finde nächste Positionen
[min_dist, min_idx] = min([geo.distance]);
fprintf('\nNächste Position zur Quelle: Pos_%d bei (%.2f, %.2f) mit dist=%.3f m\n', ...
    geo(min_idx).pos, geo(min_idx).x, geo(min_idx).y, min_dist);

% Finde kleinste Koordinaten
min_x = min([geo.x]);
min_y = min([geo.y]);
fprintf('Kleinste Koordinaten: x=%.2f m, y=%.2f m\n', min_x, min_y);

% Visualisierung
fprintf('\n=== VISUALISIERUNG (von oben) ===\n\n');
fprintf('y ^\n');
fprintf('  |\n');

% 4x4 Grid
y_vals = unique([geo.y]);
y_vals = sort(y_vals, 'descend');

for yi = 1:length(y_vals)
    y = y_vals(yi);
    fprintf('%.1f ', y);

    % Finde alle Positionen bei dieser y-Koordinate
    x_vals = unique([geo.x]);
    x_vals = sort(x_vals);

    for xi = 1:length(x_vals)
        x = x_vals(xi);

        % Finde Position bei (x, y)
        idx = find(abs([geo.x] - x) < 0.01 & abs([geo.y] - y) < 0.01);
        if ~isempty(idx)
            fprintf(' [%2d]', geo(idx(1)).pos);
        else
            fprintf('     ');
        end
    end
    fprintf('\n');
end

fprintf('    ');
for xi = 1:length(x_vals)
    fprintf('  %.1f', x_vals(xi));
end
fprintf(' (x)\n');

fprintf('\n  QUELLE @ (0.0, 0.0)\n');

% Neue Geometrie mit Offset
fprintf('\n\n=== KORRIGIERTE GEOMETRIE (mit Offset) ===\n\n');
fprintf('Wenn Positionen "0.3m höher und 0.3m seitlich" starten:\n');
fprintf('→ Quelle sollte bei (-0.3, -0.3) sein\n\n');

source_x_new = -0.3;
source_y_new = -0.3;

fprintf('Position | x [m] | y [m] | Distanz ALT [m] | Distanz NEU [m] | Differenz [m]\n');
fprintf('---------|-------|-------|-----------------|-----------------|---------------\n');
for i = 1:length(geo)
    x = geo(i).x;
    y = geo(i).y;
    dist_old = geo(i).distance;
    dist_new = sqrt((x - source_x_new)^2 + (y - source_y_new)^2);
    diff = dist_new - dist_old;
    fprintf('   %2d    | %5.2f | %5.2f |     %5.3f       |     %5.3f       |   %+6.3f\n', ...
        geo(i).pos, x, y, dist_old, dist_new, diff);
end

% Statistik
dist_old = [geo.distance];
dist_new = zeros(size(dist_old));
for i = 1:length(geo)
    dist_new(i) = sqrt((geo(i).x - source_x_new)^2 + (geo(i).y - source_y_new)^2);
end

fprintf('\nStatistik:\n');
fprintf('  Min Distanz ALT: %.3f m (Pos_%d)\n', min(dist_old), geo(find(dist_old == min(dist_old), 1)).pos);
fprintf('  Min Distanz NEU: %.3f m (Pos_%d bei (%.2f, %.2f))\n', ...
    min(dist_new), geo(find(dist_new == min(dist_new), 1)).pos, ...
    geo(find(dist_new == min(dist_new), 1)).x, geo(find(dist_new == min(dist_new), 1)).y);
fprintf('  Max Distanz ALT: %.3f m\n', max(dist_old));
fprintf('  Max Distanz NEU: %.3f m\n', max(dist_new));
fprintf('  Mittlere Differenz: %+.3f m\n', mean(dist_new - dist_old));

fprintf('\n=== VISUALISIERUNG NEU (Quelle bei -0.3, -0.3) ===\n\n');
fprintf('y ^\n');
fprintf('  |\n');

for yi = 1:length(y_vals)
    y = y_vals(yi);
    fprintf('%.1f ', y);

    for xi = 1:length(x_vals)
        x = x_vals(xi);

        idx = find(abs([geo.x] - x) < 0.01 & abs([geo.y] - y) < 0.01);
        if ~isempty(idx)
            fprintf(' [%2d]', geo(idx(1)).pos);
        else
            fprintf('     ');
        end
    end
    fprintf('\n');
end

fprintf('    ');
for xi = 1:length(x_vals)
    fprintf('  %.1f', x_vals(xi));
end
fprintf(' (x)\n');

fprintf('\n-0.3  QUELLE\n\n');

fprintf('Mit dieser Korrektur:\n');
fprintf('  - Kleinste Position: Pos_9 bei (0.0, 0.3) → dist=%.3f m\n', ...
    sqrt((0.0 - source_x_new)^2 + (0.3 - source_y_new)^2));
fprintf('  - Oder Pos_13 bei (0.3, 0.0) → dist=%.3f m\n', ...
    sqrt((0.3 - source_x_new)^2 + (0.0 - source_y_new)^2));

fprintf('\n=== LUFTDÄMPFUNGS-EINFLUSS ===\n\n');
fprintf('Wenn die Distanzen korrigiert werden, ändert sich die Luftdämpfung:\n\n');

% Beispiel bei 63 kHz
freq = 63000; % Hz
T = 20; % °C
LF = 50; % %
dist_example = [0.3, 0.67, 1.0, 1.5];

fprintf('Beispiel bei 63 kHz, 20°C, 50%% LF:\n');
fprintf('Distanz [m] | Dämpfung [dB] | Korrekturfaktor [linear]\n');
fprintf('------------|---------------|-------------------------\n');

for d = dist_example
    if d > 0
        % Vereinfachte Berechnung (realistischer Wert für 63 kHz)
        alpha = 1.6; % dB/m bei 63 kHz, 20°C, 50%
        A_dB = alpha * d;
        A_lin = 10^(A_dB/20);
        fprintf('   %5.2f    |    %6.2f     |       %6.3f\n', d, A_dB, A_lin);
    end
end

fprintf('\n→ Wenn Distanzen größer werden (z.B. 0.3→0.67 m), wird mehr Korrektur angewendet!\n');
fprintf('→ Das könnte POSITIVE dBFS-Werte erklären (Über-Korrektur bei kleinen Distanzen)\n');

fprintf('\n=== EMPFEHLUNG ===\n\n');
fprintf('Soll die Quell-Position von (0, 0) auf (-0.3, -0.3) geändert werden?\n');
fprintf('JA, wenn: Die Positionen tatsächlich 0.3m seitlich UND höher als die Quelle starten\n');
fprintf('NEIN, wenn: Die aktuelle Geometrie korrekt ist\n');
fprintf('\nBitte prüfen Sie die Messung-Setup-Dokumentation oder Fotos!\n');
