# Technischer Aufbau

Diese Datei beschreibt, wie die Seite gebaut ist und woher jede Angabe stammt.
Für die reine Benutzung reicht [README.md](README.md).

## 1. Überblick

Drei Teile, kein Build-Schritt, keine Abhängigkeiten. Node braucht man nur zum
Aktualisieren der Daten (Version 18 oder neuer, wegen `fetch`).

```
tools/fetch-data.mjs  ──lädt──>  tools/cache/*.html  ──baut──>  data.js  ──liest──>  index.html
 + tools/sources.mjs             (669 HTML-Dateien)            (window.PET_DATA)    (eine Datei, Vanilla JS)
```

- `tools/fetch-data.mjs` ist ein Scraper. Er läuft von Hand, nicht beim Öffnen der Seite.
- `tools/cache/` hält jede heruntergeladene Seite. Solange der Cache steht, läuft ein
  erneuter Durchlauf in Sekunden statt in einer halben Stunde.
- `data.js` ist das Ergebnis: eine einzige generierte Datei (~700 KB) mit allem, was die Seite zeigt.
- `index.html` ist die Anwendung. Sie braucht keinen Server, `file://` genügt.

Offline ist alles bis auf drei Dinge, die zur Laufzeit aus dem Netz kommen:
die Fähigkeiten-Icons (`wow.zamimg.com/images/wow/icons/medium/…`), die Zonenkarten
(`wow.zamimg.com/images/wow/classic/maps/dede/…`) und die Links nach Wowhead.
Ohne Internet bleibt die Seite benutzbar, nur ohne Bilder.

Aktueller Stand der Daten: 39 Fähigkeiten, 158 Ränge, 17 Pet-Familien, 465 Lehrtiere
(1130 Tier-Einträge, davon 432 mit bestätigtem Rang), Koordinaten für 417 Tiere,
56 Zonen, 5 Tierausbilder.

## 2. `index.html` – die Seite

Eine einzige Datei: CSS im `<style>`, die gesamte Logik in einer IIFE im `<script>`,
davor `<script src="data.js">`. Kein Framework, kein Bundler, kein Zustand außerhalb
des Browsers.

**Theming.** Alle Farben sind CSS-Variablen auf `:root`. Dunkelmodus kommt doppelt:
über `@media (prefers-color-scheme: dark)` (abgesichert mit `:root:not([data-theme="light"])`)
und über `:root[data-theme="dark"]` für den Umschalter in der Fußzeile. Die Wahl liegt
in `localStorage` unter `petTheme` (`index.html:626`).

**Startlogik** (`index.html:282-327`), einmal beim Laden:

1. `D.coords` entpacken – in `data.js` stehen flache Integer-Listen, hier werden wieder
   `[[x, y], …]`-Paare in Prozent daraus.
2. Zonen, die nur aus den Koordinaten bekannt sind, in `b.zones` des Tiers nachtragen.
3. Je Fähigkeit und je Tier einen kleingeschriebenen Suchtext `_text` vorberechnen
   (Name, Rangbeschreibungen, Familien, Zonen). Die Suche vergleicht nur noch gegen ihn.
4. Familien- und Zonenauswahl sowie die Lernart-Schalter aus den Daten füllen,
   Kopfzeile und Fußzeile mit den Kennzahlen beschriften.

**Zustand.** Ein Objekt `state` hält Suchbegriff, Familie, Zone, Ansicht, „nur bestätigte
Ränge“, Fraktion, gewählte Lernarten und die offenen Karten. Gespeichert wird es unter
`petState` in `localStorage` (`index.html:316-319`) – bis auf `state.open`: welche Karten
offen sind, soll bewusst nicht über einen Neustart hinaus gelten.

**Rendern.** `render()` entscheidet zwischen `renderAbilities()` und `renderFamilies()`.
Jede Fähigkeitskarte baut `abilityCard()` als HTML-String zusammen, am Ende wird
`#list.innerHTML` in einem Rutsch gesetzt. Kein virtuelles DOM, kein Diffing: bei jeder
Filteränderung wird die Liste komplett neu gebaut. Das ist bei 39 Karten schnell genug;
die Sucheingabe ist trotzdem um 120 ms entprellt. Jeder Fremdtext läuft durch `esc()`.

