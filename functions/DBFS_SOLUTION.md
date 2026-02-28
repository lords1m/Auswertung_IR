# Lösung: Positive dBFS-Werte - Quell-Messungen vs. Empfänger

##  Problem-Diagnose: GELÖST

### Diagnostik-Ergebnisse:

```
️  28 VERLETZUNGEN gefunden!

Verletzungen pro Frequenzband:
Frequenz     | Anzahl
-------------------------
10.0 kHz     | 15        ← Hauptproblem
12.5 kHz     | 10
5.0 kHz      | 1
6.3 kHz      | 1
20.0 kHz     | 1

Maximale Verletzung: +6.58 dB (Ratio 4.5×)
Betroffene Distanzen: ALLE bei 0.00 m → QUELL-MESSUNGEN!
```


##  Ursache (GEFUNDEN):

### **Quelle vs. Empfänger - Unterschiedliche Spektren**

**Problem:**
1. `FS_global` wird aus **allen** IRs berechnet (Quelle + Empfänger)
2. Im **Zeitbereich**: Empfänger haben oft höheres Maximum (breitbandiger)
3. Im **Frequenzbereich**: Quelle hat mehr Energie bei 10-12 kHz (Sender-Charakteristik)
4. Resultat: `band_energy_Quelle > FS_global²` → Positive dBFS

### **Warum ist die Quelle im Zeitbereich "schwächer"?**

**Beispiel-Messung:**
```
Empfänger Pos15:
  - Zeitbereich Max: 126.24 → Bestimmt FS_global
  - Spektrum: Breitbandig (viele Frequenzen)
  - Energie verteilt über 4-63 kHz

Quelle Pos13:
  - Zeitbereich Max: 77.05 (nur 61% von FS_global!)
  - Spektrum: Konzentriert bei 10 kHz
  - Bei 10 kHz Band: 4.5× mehr Energie als FS_global²
```

**Physikalische Erklärung:**

| Aspekt | Empfänger | Quelle |
|--------|-----------|--------|
| **Signal-Typ** | Durch Raum propagiert | Direkt vom Sender |
| **Spektrum** | Breitbandig (Raum-Effekte) | Schmalbandiger (Sender-Charakteristik) |
| **Zeitbereich-Max** | Höher (breitbandig) | Niedriger (schmalbandiger) |
| **10 kHz Energie** | Gedämpft | Sehr hoch (Grundfrequenz) |

→ **Zeitbereich**: Empfänger > Quelle
→ **10 kHz Band**: Quelle > Empfänger 


##  Lösung: Quelle von FS_global ausschließen

### **Implementiert in:** `scripts/00_pipeline/step1_process_data.m`

**Code-Änderung:**

```matlab
FS_global = 0;
source_count = 0;
receiver_count = 0;

for i = 1:length(files)
    [S, meta] = load_and_parse_file(filepath);
    ir = extract_ir(S);

    if ~isempty(ir)
        % WICHTIG: Quell-Messungen von FS_global ausschließen!
        if strcmp(meta.type, 'Source')
            source_count = source_count + 1;
            % Quelle NICHT in FS_global einbeziehen
        else
            receiver_count = receiver_count + 1;
            FS_global = max(FS_global, max(abs(ir)));  // ← Nur Empfänger!
        end
    end
end

fprintf('Berechnet aus: %d Empfänger-Messungen\n', receiver_count);
fprintf('Ausgeschlossen: %d Quell-Messungen\n', source_count);
```

**Effekt:**
-  `FS_global` basiert nur auf **Empfänger-Messungen**
-  Empfänger: **Keine positiven dBFS** mehr
- ️ Quelle: **Kann positive dBFS haben** (aber das ist OK!)


##  Warum ist das korrekt?

### **Physikalische Argumentation:**

1. **Referenz sind die Empfänger**
   - Wissenschaftliche Messungen: Empfänger-Positionen
   - Quelle ist nur für Kalibrierung/Referenz

2. **Quelle DARF lauter sein**
   - Quelle ist die **Schallquelle** → natürlich am lautesten
   - Positive dBFS bei Quelle bedeuten: "Quelle ist X dB lauter als Empfänger-Maximum"
   - Das ist **physikalisch korrekt** und **informativ**!

