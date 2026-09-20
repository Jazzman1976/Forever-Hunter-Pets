# Hunter-Pet-Fähigkeiten · WoW Forever

Eine lokale Nachschlageseite für alle Hunter-Pet-Fähigkeiten in WoW Forever. Sie zeigt zu jeder Fähigkeit die Ränge, die Pet-Familien und die zähmbaren Tiere, von denen man sie lernen kann. Die Namen sind deutsch.

## Öffnen
Öffne `index.html` per Doppelklick im Browser. Die Seite braucht keinen Server. Für die Symbole braucht sie Internet, weil sie von Wowhead geladen werden.

## Daten aktualisieren
```
node tools/fetch-data.mjs
```
- Das Skript liest die Daten von https://www.wowhead.com/forever/de/spells/pet-abilities/ und den einzelnen Zauberseiten und schreibt daraus `data.js`.
- Geladene Seiten landen in `tools/cache/`. Um wirklich neue Daten von Wowhead zu holen, lösche vorher diesen Ordner. Wowhead drosselt zu schnelle Abrufe, deshalb dauert ein kompletter Lauf ohne Cache etwa 30 Minuten.

## Quellen
1. **Wowhead Forever** (deutsch): Fähigkeiten, Ränge, Pet-Familien und die Tiere, die eine Fähigkeit nutzen.
2. **Wowhead-Kommentare** auf den Zauberseiten: rangweise Zähmlisten mit Trainingspunkten (vor allem von „hevgirl“, 2019) und die Tierausbilder in den Hauptstädten.
3. **Petopia Classic** (https://www.wow-petopia.com/classic/): Lehrtiere je Rang, Trainingspunkte, welche Fähigkeiten beim Tierausbilder zu lernen sind, und die Angriffstempi der Tiere. Damit werden Lücken mit Classic-Wissen gefüllt.

4. **Wowhead Classic**: Fundorte (Koordinaten) der Tiere aus `g_mapperData` auf den NPC-Seiten. Wowhead Forever hat noch keine Kartendaten. Die Zonenkarten (deutsch) lädt die Seite vom Wowhead-CDN.

Die Parser für 2 und 3 stehen in `tools/sources.mjs`.

Beim ersten Lauf ruft das Skript für jedes der rund 465 Tiere die Classic-Seite ab. Das dauert etwa 20 Minuten. Danach kommt alles aus dem Cache.

## Empfehlung
Die Seite schätzt zu jedem Tier den Aufwand (leicht/mittel/schwer) aus Einstufung (normal, Elite, rar), Instanz ja/nein, Anzahl der Fundorte, Tierstufe und der Frage, ob der Rang bestätigt ist. Je Rang steht das leichteste Tier oben und mit ★, oben in der Karte steht die Empfehlung für die Fähigkeit. Über die Fraktionsauswahl werden Startgebiete der Gegenfraktion abgewertet. Das ist eine Faustregel, keine Spielmechanik.

## Grenzen der Daten
- Wowhead Forever ordnet Tiere keinem Rang zu. Tiere, die nur dort vorkommen, sind auf der Seite mit ≈ markiert. Ihr Rang ist nach der Tierstufe geschätzt. Tiere mit P (Petopia) oder K (Kommentar) haben einen Rang aus der Quelle.
- Trainingspunkte, Tierausbilder und Classic-Ränge stammen aus WoW Classic und können in Forever abweichen.
- Für neue Forever-Fähigkeiten wie Prankenhieb, Zwicken, Sehnenriss, Zerstückeln, Wildes Verwunden und Meins! gibt es keine Lernquelle.

## Technik
Wie die Seite aufgebaut ist, wie `data.js` aussieht und woher jede einzelne Angabe stammt, steht in [TECHNIK.md](TECHNIK.md).