**Karten und Fundorte** (`index.html:332-419`). Das Zonenbild kommt direkt vom Wowhead-CDN,
`…/classic/maps/dede/{normal|original}/{zoneId}.jpg`; `normal` für die Vorschau,
`original` für die große Ansicht. Die Fundorte sind absolut positionierte `<span class="pin">`
in Prozent – deshalb passen sie ohne Umrechnung auf jede Bildgröße. Zwei Hilfsfunktionen
halten das lesbar: `sample()` zeigt in der Vorschau höchstens 40 gleichmäßig verteilte
Punkte, `spread()` sucht für den Koordinatentext die drei am weitesten auseinanderliegenden
Punkte aus (sonst stünden dort dreimal fast dieselben Werte). Ein Klick auf die Vorschau
öffnet ein `<dialog>` mit Zonen-Tabs, falls ein Tier in mehreren Zonen vorkommt.
Lädt ein Kartenbild nicht, entfernt sich die Vorschau per `onerror` selbst.

**Ereignisse.** Statt Handler pro Karte hängt alles an `#list` (Delegation): Karte
vergrößern (`data-map`), „Alle Tiere anzeigen“ (`data-more`) und der Sprung aus der
Familienansicht zu einer Fähigkeit (`data-goto`). Beim Aufklappen einer langen Tierliste
wird die Scrollposition gemerkt und wiederhergestellt, weil ja neu gerendert wird.

## 3. Aufwand und Empfehlung

`effort()` (`index.html:363-380`) schätzt je Tier, wie mühsam das Zähmen wird. Ein
Punktesystem, niedriger ist leichter:

| Kriterium | Punkte |
| --- | --- |
| Elite | +3 |
| Rar-Elite | +5 |
| Boss | +6 |
| Rar | +3 |
| in einem Dungeon | +3 |
| in einem Raid oder auf einem Schlachtfeld | +5 |
| kein Fundort mit Koordinaten | +1,5 |
| weniger als 3 Fundorte | +2 |
| weniger als 10 Fundorte | +1 |
| Rang nur geschätzt (`est`) | +2 |
| Tierstufe über der Rang-Stufe | Differenz / 10 |
| nur in Zonen der Gegenfraktion | +2 |

Bis 1,5 Punkte „leicht“, bis 4 „mittel“, darüber „schwer“. Je Rang steht das Tier mit der
niedrigsten Summe oben und bekommt ★. Die Empfehlung oben in der Karte nennt das beste
Tier des höchsten Rangs und, falls das ein anderes ist, zusätzlich das insgesamt leichteste.
Die Begründung (`why`) liefert dieselbe Funktion mit: als Tooltip am farbigen Punkt vor dem
Tier und als Klartext in der Empfehlung oben in der Karte.

Zwei Dinge dazu: Die Gegenfraktions-Abwertung arbeitet mit der festen Zonenliste
`FACTION_ZONES` (`index.html:361`) – das sind die Startgebiete, nicht alle feindlichen Zonen.
Und das Ganze schätzt nur, wie schwer das Tier zu erreichen ist. Wie schnell ein Pet die
Fähigkeit im Kampf aufschnappt, hängt nicht vom Tier ab.

## 4. Das Datenformat `data.js`

Die Datei setzt genau eine globale Variable:

```js
window.PET_DATA = { generatedAt, sources, coords, instances, families, zones, trainers, trainerRef, abilities };
```

| Feld | Inhalt |
| --- | --- |
| `generatedAt` | ISO-Zeitstempel des Laufs; die Fußzeile zeigt ihn als „Stand“. |
| `sources[]` | `{ label, url }` – die Links in der Fußzeile. |
| `coords` | `{ npcId: { zoneId: [x, y, x, y, …] } }`, flach und mit 10 multipliziert gerundet. Aus `28.4 / 66.4` wird `284, 664`. Das spart gegenüber verschachtelten Kommazahlen viel Platz; `index.html:284-290` packt es wieder aus. |
| `instances` | `{ zoneId: 2 Dungeon, 3 Raid, 4 Schlachtfeld }`, nur für Zonen, die vorkommen. |
| `families[]` | `{ id, name, icon, diet, type }` – die 17 Pet-Familien. |
| `zones` | `{ zoneId: deutscher Name }`, nur tatsächlich benutzte Zonen. |
| `trainers[]` | `{ id, name, title, zones[] }` – die Tierausbilder in den Hauptstädten. |
| `trainerRef` | `{ url, user }` des Kommentars, aus dem die Ausbilderliste stammt. |
| `abilities[]` | die Fähigkeiten, nach deutschem Namen sortiert. |