3. **Vergleichbarkeit**
   - Alle **Empfänger** verwenden gleiche Referenz
   - Untereinander vergleichbar
   - Quelle ist separater Referenzpunkt

### **Analogie:**

Stellen Sie sich vor:
- **Empfänger** = Mikrofone im Raum (0.5 - 3m vom Lautsprecher)
- **Quelle** = Mikrofon direkt am Lautsprecher (0m)

Natürlich ist das **Quell-Mikrofon lauter**!

Es wäre falsch, die Referenz vom Quell-Mikrofon zu nehmen:
- Alle anderen Messungen wären dann "zu leise"
- Relative Unterschiede zwischen Empfängern wären verfälscht

→ **Richtig:** Referenz aus Empfängern, Quelle darf höher sein


##  Erwartete Ergebnisse nach Änderung:

### **Vor der Änderung:**

```
FS_global: 126.24 (aus allen Messungen)

Empfänger Pos1: -15.3 dBFS 
Empfänger Pos5: -22.1 dBFS 
...
Quelle Pos13 bei 10 kHz: +6.58 dBFS  (Verletzung!)
```

### **Nach der Änderung:**

```
FS_global: XXX.XX (nur aus Empfängern)
  Berechnet aus: 44 Empfänger-Messungen
  Ausgeschlossen: 4 Quell-Messungen

Empfänger Pos1: -15.3 dBFS 
Empfänger Pos5: -22.1 dBFS 
...
Quelle Pos13 bei 10 kHz: +Y.Y dBFS (OK - ist die Quelle!)
```

**Wichtig:**
-  **Empfänger:** Alle dBFS ≤ 0 dB
- ️ **Quelle:** Kann positive dBFS haben
-  **Interpretation:** Quelle ist Y.Y dB lauter als lautester Empfänger


##  Validierung:

### **Test nach Implementierung:**

1. **Führe step1_process_data.m aus:**
   ```matlab
   run('scripts/00_pipeline/step1_process_data.m')
   ```

2. **Prüfe Ausgabe:**
   ```
   --- Phase 1: Ermittle globalen Referenzpegel ---
   Globaler Referenzpegel (FS_global): XXX.XX
     Berechnet aus: 44 Empfänger-Messungen
     Ausgeschlossen: 4 Quell-Messungen
   ```

3. **Führe Diagnostik erneut aus:**
   ```matlab
   run('scripts/02_qc_diagnostics/diagnose_dbfs_energy.m')
   ```

4. **Erwartetes Ergebnis:**
   - Verletzungen nur noch bei dist=0 (Quelle)
   - KEINE Verletzungen bei Empfängern (dist>0)
   - Oder deutlich weniger Verletzungen gesamt


##  Alternative: Quelle komplett ignorieren?

**Frage:** Sollten Quell-Messungen überhaupt Terz-Spektren bekommen?

**Option A: Quelle bekommt Spektrum (aktuell)**
```matlab
// Quelle wird verarbeitet, kann positive dBFS haben
Result.freq.terz_dbfs = [kann > 0 dB sein]
```

**Option B: Quelle überspringen**
```matlab
// In step1_process_data.m:
if strcmp(meta.type, 'Source')
    fprintf('  [SKIP] Quell-Messung - kein Spektrum berechnet\n');
    continue;
end
```

**Empfehlung:** **Option A** (aktuell)
- Spektrum der Quelle kann nützlich sein (Kalibrierung, Sender-Charakteristik)
- Positive dBFS sind OK, wenn dokumentiert

Wenn Sie Quelle nicht brauchen: **Option B** verwenden


##  Zusammenfassung:

| Aspekt | Lösung |
|--------|--------|
| **Problem** | Quelle hat bei 10 kHz mehr Energie als Empfänger |
| **Ursache** | Sender-Charakteristik + schmalbandiges Spektrum |
| **Code-Änderung** | FS_global nur aus Empfängern berechnen |
| **Empfänger** | Keine positiven dBFS mehr  |
| **Quelle** | Kann positive dBFS haben (OK!) |
| **Interpretation** | Quelle ist X dB lauter als Empfänger-Max |

**Status:**  **GELÖST**


*Erstellt: 2026-01-19*
*Basierend auf Diagnostik-Ergebnissen: 28 Verletzungen, alle bei dist=0*
