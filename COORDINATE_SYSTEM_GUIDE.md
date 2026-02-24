# Koordinatensystem-Anleitung für get_geometry.m

Erstellt: 2026-01-19

##  Zweck

Diese Anleitung erklärt, wie Sie die Koordinaten in `get_geometry.m` an Ihr **tatsächliches Messsetup** anpassen.


##  Koordinatensystem

### Achsen-Definition

```
y ^  (oben)
  |
  |
  |
  +---------> x  (rechts)
(0,0)
```

- **x-Achse**: Horizontal (seitlich), nach rechts positiv
- **y-Achse**: Vertikal (höhe), nach oben positiv
- **Einheit**: Meter [m]

### Ursprung

Der Ursprung (0, 0) ist ein **Referenzpunkt**, nicht unbedingt die Quelle!

In Ihrem Setup:
- **Quelle bei**: (-0.3, -0.3)
- **Erste Receiver-Position**: (0, 0.3) oder (0.3, 0)


##  coords Array Struktur

### Format

```matlab
coords = [
    Position_Nr,  x_Koordinate,  y_Koordinate;
    Position_Nr,  x_Koordinate,  y_Koordinate;
    ...
];
```

### Aktuelles Setup

```matlab
coords = [
    % Position,  x [m],  y [m]
    1,          0.0,     1.2;
    2,          0.3,     1.2;
    3,          0.6,     1.2;
    4,          1.2,     1.2;
    5,          0.0,     0.6;
    6,          0.3,     0.6;
    7,          0.6,     0.6;
    8,          1.2,     0.6;
    9,          0.0,     0.3;
    10,         0.3,     0.3;
    11,         0.6,     0.3;
    12,         1.2,     0.3;
    13,         0.3,     0.0;
    14,         0.6,     0.0;
    15,         1.2,     0.0
];
```

**Interpretation:**
- Position 1: 0.0m rechts, 1.2m oben vom Ursprung
- Position 10: 0.3m rechts, 0.3m oben vom Ursprung
- Position 15: 1.2m rechts, 0.0m oben (auf x-Achse)


## ️ Wie erstelle ich Koordinaten für mein Setup?

### Methode 1: Von physischen Messungen

#### Schritt 1: Wählen Sie einen Referenzpunkt

**Empfehlung:** Wählen Sie die **Quelle** als Referenzpunkt (Ursprung)

Beispiel:
- Quelle = (0, 0)
- Alle anderen Positionen relativ zur Quelle

#### Schritt 2: Messen Sie die Positionen

**Ausrüstung:**
- Maßband / Laser-Entfernungsmesser
- Messprotokoll

**Vorgehen:**
1. Markieren Sie die Quelle
2. Für jede Receiver-Position:
   - Messen Sie Abstand in x-Richtung (seitlich)
   - Messen Sie Abstand in y-Richtung (Höhe/Tiefe)
   - Notieren Sie: Position_Nr, x, y

**Beispiel-Messprotokoll:**

| Position | x [m] | y [m] | Notizen                    |
|----------|-------|-------|----------------------------|
| 1        | 0.3   | 1.5   | Ecke oben links            |
| 2        | 0.6   | 1.5   | Nächste Position rechts    |
| 3        | 0.9   | 1.5   | Noch weiter rechts         |
| ...      | ...   | ...   | ...                        |

#### Schritt 3: In MATLAB übertragen

```matlab
coords = [
    1, 0.3, 1.5;
    2, 0.6, 1.5;
    3, 0.9, 1.5;
    % ... weitere Positionen
];
```


### Methode 2: Von einem Raster-Setup

#### Typisches Setup: Gleichmäßiges Grid

**Parameter:**
- Anzahl Reihen: 4
- Anzahl Spalten: 4
- Abstand zwischen Positionen: 0.3m
- Start-Position: (0.3, 0.3) relativ zur Quelle

**Erzeugung:**