Eine Fähigkeit in `abilities[]`:

| Feld | Inhalt |
| --- | --- |
| `name`, `nameEn` | deutscher und englischer Name. Der englische ist der Schlüssel zu Petopia. |
| `icon` | Dateiname ohne Endung, wird zur Icon-URL ergänzt. |
| `schools`, `classic`, `classicFamilies[]` | Zauberschule und Classic-Herkunft; derzeit nicht überall angezeigt. |
| `families[]` | Familien-IDs, die die Fähigkeit nutzen (leer bei allgemeinen Fähigkeiten). |
| `kind` | `general` (alle Familien), `family` (bestimmte Familien), `trait` (Angriffstempo). |
| `source` | `tame` (von einem Tier abschauen), `trainer` (Tierausbilder), `unknown` (keine Quelle nennt etwas). Steuert Label, Filter und Empfehlungstext. |
| `speed` | nur bei `kind: 'trait'`: das Angriffstempo als Text, z. B. `"1.3"`. |
| `classicTrainer` | in Classic beim Ausbilder lernbar (laut Petopia). |
| `classicExtra[]` | Ränge, die es in Classic gab und die Forever nicht listet: `{ rank, level, tp }`. |
| `ranks[]` | `{ id, rank, level, desc, tp }` – Spell-ID, Rangnummer, Pet-Mindeststufe, deutsche Beschreibung, Trainingspunkte (oder `null`). |
| `beasts[]` | die Lehrtiere, siehe unten. |
| `refs[]` | `{ label, url }` – die Belege, die unten in der Karte stehen. |

Ein Tier in `beasts[]`:

| Feld | Inhalt |
| --- | --- |
| `id`, `name` | NPC-ID und deutscher Name. |
| `family` | Familien-ID. |
| `min`, `max` | Stufenbereich. |
| `zones[]` | Zonen-IDs. |
| `zoneText` | Ersatztext, wenn keine Zonen-ID ermittelt werden konnte (Petopia-Freitext). |
| `cls` | Einstufung: 0 normal, 1 Elite, 2 Rar-Elite, 3 Boss, 4 Rar. |
| `rank` | der Rang, den dieses Tier beibringt. |
| `est` | `true` = Rang nur nach der Tierstufe geschätzt. Auf der Seite das „≈“. |
| `src[]` | woher der Eintrag stammt: `petopia` (P), `kommentar` (K), `forever` (F). Mehrere möglich. |

`data.js` ist generiert und wird nicht von Hand bearbeitet.

## 5. Die Datenbeschaffung: `tools/fetch-data.mjs`

`node tools/fetch-data.mjs` – der Ablauf in der Reihenfolge des Skripts:

**1. Abrufen und Cache** (`get()` und `download()`, Zeile 39-75). Vor jedem Abruf 2 Sekunden
Pause. Bei 403, 429 oder 5xx – Wowhead drosselt – wird mit wachsender Wartezeit bis zu
viermal neu versucht. Ein 404 wird als leere Datei im Cache vermerkt, damit dieselbe Seite
nicht bei jedem Lauf neu angefragt wird. Weiterleitungen folgt das Skript selbst
(`redirect: 'manual'`), weil Wowhead auf URLs mit Umlauten umleitet und der `Location`-Header
dabei latin1-kodiert ankommt; ohne die Korrektur läuft `fetch` im Kreis.
Jede Antwort landet unter einem sprechenden Namen in `tools/cache/`:

| Datei | Inhalt |
| --- | --- |
| `list.html`, `list-en.html` | die Fähigkeitenliste, deutsch und englisch |
| `zones.html`, `zones-en.html` | die Zonenlisten |
| `spell-<id>.html` | eine Zauberseite samt Kommentaren |
| `npc-<id>.html` | eine NPC-Seite aus Forever |
| `classic-npc-<id>.html` | dieselbe NPC-Seite aus Classic, wegen der Koordinaten |
| `petopia-abilities.html`, `petopia-attackspeed.html` | die beiden Petopia-Seiten |

