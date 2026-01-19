function pos_info = get_geometry()
    % Definiert Positionen im Raum (4x4 Raster)
    pos_info = struct('pos', {}, 'x', {}, 'y', {}, 'distance', {});

    % Koordinaten-Definition (Receiver-Positionen)
    coords = [
        1, 0, 1.2; 2, 0.3, 1.2; 3, 0.6, 1.2; 4, 1.2, 1.2;
        5, 0, 0.6; 6, 0.3, 0.6; 7, 0.6, 0.6; 8, 1.2, 0.6;
        9, 0, 0.3; 10, 0.3, 0.3; 11, 0.6, 0.3; 12, 1.2, 0.3;
        13, 0.3, 0; 14, 0.6, 0; 15, 1.2, 0
    ];

    % Quelle bei Ursprung
    % Kleinste Receiver-Positionen: Pos_9 bei (0, 0.3) und Pos_13 bei (0.3, 0)
    % → Minimale Distanz = 0.3m
    source_x = 0;
    source_y = 0;
    
    for i = 1:size(coords, 1)
        p = coords(i, 1);
        x = coords(i, 2);
        y = coords(i, 3);
        d = sqrt((x - source_x)^2 + (y - source_y)^2);
        
        pos_info(i).pos = p;
        pos_info(i).x = x;
        pos_info(i).y = y;
        pos_info(i).distance = d;
    end
end