```matlab
% Parameter
n_rows = 4;
n_cols = 4;
spacing = 0.3;  % m
start_x = 0.3;  % m
start_y = 0.3;  % m

% Erzeuge Grid
coords = [];
pos_nr = 1;

for row = 1:n_rows
    for col = 1:n_cols
        % Berechne Position
        % WICHTIG: y steigt von unten nach oben!
        x = start_x + (col - 1) * spacing;
        y = start_y + (n_rows - row) * spacing;  % Invertiert für oben→unten

        coords = [coords; pos_nr, x, y];
        pos_nr = pos_nr + 1;
    end
end

% Zeige Ergebnis
disp(coords);
```

**Ausgabe:**
```
Position | x [m] | y [m]
---------|-------|-------
    1    | 0.3   | 1.2
    2    | 0.6   | 1.2
    3    | 0.9   | 1.2
    4    | 1.2   | 1.2
    5    | 0.3   | 0.9
    ...
```


### Methode 3: Von bestehenden Positionen anpassen

#### Ihr aktuelles Setup (mit Offset):

Sie haben gesagt: **"Positionen starten 0.3m seitlich und 0.3m höher als die Quelle"**

**Original coords** (Ursprung bei kleinster Position):
```matlab
coords = [
    1, 0, 1.2;
    ...
    9, 0, 0.3;
    13, 0.3, 0;
];
```

**Interpretation:**
- Kleinste x: 0
- Kleinste y: 0
- → Ursprung bei kleinster Position

**Problem:**
- Quelle ist NICHT bei der kleinsten Position
- Quelle ist 0.3m links und 0.3m unterhalb

**Lösung:**
- Option A: Koordinaten verschieben (alle +0.3)
- Option B: Quelle verschieben zu (-0.3, -0.3) ← **Gewählt!**

#### Option A: Koordinaten verschieben

```matlab
% Original
coords_old = [
    1, 0.0, 1.2;
    9, 0.0, 0.3;
    13, 0.3, 0.0;
];

% Shift: Alle Koordinaten um (0.3, 0.3) verschieben
shift_x = 0.3;
shift_y = 0.3;

coords_new = coords_old;
coords_new(:, 2) = coords_new(:, 2) + shift_x;  % x-Spalte
coords_new(:, 3) = coords_new(:, 3) + shift_y;  % y-Spalte

% Ergebnis
% coords_new = [
%     1, 0.3, 1.5;
%     9, 0.3, 0.6;
%     13, 0.6, 0.3;
% ];

% Quelle bleibt bei (0, 0)
source_x = 0;
source_y = 0;
```

**Distanzen bleiben GLEICH!**

#### Option B: Quelle verschieben (← Gewählt)

```matlab
% Koordinaten bleiben
coords = [
    1, 0.0, 1.2;
    9, 0.0, 0.3;
    13, 0.3, 0.0;
];

% Quelle verschieben
source_x = -0.3;
source_y = -0.3;
```

**Distanzen ÄNDERN sich!**

**Beispiel:**
- Position 9: (0, 0.3)
- Quelle: (-0.3, -0.3)
- Distanz: sqrt((0 - (-0.3))² + (0.3 - (-0.3))²) = sqrt(0.3² + 0.6²) = 0.671m


##  Distanz-Berechnung

### Formel

```matlab
distance = sqrt((x_receiver - x_source)^2 + (y_receiver - y_source)^2)
```

**Pythagoras:** Euklidische Distanz in 2D

### Beispiele

#### Fall 1: Quelle bei (0, 0), Receiver bei (0.3, 0.4)

```
distance = sqrt((0.3 - 0)² + (0.4 - 0)²)
         = sqrt(0.09 + 0.16)
         = sqrt(0.25)
         = 0.5 m
```

#### Fall 2: Quelle bei (-0.3, -0.3), Receiver bei (0.3, 0.3)