**2. Wowhead auslesen ohne HTML-Parser.** Die interessanten Daten stehen auf Wowhead-Seiten
als JavaScript-Literale im Quelltext. Zwei Helfer holen sie heraus: `sliceLiteral()` schneidet
ab einer Fundstelle das Array- oder Objektliteral per Klammerzählung aus (Strings werden dabei
beachtet), `evalLiteral()` wertet es in einem leeren `vm`-Kontext mit 1 s Zeitlimit aus –
nötig, weil Wowhead unquotierte Schlüssel benutzt und `JSON.parse` daran scheitert.
So gelesen werden `listviewspells` (die Fähigkeitenliste), die `listview`-Blöcke
`used-by-pet` und `used-by-npc`, `WH.Gatherer.addData(6, …)` (Beschreibung und Icon),
`$.extend(g_npcs[id], …)` (NPC-Stammdaten) und `g_mapperData` (die Fundorte).

**3. Fähigkeitenliste.** Die deutsche Liste liefert alles, die englische nur die Namen
(`nameEn`) als Schlüssel zu Petopia. Gefiltert wird auf `chrclass === 4` (Jäger) abzüglich
`SKIP_IDS` – vier interne Einträge (Scaling, DND, Summoning).

**4. Zonen.** Aus `/zones` kommen die deutschen Namen für die Anzeige und, aus der englischen
Fassung, eine Brücke „englischer Zonenname → Zonen-ID“, mit der sich Petopia-Ortsangaben
deutsch anzeigen lassen. Gruppeninhalte erkennt das Skript an `nplayers > 0` und unterscheidet
über `category` zwischen Dungeon, Raid und Schlachtfeld – daraus wird `instances`.
(Die Blackrockspitze hat `"instance":0`, aber 10 Spieler; deshalb `nplayers` und nicht `instance`.)

**5. Je Zauberseite** werden gelesen: Pet-Familien, die Tiere aus `used-by-npc`, Rangnummer,
Pet-Stufe, Beschreibung und Icon – und die Kommentare der Seite.

**6. Nachladen.** Tiere, die nur Petopia oder ein Kommentar nennt, kennt Forever aus Schritt 5
noch nicht. Für sie und für die Tierausbilder wird je eine NPC-Seite geholt. Beim ersten Lauf
sind das ein paar hundert Seiten, gut 20 Minuten.

**7. Tiere zusammenführen** (Zeile 272-341). Die Reihenfolge ist die Rangfolge der Quellen:

1. Petopia und die Kommentar-Tabellen liefern Tiere **mit** Rang → `est: false`.
2. Danach die Forever-Tiere: ist das Tier schon bekannt, wird nur `src` um `forever`
   ergänzt (es bestätigt den Eintrag). Ist es neu, wird sein Rang aus der Tierstufe
   geschätzt – der höchste Rang, dessen Pet-Stufe die Tierstufe nicht übersteigt – und
   `est: true` gesetzt. Bei allgemeinen Fähigkeiten bleibt die Forever-Liste außen vor,
   dort wäre sie nur Rauschen.

Trainingspunkte kommen aus Petopia, ersatzweise aus einer Kommentar-Tabelle. Ränge, die es
in Classic gab und die Forever nicht listet, landen in `classicExtra`. Die Lernart ergibt
sich am Ende: gibt es Lehrtiere → `tame`; sonst Ausbilder oder allgemeine Fähigkeit →
`trainer`; sonst `unknown`.

**8. Angriffstempo.** Das ist keine erlernbare Fähigkeit, sondern eine versteckte Aura
(„Schnellerer/Langsamerer Angriff“), die Wowhead trotzdem in der Liste führt. `TRAIT_SPEED`
(Zeile 23-26) ordnet diesen Spell-IDs das Tempo zu (Basis 2,0 s); die Tiere dazu kommen aus
der Petopia-Tempoliste, und die Fähigkeit bekommt `kind: 'trait'`.

**9. Koordinaten und Schreiben.** Für jedes Tier einmal die Classic-Seite, `g_mapperData`
auslesen, Punkte je Zone entdoppeln. Zum Schluss werden nur die Zonen übernommen, die
wirklich vorkommen, und `data.js` geschrieben.

## 6. Die Quellen – was genau woher kommt

