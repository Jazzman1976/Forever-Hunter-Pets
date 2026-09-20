# Hunter-Pet-Fähigkeiten · WoW Forever

Eine lokale Nachschlageseite für alle Hunter-Pet-Fähigkeiten in WoW Forever. Sie zeigt zu jeder Fähigkeit die Ränge, die Pet-Familien und die zähmbaren Tiere, von denen man sie lernen kann. Die Namen sind deutsch.

## Öffnen
Öffne `index.html` per Doppelklick im Browser. Die Seite braucht keinen Server. Für die Symbole braucht sie Internet, weil sie von Wowhead geladen werden.

## Ansichten
Oben schaltest du zwischen vier Ansichten um:

- **Fähigkeiten** – die Nachschlageliste. Jeder Rang ist ein eigener, zugeklappter Eintrag mit Pet-Stufe, TP, Tierzahl und der Empfehlung; ein Klick zeigt die Lehrtiere mit Karte. Das Häkchen links pflegt deinen Lernstand.
- **Familien** – welche Familie welche Fähigkeiten hat. Mit gewählter Zone bleiben nur die Familien übrig, die dort Lehrtiere haben, und jede Karte nennt zusätzlich, was von deren Tieren genau hier zu lernen ist.
- **Gebiet** – *„Ich komme neu in dieses Gebiet, was nehme ich hier mit?“* Wähle deine Zone und deine Stufe. Die Seite gruppiert, was dort zähmbar ist, in **Neu für dich**, **Upgrade**, **Noch zu hoch** und **Hast du schon**, nennt je Eintrag das leichteste Tier mit Karte und listet zusätzlich die Tierausbilder und die Angriffstempi der Gegend.
- **Stufe** – *„Ich bin aufgestiegen, was ist jetzt dran?“* Trag deine Stufe ein. Du bekommst **Neu bei Stufe N**, **Noch offen für deine Stufe** und **Als Nächstes**, je Eintrag mit dem Ort, an dem du es am leichtesten holst. Setzt du zusätzlich eine Zone, zeigt die Liste nur, was du dort holen kannst; Fähigkeiten ohne Fundort (Pet-Lehrer, automatisch gelernte) rutschen in die eingeklappte Gruppe **Ortsunabhängig**, und steht der Tierausbilder in der gewählten Hauptstadt, erscheint seine Fähigkeit oben in der normalen Liste.

Suche, Familie und Zone wirken in allen vier Ansichten, „Alle Zonen“ hebt den Zonenfilter wieder auf. Das Stufenfeld gilt nur in **Gebiet** und **Stufe**. Was die Zone angeht, kennen die Daten nur **Lehrtiere**: Eine Familie kann in einer Zone leben, ohne dort etwas beizubringen – dann taucht sie unter dieser Zone nicht auf.

Das Stufenfeld gilt gleichzeitig als Jäger- und als Pet-Stufe: Es entscheidet, welche Ränge dein Pet wirken kann *und* welche Tiere du schon zähmen darfst. Ist dein Pet niedriger als du, trag die Pet-Stufe ein.

**Lernstand.** In **Fähigkeiten**, **Gebiet** und **Stufe** hakst du ab, was dein Pet schon kann. Ein Haken gilt auch für alle niedrigeren Ränge derselben Fähigkeit – du brauchst also nur den höchsten. Daraus entsteht die Trennung zwischen „neu“ und „Upgrade“. **Schon Gelerntes ausblenden** wirkt in allen vier Ansichten: In **Fähigkeiten** verschwinden die abgehakten Ränge, in **Familien** verschwindet eine Fähigkeit, sobald kein Rang mehr offen ist, und in der Zonenliste der Familienkarte fallen die erledigten Ränge weg. Der Lernstand liegt im `localStorage` deines Browsers, nicht in einer Datei: Er überlebt Neuladen, wandert aber nicht auf einen anderen Rechner mit und geht beim Leeren der Browserdaten verloren. Zurücksetzen kannst du ihn unten in der Liste.

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