```
distance = sqrt((0.3 - (-0.3))² + (0.3 - (-0.3))²)
         = sqrt(0.6² + 0.6²)
         = sqrt(0.36 + 0.36)
         = sqrt(0.72)
         = 0.849 m
```

#### Fall 3: Quelle bei (1, 1), Receiver bei (1, 2)

```
distance = sqrt((1 - 1)² + (2 - 1)²)
         = sqrt(0 + 1)
         = 1.0 m
```

→ Nur vertikaler Abstand!


##  Position der Quelle festlegen

### Variante 1: Quelle im Ursprung (einfach)

```matlab
source_x = 0;
source_y = 0;
```

**Koordinaten:**
- Alle Positionen sind **absolut** relativ zur Quelle
- Beispiel: Receiver bei (0.5, 0.8) ist 0.5m rechts und 0.8m oben der Quelle

**Vorteil:** Intuitiv, einfache Koordinaten


### Variante 2: Quelle an beliebiger Position

```matlab
source_x = -0.3;
source_y = -0.3;
```

**Koordinaten:**
- Positionen sind relativ zum Ursprung (0, 0)
- Quelle ist bei (-0.3, -0.3)
- Receiver bei (0, 0.3) ist 0.671m von Quelle entfernt

**Vorteil:** Flexibel, passt zu bestehendem Setup


### Variante 3: Quelle in der Mitte

```matlab
% Berechne Zentrum des Grids
x_center = mean(coords(:, 2));  % Mittlere x-Koordinate
y_center = mean(coords(:, 3));  % Mittlere y-Koordinate

source_x = x_center;
source_y = y_center;
```

**Vorteil:** Symmetrisch, für zentrale Quelle


## ️ Praktisches Beispiel: Ihr aktuelles Setup

### Gegebene Information

> "Die Messpositionen starten 0.3m seitlich und 0.3m höher als die Quelle"

### Interpretation

**Physisches Setup:**
```
         Receiver Grid
         ┌───┬───┬───┬───┐
         │ 1 │ 2 │ 3 │ 4 │  ← Reihe 1 (oben)
         ├───┼───┼───┼───┤
         │ 5 │ 6 │ 7 │ 8 │  ← Reihe 2
         ├───┼───┼───┼───┤
         │ 9 │10 │11 │12 │  ← Reihe 3
         ├───┼───┼───┼───┤
         │   │13 │14 │15 │  ← Reihe 4 (unten)
         └───┴───┴───┴───┘
            ^
            |
            Quelle (links-unten vom Grid)
```

**Koordinaten:**
- **Quelle**: Links-unten von Position 9
- **Position 9**: (0, 0.3) - kleinste Position oben
- **Position 13**: (0.3, 0) - kleinste Position rechts

**Wenn "0.3m seitlich und 0.3m höher":**
- Quelle ist bei: (-0.3, -0.3)
- Position 9 ist: 0.3m rechts, 0.6m oben → dist = 0.671m
- Position 13 ist: 0.6m rechts, 0.3m oben → dist = 0.671m

**Korrekte get_geometry.m:**
```matlab
coords = [
    1, 0.0, 1.2; 2, 0.3, 1.2; 3, 0.6, 1.2; 4, 1.2, 1.2;
    5, 0.0, 0.6; 6, 0.3, 0.6; 7, 0.6, 0.6; 8, 1.2, 0.6;
    9, 0.0, 0.3; 10, 0.3, 0.3; 11, 0.6, 0.3; 12, 1.2, 0.3;
    13, 0.3, 0.0; 14, 0.6, 0.0; 15, 1.2, 0.0
];

source_x = -0.3;  % 0.3m links von kleinster x-Koordinate
source_y = -0.3;  % 0.3m unter kleinster y-Koordinate
```


##  Checkliste: Koordinaten überprüfen

### 1. Physisches Setup dokumentieren

- [ ] Foto/Skizze des Messaufbaus erstellt?
- [ ] Quelle markiert?
- [ ] Alle Receiver-Positionen markiert (1-15)?
- [ ] Maßband / Messinstrument vorhanden?