| Quelle | Liefert | Code | Verlässlichkeit |
| --- | --- | --- | --- |
| **Wowhead Forever** (de + en) | Fähigkeiten, Ränge, Pet-Stufen, Beschreibungen, Icons, Pet-Familien, Tiere je Fähigkeit, Zonennamen, NPC-Stammdaten (Name, Stufe, Zone, Einstufung) | `fetch-data.mjs:99-139` | Der aktuelle Stand des Servers. Aber: keine Rangzuordnung der Tiere, keine Trainingspunkte, keine Karten. |
| **Wowhead-Kommentare** auf den Zauberseiten | rangweise Zähmlisten mit Trainingspunkten, die Tierausbilder | `sources.mjs:60-113` | Spielerwissen, meist aus Classic. Die ergiebigste Tabelle stammt von „hevgirl“ (2019). |
| **Petopia Classic** | Lehrtiere je Rang, Trainingspunkte, „learned from trainers“, Angriffstempi | `sources.mjs:22-57` | Sehr gründlich, aber Classic-Stand. |
| **Wowhead Classic** | Fundorte (`g_mapperData`) und die Zonenkarten vom CDN | `fetch-data.mjs:141-154` | Forever hat keine eigenen Kartendaten, deshalb der Umweg. Fundorte können abweichen. |

Zu den Parsern in `tools/sources.mjs`:

- `parsePetopiaAbilities()` zerlegt die Seite an den `guide_heading`-Überschriften, liest je
  Rang „Pet Level N, Cost N TP“, die Beschreibung, das Merkmal „learned from trainers“ und
  die verlinkten NPCs. Die Klammerangabe hinter jedem Tier („Wolf, 2-3, Tirisfal Glades“)
  zerlegt `parseNpcInfo()` in Familie, Stufenbereich und Zone.
- `parsePetopiaAttackSpeeds()` liest dieselbe NPC-Notation aus der Tempo-Seite.
- `extractComments()` holt die `lv_comments`-Arrays samt Antworten aus einer Wowhead-Seite.
- `parseCommentLists()` versteht zwei Formen: eine Tabelle, deren Kopfzeile `[spell=…]`-Links
  und „Rank N“ enthält (daraus kommen Rang, TP und die NPCs je Spalte), und einfache
  Freitextlisten. Letztere werden nur übernommen, wenn das Wort „tame“ vorkommt und mindestens
  zwei NPCs verlinkt sind – sonst landen beliebige Kommentar-Links in den Daten.
- `parseTrainerComment()` zieht die Tierausbilder aus dem Kommentar zu „Große Ausdauer“.

Weil Petopia englisch ist, hängen zwei Übersetzungstabellen in `fetch-data.mjs:27-34`
daran: `PETOPIA_ALIAS` für abweichende Fähigkeitsnamen und `FAMILY_EN` für die
Familiennamen (Singular und Plural) → Wowhead-Familien-ID.

## 7. Fallstricke und Wartung

- **Alle Parser hängen an fremdem Markup.** Benennt Wowhead eine Variable um oder ändert
  Petopia seine CSS-Klassen, bricht genau ein `indexOf` oder `match`. Das Skript bricht dann
  laut ab (`main().catch`), es schreibt keine halben Daten.
- **Den Cache nicht leichtfertig löschen.** Ein Lauf ohne Cache dauert etwa 30 Minuten und
  riskiert erneutes Drosseln. Wer nur eine Fähigkeit neu ziehen will, löscht gezielt die eine
  `spell-<id>.html`.
- **Leere Cache-Dateien sind Absicht.** Sie bedeuten „gibt es dort nicht“ (404), meist ein NPC,
  den es in Classic nicht gibt.
- **Petopia-Zonen ohne Treffer** in der Namensbrücke landen als Freitext in `zoneText`; solche
  Tiere haben keine Karte und bekommen in der Aufwandsschätzung einen kleinen Aufschlag.
- **Classic-Wissen bleibt Classic-Wissen.** Trainingspunkte, Ausbilder und Ränge stammen aus
  Petopia und den Kommentaren und können in Forever abweichen. Die Seite kennzeichnet die
  Herkunft (P/K/F), prüfen kann das Skript sie nicht.
- **Neue Forever-Fähigkeiten ohne Classic-Vorbild** (Prankenhieb, Zwicken, Sehnenriss,
  Zerstückeln, Wildes Verwunden, Meins!) haben keine Lernquelle und stehen deshalb als
  `source: 'unknown'` in den Daten.
