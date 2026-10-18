# Quellen

Woher die Daten des Addons stammen, wie sie belegt sind, was sie nicht können und wie es um die Rechte steht.

## Grundsatz

In die Daten kommt nur, was **im Spiel selbst erhoben** wurde, und das Addon nutzt dazu, was **der Client zur Laufzeit liefert** (entschieden am 15.10.2026). Daten von fremden Seiten und aus fremden Addons kommen nie ins Repo und nie ins Addon. Jede Angabe in `tools/eigene/` hat einen Beleg, und `tools/build-data.mjs` bricht ab, wenn einer fehlt.

Was niemand gefunden hat, steht nicht in den Daten. Das Addon zeigt solche Lücken als Aufgabe: „unentdeckt“ bei einem Rang ohne Lehrtier, „Fundort unbekannt“ bei einem Tier ohne Fundort, „Unbekanntes Tier (#ID)“ bei einem Tier ohne Namen.

## Vom Client zur Laufzeit

Namen und Beschreibungen der Fähigkeiten (`C_Spell`), Icons, Zonennamen (`C_Map.GetMapInfo`), Kartenbilder und erkundete Gebiete, 3D-Modelle (`SetCreature`) und Tooltips. Nichts davon liegt im Repo.

## Die Sammelwege

| Weg | Auslöser | Liefert | Modul | Datei in `tools/eigene/` |
| --- | --- | --- | --- | --- |
| **Erhebung** | Fenster „Wildtierausbildung“ oder Tierausbilder öffnen; Pet rufen | Fähigkeiten, Ränge, Zauber-IDs (aus dem Tooltip der Zeile), Pet-Stufe, angezeigte TP, Familien je Fähigkeit; vom Tierausbilder Jägerstufe und Preis; das Zauberbuch der Pets | `Core/Survey.lua` | `erhebung.json` |
| **Sichtung** | Tier mit Familie anvisieren, mit der Maus berühren oder mit Namensplakette sehen, bis etwa 28 m | NPC-ID, Name in Client-Sprache, Stufe, Einstufung, Familie und Familienname, Angriffstempo | `Core/Sightings.lua` | `sichtungen.json` |
| **Zähmen** | „Wildtier zähmen“ gelingt | Zauber-IDs und Angriffstempo, die das Tier mitbrachte; Stufe | `Core/Observe.lua` | `beobachtungen.json` |
| **Fundort** | Sichtung oder Zähmbeginn, Tier in etwa 10 m | Zelle eines Rasters von 2 % der Karte (50 × 50) an der Position des Spielers | `Core/Places.lua` | `zellen.json` |
| **Befund** | von Hand, nach Beobachtung im Spiel | ein Lehrtier bestätigt oder widerlegt, mit Quelle und Datum | – | `korrekturen.json` |
| **Fundort von Hand** | von Hand, im Spiel gesehen | Punkte in Prozent der Karte, mit Quelle und Datum | – | `fundorte.json` |

Dazu kommen von Hand `tiere.json`, `familien.json` und `faehigkeiten.json` (für Angaben, die keine Erhebung liefert, etwa das Angriffstempo); auch dort braucht jeder Eintrag einen `beleg`. `eigene-melder.json` hält die Kürzel der eigenen Charaktere.

`tools/import-observations.mjs` holt alles aus den SavedVariables, `tools/build-data.mjs` leitet daraus die Daten ab. Die Regeln dafür:

- **Fähigkeiten:** Ränge gleichen Namens bilden eine Fähigkeit. Bietet der Tierausbilder einen Rang an, lernt man sie dort, und jede Familie kann sie; sonst lernt man sie von Tieren, und sie gilt nur für die Familien, in deren Wildtierausbildung oder Zauberbuch sie stand. Was nicht gesehen wurde, wird nicht angenommen.
- **Angriffstempo:** Ein abweichendes Tempo ist eine passive Fähigkeit im Zauberbuch des Pets, mit eigener Zauber-ID und Namen („Schnellerer Angriff III“, „Langsamerer Angriff II“); normales Tempo (2,0 s) hat keine (im Spiel geprüft am 16.10.2026). Welcher Zauber welches Tempo bedeutet, zeigen die Zähmungen; Lehrtiere sind die Tiere, die ihn mitbrachten oder deren Tempo die Sichtung zeigte (das wilde Tier hat das Tempo, das es gezähmt hat). Für ein Tempo, dessen Zauber noch niemand gesehen hat, bleibt ein Eintrag „Angriffstempo“ mit Ersatz-ID.
- **Zauber aus dem Zauberbuch**, die in keiner Liste stehen, kommen dazu, ohne Pet-Stufe und TP: Das Pet kann sie, der Jäger noch nicht.
- **TP:** Die Wildtierausbildung zeigt beim aktuellen Rang des Pets 0, bei höheren den Preis abzüglich dessen, bei niedrigeren den vollen Preis. Daraus wird der Preis zurückgerechnet; was sich noch nicht rechnen lässt, bleibt leer.
- **Je Familie** gilt die zuletzt gelesene vollständige Wildtierausbildung. Sie ersetzt die vorige, damit eine falsche Liste (etwa beim Pet-Wechsel) nicht stehen bleibt.
- **Tiere:** aus eigenen Sichtungen sofort, aus fremden ab 3 Meldern, mit dem häufigsten Namen.
- **Fundorte:** Zellen werden als Punkt in der Zellmitte ausgeliefert: eigene sofort, fremde ab 3 Meldern (je Melder gespeichert seit #2). Ältere fremde Zellen ohne Melder bleiben im Spiel.

Das Teilen im Spiel (`Core/Comm.lua`) bringt die Erhebungen anderer Spieler mit; sie stehen in deren SavedVariables und kommen über den Import in die eigenen Daten, wenn sie die Regeln unten erfüllen.

## Belegung der Lehrtiere

| Stufe | Bedeutung | im Addon |
| --- | --- | --- |
| **belegt** | ein eigener Charakter hat es beim Zähmen gesehen, ein Befund „bestätigt“ liegt vor, oder 3 verschiedene andere Spieler haben es gesehen | immer gezeigt |
| **unsicher** | bisher von weniger als 3 anderen Spielern gemeldet | auf Wunsch, mit „?“ |
| **unbelegt** | nur geschätzt, noch nicht gesehen (Idee „Lehrtiere schätzen“, bisher gibt es keine) | auf Wunsch, mit „!“; der Schalter erscheint erst, wenn es Schätzungen gibt |
| **widerlegt** | eine Zähmung zeigte den Rang nicht, obwohl die Stufe reichte und kein höherer Rang da war | nie gezeigt, nicht ausgeliefert |

Eigene Zähmungen gelten als bewiesen, gesehen wie nicht gesehen, und gehen allem Fremden vor. Unter Fremden geht gesehen vor widerlegt. „3 verschiedene andere Spieler“ heißt seit #15: 3 verschiedene Melder, die zusammen über mindestens zwei verschiedene Absender kamen (`tools/eigene/melder-wege.json`); ein einzelner Absender genügt nie. Das gilt ebenso für Tiere aus Sichtungen und für fremde Fundort-Zellen. Melder ohne vermerkte Herkunft zählen wie bisher. Die Regel stützt sich darauf, dass die Fähigkeiten eines Tiers an seiner NPC-ID hängen und nur der Rang an der Stufe. Widersprechen sich Zähmungen derselben NPC-ID, meldet der Generator das – dann wackelt diese Annahme.

## Grenzen der Daten

- **Nur, was jemand gesehen hat.** Ein Rang, den kein Spieler gelernt oder gezähmt hat, fehlt; ebenso Tiere, die niemand angevisiert hat.
- **Namen in der Sprache, in der sie erhoben wurden.** Ein deutscher Client liefert deutsche Namen; englische kommen erst, wenn jemand mit englischem Client sammelt. Fähigkeits- und Zonennamen nennt der Client ohnehin in seiner Sprache.
- **Fundorte sind „hier ungefähr“.** Der Client nennt nur die Position des Spielers. Gezählt wird nur aus etwa 10 m Nähe, und das Raster rundet auf etwa 60–100 m. Wandernde Tiere ergeben eine Kette von Zellen.
- **TP** fehlen, solange kein Pet die Fähigkeit in der Wildtierausbildung zeigte, das den Rang darunter noch nicht hatte.
- **Pet-Stufen** der Ränge, die nur der Tierausbilder anbietet und die der Jäger noch nicht kennt, fehlen; bekannt ist dann nur die Jägerstufe.
- **Wildtierkunde** zeigt in Forever die Fähigkeiten eines Tiers nicht (an Blizzard gemeldet) und taugt deshalb nicht zum Sammeln.

## Rechte und Lizenz

Die MIT-Lizenz gilt für den Code und für die selbst erhobenen Daten (`tools/eigene/`, `Data/Data.lua`). Namen, Texte, Icons, Karten und Modelle gehören Blizzard Entertainment; das Addon holt sie zur Laufzeit vom Client. Die Aufstellung steht in [NOTICE.md](../../NOTICE.md).

Regeln, die daraus folgen:

- **Nichts aus fremden Addons**, weder Code noch Datentabellen, und keine Daten von fremden Seiten – auch nicht als Ausgangspunkt. Lieber eine Lösung, die nur nutzt, was der Client zur Laufzeit liefert, auch wenn sie weniger bequem ist.
- **Jede neue Quelle** – nur mit ausdrücklicher schriftlicher Erlaubnis ihres Rechteinhabers – wird hier und in NOTICE.md eingetragen, bevor ihre Daten hineinkommen.
- Wer Rechte an einem Inhalt hat und ihn entfernt haben möchte, meldet sich über ein Issue im Repository.