### 2. Messungen durchführen

- [ ] Referenzpunkt gewählt (Quelle oder Ursprung)?
- [ ] Für jede Position: x-Koordinate gemessen?
- [ ] Für jede Position: y-Koordinate gemessen?
- [ ] Messungen in Tabelle eingetragen?

### 3. In MATLAB übertragen

- [ ] coords Array erstellt/angepasst?
- [ ] Position-Nummern korrekt (1-15)?
- [ ] Koordinaten in Metern [m]?
- [ ] source_x, source_y definiert?

### 4. Überprüfung

```matlab
% Führen Sie aus:
geo = get_geometry();

% Prüfen Sie:
fprintf('Anzahl Positionen: %d (erwartet: 15)\n', length(geo));
fprintf('Min Distanz: %.3f m\n', min([geo.distance]));
fprintf('Max Distanz: %.3f m\n', max([geo.distance]));
fprintf('Mittel Distanz: %.3f m\n', mean([geo.distance]));

% Visualisierung
figure;
scatter([geo.x], [geo.y], 100, 'filled');
hold on;
plot(source_x, source_y, 'r*', 'MarkerSize', 20);
for i = 1:length(geo)
    text(geo(i).x + 0.02, geo(i).y + 0.02, sprintf('%d', geo(i).pos));
end
xlabel('x [m]');
ylabel('y [m]');
title('Receiver-Positionen und Quelle');
legend('Receiver', 'Quelle');
grid on;
axis equal;
```

**Erwartung:**
- 15 Positionen im Plot
- Quelle (roter Stern) an der richtigen Position
- Abstände visuell plausibel


##  Häufige Fehler

### Fehler 1: Vertauschte Achsen

**Problem:**
```matlab
coords = [
    1, 1.2, 0.0;  % FALSCH: x und y vertauscht
```

**Lösung:**
```matlab
coords = [
    1, 0.0, 1.2;  % RICHTIG: [Position, x, y]
```


### Fehler 2: Einheiten falsch

**Problem:**
```matlab
coords = [
    1, 30, 120;  % FALSCH: Zentimeter statt Meter
```

**Lösung:**
```matlab
coords = [
    1, 0.30, 1.20;  % RICHTIG: Meter
```


### Fehler 3: Position-Nummern nicht eindeutig

**Problem:**
```matlab
coords = [
    1, 0.0, 1.2;
    1, 0.3, 1.2;  % FALSCH: Position 1 zweimal!
```

**Lösung:**
```matlab
coords = [
    1, 0.0, 1.2;
    2, 0.3, 1.2;  % RICHTIG: Eindeutige Nummern
```


### Fehler 4: Quelle falsch positioniert

**Problem:**
```matlab
source_x = 1.0;
source_y = 1.0;
% Aber alle Receiver sind bei x<1 und y<1 → Negative Distanzen!
```

**Lösung:**
```matlab
% Quelle muss links-unten (oder in der Mitte) sein
source_x = min(coords(:, 2)) - 0.3;  % Links von kleinster x-Position
source_y = min(coords(:, 3)) - 0.3;  % Unter kleinster y-Position
```


##  Zusammenfassung

### Koordinaten erstellen:

1. **Wählen** Sie einen Referenzpunkt (Quelle oder Ursprung)
2. **Messen** Sie x und y für jede Position
3. **Übertragen** Sie in das coords Array
4. **Definieren** Sie source_x, source_y
5. **Überprüfen** Sie mit Visualisierung

### Wichtige Regeln:

 **Einheit:** Immer Meter [m]
 **Format:** [Position_Nr, x, y]
 **Achsen:** x = seitlich, y = höhe
 **Distanz:** Wird automatisch berechnet
 **Eindeutig:** Jede Position-Nr nur einmal


*Erstellt: 2026-01-19*
*Für: Anpassung von get_geometry.m an tatsächliches Messsetup*
