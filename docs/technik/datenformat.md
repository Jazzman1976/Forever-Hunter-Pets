# Datenformat

Die Daten entstehen in drei Stufen:

```
tools/eigene/*.json  ──>  tools/build-data.mjs  ──>  tools/data.json  ──>  tools/build-addon.mjs  ──>  Data/Data.lua
```

`tools/eigene/` ist die einzige Datenquelle und wird gepflegt; `tools/data.json` und `Data/Data.lua` sind generiert und werden nicht von Hand bearbeitet. Woher die Angaben stammen, steht in [quellen.md](quellen.md).

## `tools/eigene/`

| Datei | Inhalt | woher |
| --- | --- | --- |
| `erhebung.json` | `raenge` (je Zauber-ID: Name je Sprache, Rang, Icon, `petStufe`, `jaegerStufe`, `preis` in Kupfer, `wildtierausbildung`, `tierausbilder`, `datum`), `listen` (je Familien-ID die letzte vollständige Wildtierausbildung: `zeilen` = Zauber-ID → „Status/angezeigte TP“), `familien` (Name je Sprache), `zauberbuch` (je Zauber-ID: Name, Rang, passiv, Familien der Pets) | Import aus `ForeverHunterPetsDB.survey` |
| `sichtungen.json` | `[{ npc, stufe, einstufung, familie, sprache, name, zeit, melder, tempo? }]`, je Tier, Stufe, Sprache und Melder einer | Import aus `ForeverHunterPetsDB.sights` |
| `beobachtungen.json` | `[{ npc, stufe, zauber: [IDs], tempo, zeit, melder }]`, eine je Zähmung | Import aus `ForeverHunterPetsDB.obs` |
| `zellen.json` | `{ npc: { uiMapID: "xyxy…" } }`, eigene Fundort-Zellen, zwei Zeichen je Zelle (Spalte, Zeile im Raster 50 × 50, Alphabet `0–9 A–Z a–n`) | Import aus `ForeverHunterPetsDB.loc` |
| `zellen-fremd.json` | `{ npc: { uiMapID: { melder: "xyxy…" } } }`, Fundort-Zellen anderer Spieler je Melder, Format wie `zellen.json`; ausgeliefert wird eine Zelle ab 3 Meldern oder mit einem eigenen Kürzel | Import aus `ForeverHunterPetsDB.locIn` (Einträge ohne Melder entfallen) |
| `eigene-melder.json` | Kürzel der eigenen Charaktere | Import aus `ForeverHunterPetsDB.myReps` |
| `korrekturen.json` | `[{ npc, name, ability, rank, zauber?, befund: bestätigt\|widerlegt, quelle, datum }]`; `zauber` ist die ID des Rangs und geht vor dem Namen | von Hand |
| `fundorte.json` | `[{ npc, name, map, punkte: [[x, y], …] in Prozent, quelle, datum }]` | von Hand |
| `faehigkeiten.json` | `[{ en?, de?, icon?, kind, source, speed?, families, ranks: [{ id, rank, level?, tp? }], beleg }]` für Angaben, die keine Erhebung liefert (etwa das Angriffstempo); geht vor der Erhebung | von Hand |
| `tiere.json`, `familien.json` | `{ ID: { de?, en?, …, beleg } }`; gehen vor Sichtung und Erhebung | von Hand |

Ein Melder ist ein Kürzel aus acht Hexziffern, der djb2-Hash des vollen Charakternamens; Namen werden nirgends gespeichert.

## `tools/data.json`

```js
{ generatedAt, families, beasts, coords, abilities }
```

| Feld | Inhalt |
| --- | --- |
| `families` | `{ ID: { de, en, icon } }` |
| `beasts` | `{ NPC-ID: { de, en, fam, min, max, cls } }`; `cls` ist die Einstufung: 0 normal, 1 Elite, 2 Rar-Elite, 3 Boss, 4 Rar |
| `coords` | `{ NPC-ID: { uiMapID: [x, y, x, y, …] } }` in Promille der Karte |
| `abilities[]` | `{ en, de, icon, kind, source, speed, families, ranks: [{ id, rank, level, tp }], teach: [{ id, rank, conf }] }` |

- `kind`: `general` (alle Familien), `family` (die in `families`), `trait` (Angriffstempo, `speed` in Sekunden): ein passiver Zauber aus dem Zauberbuch, dessen Tempo die Zähmungen zeigen; ist der Zauber für ein Tempo noch nicht gesehen, eine negative Ersatz-ID (etwa −150 für 1,5 s), für die das Addon den Client nicht fragt.
- `source`: `tame` (von einem Tier abschauen), `trainer` (Tierausbilder), `unknown`.
- `icon`: Datei-ID aus dem Spiel (Zahl) oder ein Dateiname unter `Interface\Icons\`; das Addon fragt ohnehin zuerst den Client.
- `teach.conf`: Belegung, 1 belegt, 2 unsicher, 3 unbelegt (geschätzt). Widerlegte Paare stehen nicht drin. Siehe [quellen.md](quellen.md#belegung-der-lehrtiere).

## `Data/Data.lua`

Dieselben Daten als Lua-Tabelle `ns.Data`, kompakt:

- `zones = { [uiMapID] = { map = uiMapID } }`: jede Karte, auf der ein Fundort liegt. Den Namen nennt der Client.
- `beasts[npc]` trägt zusätzlich `zones = { uiMapID, … }`; Felder ohne Wert fehlen.
- `coords[npc][uiMapID]` ist eine Zeichenkette mit sechs Ziffern je Punkt (x und y in Promille); das Addon packt sie erst aus, wenn eine Karte aufgeht.
- `teach = { { NPC-ID, Rang }, { NPC-ID, Rang, 2 } }`: das dritte Feld nur bei unsicher (2) oder unbelegt (3).
