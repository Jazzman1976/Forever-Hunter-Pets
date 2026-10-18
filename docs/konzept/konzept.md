# Konzept: Ziele, Modelle, Entscheidungen

Das Nachschlagewerk für den roten Faden: **was** das Addon sein soll, **wie** es gedacht ist und **warum** es so entschieden wurde. Stand 17.10.2026. Wie es gebaut ist, steht in [addon-technik.md](../technik/addon-technik.md); dieses Dokument verweist dorthin und auf den Code, statt ihn zu wiederholen. Die Anwender-Sicht steht in der englischen Anleitung [guide.md](../guide/guide.md).

Wer etwas ändert, prüft hier zuerst, ob es einer Entscheidung widerspricht. Entscheidungen werden nicht stillschweigend umgedreht; neue kommen hierher und nach [entscheidungen.md](entscheidungen.md) (dort mit Datum und Wortlaut).

**Inhalt:** [1 Zweck und Leitbild](#1-zweck-und-leitbild) · [2 Grundsätze](#2-grundsätze-in-dieser-rangfolge) · [3 Begriffe](#3-begriffe) · [4 Daten: woher, wohin](#4-daten-woher-wohin) · [5 Die zwei Modi](#5-die-zwei-modi) · [6 Status eines Tiers](#6-status-eines-tiers) · [7 Fortschritt](#7-fortschritt) · [8 Fundorte](#8-fundorte) · [9 Fährten](#9-fährten) · [10 Belegung](#10-belegung-was-gilt-als-wahr) · [11 Lernstand](#11-lernstand) · [12 Teilen](#12-teilen-im-spiel) · [13 Oberfläche](#13-oberfläche) · [14 Verworfen und zurückgestellt](#14-verworfen-und-zurückgestellt) · [15 Arbeitsweise](#15-arbeitsweise) · [16 Meilensteine und Stand](#16-meilensteine-und-stand) · [17 Wo was steht](#17-wo-was-steht)

## 1 Zweck und Leitbild

**Zweck:** Jäger in WoW Forever lernen Pet-Fähigkeiten von Tieren. Das Addon sagt, **welches Tier welchen Rang lehrt und wo es lebt**, und führt den Lernstand.

**Leitbild „Zähmen als Spiel“** (15.10.2026). Das ist der Kern, an dem sich alles ausrichtet:

- **Alles finden, alles katalogisieren.** Jede Fähigkeit, jeder Rang, jedes Lehrtier, jeder Fundort.
- **Suchen und Sammeln soll Spaß machen und belohnt werden**, auch wenn es für Raid-Spieler unnötig ist. Das unterscheidet das Addon von anderen.
- **Lücken sind Aufgaben, keine Schwäche.** Was niemand kennt, kann man entdecken. Daraus sollen später Erfolge werden („Pionier: 10 Tiere gefunden, die noch niemand kannte“).
- **Was man nicht kennt, sucht man nicht.** Das Addon verrät deshalb im Entdeckermodus, *dass* und *wie viel* es zu finden gibt, aber nicht *was*.
- **Ziel des Spiels ist „Fähigkeiten bekannt“** (17.10.2026): Nur das treibt den Fortschritt. Fährte und Fund sind Schritte dorthin.
- **Nebenbei werden alte Jäger-Fähigkeiten sinnvoll:** „Wildtiere aufspüren“, „Adlerauge“ und „Augen des Wildtiers“ bringen Fährten – in WoW eher Nebensache, hier Werkzeuge der Suche.
- **Das Classic-Gefühl zurückholen,** wo der Forever-Client es schlechter macht (Beispiel: Ansicht „Ausbildung“).

**Warum nur eigene Daten:** In frühen Entwicklungsständen stammten Daten aus fremden Quellen, deren Bedingungen das Weiterverbreiten nicht erlaubten oder deren Rechte sich nicht zweifelsfrei klären ließen. Dieser Bestand wurde vollständig verworfen. Seit 15.10.2026 enthält das Addon nur, was im Spiel selbst erhoben wurde, und was der Client zur Laufzeit liefert. Aus der Not wurde das Spielprinzip: Die Lücken füllen die Spieler.

## 2 Grundsätze (in dieser Rangfolge)

1. **Nur eigene Daten und Client-Daten.** Keine fremden Datenquellen – nie im Repo, nie im Addon, auch nicht als Herkunftsangabe in Texten. Nichts aus fremden Addons (Code oder Tabellen). Lizenz: MIT für Code, erhobene Daten (auch von anderen Spielern geteilte) und Logo.
2. **Wenig Kanal-Verkehr, wenig Speicher, wenig Rechenzeit – vor Komfort** (16.10.2026). Der verborgene Kanal darf nicht ausarten: so wenig wie möglich, so viel wie nötig. Gezählt wird bei Bedarf (beim Öffnen einer Ansicht), nicht im Hintergrund.
3. **Eigenes zählt sofort, überall** (16.10.2026). Was man selbst sichtet, zähmt oder erhebt, gilt im Addon sofort, nicht erst nach dem Import in die mitgelieferten Daten. Neue Stellen lesen nie nur `D.beasts`, `D.families` oder `a.teach`, sondern nehmen die Helfer, die Daten und eigene Funde zusammenführen ([§4](#zur-laufzeit-daten-und-eigene-funde-zusammen)).
4. **Nicht spoilern.** Wer entdecken will, bekommt nichts verraten – das Addon fragt jeden Charakter beim ersten Start und zeigt bis dahin nichts.
5. **Barrierefreiheit:** Kein Zustand nur über Farbe, immer auch ein Wort oder Symbol.
6. **Gleiches sieht gleich aus und ist gleich** (Regel für immer, 16.10.2026). Derselbe Zustand bekommt überall dasselbe Element, Wort und Symbol; neue Ansichten nehmen vorhandene Bausteine (Kästchen aus „Fähigkeiten“, `ns.FamilyIcon`, `ns.StatusWord`, `ns.TeachText`).
7. **Knapp.** Keine Erklärtexte in Listen und Tooltips; Markierungen sind ein Wort oder „?“ / „!“. Erklärt wird in den Einstellungen und im Startdialog. Ausnahmen: der Erklär-Tooltip am Zähler „Tiere“ (dort sucht man es) und die Zeile für Tiere, deren Lehre noch niemand kennt (#23, sonst wirkt das Tier, als könne es nichts).
8. **Nicht raten.** Was niemand weiß, sagt das Addon („? unbekannt“, „? unklar“, „Fundort unbekannt“). Keine Wahrscheinlichkeiten, keine Hochrechnung aus Familie und Stufe.

## 3 Begriffe

| Begriff | Bedeutung | Im Code |
| --- | --- | --- |
| **Fähigkeit, Rang** | Pet-Fähigkeit (Beißen) und ihr Rang (Beißen 3); Schlüssel ist die Zauber-ID des Rangs | `D.abilities[i].ranks[j].id` |
| **Lehrtier** | Tier (NPC-ID), das einen Rang mitbringt, wenn man es zähmt | `a.teach`, `ns.Teachers` |
| **Angeboren** | Angriffstempo: bringt das Tier mit, lässt sich nie lehren | `a.kind == "trait"` |
| **Sichtung** | Stammdaten eines Tiers aus etwa 28 m: Name, Stufe, Einstufung, Familie, Tempo | `Core/Sightings.lua`, `db.sights` |
| **Fährte** | „in dieser Zone gesehen“, aus jeder Entfernung | `db.seenIn`, Status `track` |
| **Fundort, Zelle** | wo ein Tier stand, gerundet auf 2 % der Karte, nur aus etwa 10 m | `Core/Places.lua`, `db.loc`, `db.locIn` |
| **Zähmung, Beobachtung** | was ein gezähmtes Tier wirklich mitbrachte | `Core/Observe.lua`, `db.obs` |
| **Erhebung** | Fähigkeiten und Ränge aus Wildtierausbildung, Tierausbilder und Zauberbuch | `Core/Survey.lua`, `db.survey` |
| **Melder, Kürzel** | wer etwas gemeldet hat, als Hash statt Name | `ns.MyRep`, `db.myReps` |
| **Belegung** | wie sicher ein Lehrtier-Paar ist: belegt, unsicher, unbelegt, widerlegt | `conf`, `ns.CONF_*` |
| **Status** | wie weit man selbst mit einem Tier in einer Zone ist (nur Entdeckermodus) | `ns.BeastStatus` |
| **Komplett-/Entdeckermodus** | was angezeigt wird (alles / nur Eigenes), je Charakter | `ns.Discovering()` |

## 4 Daten: woher, wohin

### Sammelwege im Spiel

| Weg | Auslöser | Liefert |
| --- | --- | --- |
| **Erhebung** | Wildtierausbildung öffnen, Tierausbilder besuchen, Pet rufen | Fähigkeiten, Ränge (Zauber-ID), Pet-Stufe, Kosten, Familien; Familien-Icon (`GetPetIcon`) |
| **Sichtung** | Ziel, Maus, Namensplakette; außerhalb Kampf und Instanz | Fährte (jede Entfernung), Stammdaten (28 m), Fundort (10 m) |
| **Witterung** | Maus über einem Punkt von „Wildtiere aufspüren“ auf der Minikarte | Fährte (über den Namen zugeordnet) |
| **Zähmen** | „Wildtier zähmen“ gelingt | Zauber-IDs, Stufe, Tempo, Fundort (immer), Fährte |
| **Lernmeldung, Ausbildungsfenster** | „Ihr habt einen neuen Zauber erlernt“, Wildtierausbildung | Lernstand des Jägers |

Wildtierkunde zeigt in Forever keine Fähigkeiten (an Blizzard gemeldet) und taugt deshalb nicht zum Sammeln; ihr Icon ist trotzdem das Addon-Icon.

### Ablage

Kontoweit in `ForeverHunterPetsDB` (`survey`, `sights`, `obs`, `loc`, `locIn`, `seenIn`, `trackNames`, `myReps`), je Charakter in `ForeverHunterPetsCharDB` (`known`, `discover`, `modeChosen`, `filters`). Funde gelten kontoweit („Erkundung je Konto“), der Modus je Charakter. Formate in [addon-technik.md](../technik/addon-technik.md).

### Vom Spiel ins Repo

```
SavedVariables ──tools/import-observations.mjs──> tools/eigene/*.json ──build-data.mjs──> tools/data.json ──build-addon.mjs──> Data/Data.lua
```

Jeder Eintrag in `tools/eigene/` braucht einen Beleg. Der Generator rechnet die Belegung ([§10](#10-belegung-was-gilt-als-wahr)) und bricht ab, wenn ein Beleg fehlt. `tools/data.json` und `Data/Data.lua` sind generiert und werden nie von Hand bearbeitet. Fremde Fundort-Zellen werden je Melder gespeichert und wie Zähmungen und Sichtungen ab 3 Meldern ausgeliefert (#2).

### Zur Laufzeit: Daten und eigene Funde zusammen

Die mitgelieferten Daten sind nur ein Teil. Was das Addon zeigt, setzt sich zusammen – und genau dafür gibt es Helfer, die immer zu nehmen sind:

| Frage | Helfer | Quellen |
| --- | --- | --- |
| Welche Fähigkeiten und Ränge gibt es? | `ns.MergeSurveyAbilities` (beim Einloggen und nach jeder Erhebung; Zwischenspeicher über `ns.OnAbilitiesChanged`) | Daten + eigene Erhebung |
| Stufe, Familie, Einstufung eines Tiers | `ns.BeastInfo`, `ns.BeastFamily` | Daten → Sichtung → Zähmung → Fernname |
| Name eines Tiers | `ns.BeastName` | Sichtung (Client-Sprache) → Daten → Fernname → „Unbekanntes Tier (#ID)“ |
| Name und Icon einer Familie | `ns.FamilyName`, `ns.FamilyIds`, `ns.FamilyIcon` | Daten → Erhebung → Ersatz-Icon „Wildtier zähmen“ |
| Lehrtiere eines Rangs | `ns.Teachers`, `ns.ObservedTeachers` | Daten + Zähmungen (eigene und geteilte) |
| Was lehrt ein Tier? | `ns.TeachInfo(npc, discover)` | Entdeckermodus: eigene Zähmung; sonst Daten + alle Zähmungen |
| Fundorte, Zonen | `ns.Coords`, `ns.ZoneCounts`, `ns.BeastZones`, `ns.TamedZones` | Daten + Zellen + eigene Zähmungen |

Anlass für den Grundsatz: Ein gezähmter Kojote fehlte bei „Beißen 2“, ein Junger Fleischreißer „brachte keine Fähigkeit mit“ – beides, weil nur die mitgelieferten Daten gelesen wurden.

## 5 Die zwei Modi

Wortlaut des Nutzers (17.10.2026), maßgeblich:

> „Komplettmodus will nichts suchen. Da soll alles was bekannt ist immer vollständig präsentiert werden, auch wenn das von anderen Spielern oder den Stammdaten kommt. Was der Spieler noch nie gesehen oder gezähmt hat ist im Komplettmodus völlig irrelevant. Ganz im Gegenteil zum Entdeckermodus. Da zählt im Gegenteil dazu nur das, was der Spieler wirklich gesehen und gezähmt und entdeckt hat. Die Stammdaten und die Daten anderer Spieler dienen dann nur als Quelle für das Grundgerüst was man sehen muss damit man danach sucht, z.B. die Fortschrittsbalken. Da sollen dann auch Tiere als ‚Unbekanntes Tier‘ in der Liste des Gebiets auftauchen und Statusbalken angezeigt werden. Damit man eben danach auch sucht. Alle Tiere nur anonymisiert quasi. Bis man eine Fährte hat. Ab da dann mit Namen und Status Tag.“

| Stelle | Komplettmodus | Entdeckermodus |
| --- | --- | --- |
| Lehrtiere, Namen, Fundorte | alles Bekannte | nur Eigenes |
| Grundgerüst | – | alle Fähigkeiten und Ränge (Spielwissen), **wie viele** Lehrtiere und Tiere es gibt |
| Fähigkeiten, Liste und Details | alle Lehrtiere | eigene; die übrigen als „N unentdeckt“ bzw. „? unentdecktes Tier“ |
| Kartenseite | alle Fundorte | eigene Zellen |
| Tier-Tooltip | Ränge aus allen Daten, kein Status | Status-Tag, Ränge nur aus eigener Zähmung |
| Reiter „Gebiet“, Liste | alle Tiere benannt, anklickbar, kein Status | anonym bis zur Fährte, dann Name und Status-Tag |
| Reiter „Gebiet“, Fortschritt | Stand des Datensammelns | eigener Stand |
| Ausbildung | unverändert | unverändert |
| Sammeln und Teilen | an | an |

- **Modus je Charakter, Funde je Konto.** Ein zweiter Charakter wählt neu, sieht aber die Funde des ersten als eigene.
- **Startdialog** beim ersten Öffnen je Charakter; bis zur Wahl zeigt das Addon nichts, was spoilern könnte (Tooltip leer), sammelt aber. Umschaltbar in den Einstellungen. Der aktuelle Modus steht klein oben rechts vor dem Zahnrad.
- **Zwei Wörter für Lücken:** „? unbekannt“ – das weiß niemand. „? unentdeckt“ – es ist bekannt, du hast es nur noch nicht gefunden (nur Entdeckermodus).
- **Tipp Namensplaketten:** ein Satz am Ende der Moduswahl in den Einstellungen, bewusst unauffällig (nicht jeder mag Plaketten).

## 6 Status eines Tiers

Nur im Entdeckermodus. Im Komplettmodus gibt es keinen Status.

| Status (Code) | Tag | Wann | Kästchen |
| --- | --- | --- | --- |
| `unknown` | „? unentdecktes Tier“ (anonym) | noch nichts in dieser Zone | keins |
| `track` | **Fährte aufgenommen** | in dieser Zone gesehen, nie nah gewesen | keins |
| `found` | **Tier gefunden** | eigener Fundort in dieser Zone (oder eigene Zähmung dort) | leer |
| `known` | **Fähigkeiten bekannt** | gefunden und selbst gezähmt | Haken |

- **Je NPC-ID und je Zone.** Jede Zone ist ein eigenes Jagdrevier; ein Tier, das über eine Grenze läuft, muss in jeder Zone selbst gefunden werden. Innerhalb einer Zone reicht ein Tier dieser ID.
- **Was ein Tier lehrt, gilt zonenübergreifend:** Die Fähigkeiten hängen an der NPC-ID, nur der Rang an der Stufe. „Bekannt“ wird ein Tier in einer Zone trotzdem erst, wenn es dort gefunden ist.
- **Wo lebt ein Tier?** (`ns.LivesIn`) Wo es einen echten Fundort hat: Daten, Zelle oder eigene Zähmung. Hat es nirgends einen, zählt seine Fährte, wo man es gesehen hat ([§9](#9-fährten)).
- **Wörter:** Jäger-Sprache, als Zustand formuliert, ohne Icon. Verlauf: „Fährte“ mit Pfoten-Icon, dann „gesichtet / gefunden / bekannt“ – zu nah beieinander, der Unterschied war unklar. Im Code heißt der Status weiter `track`. Texte: `ns.StatusWord`, `ns.StatusText` (liefert im Komplettmodus `nil`).
- **„lehrt nichts“** steht grau im Tooltip, wenn feststeht, dass ein Tier nichts lehrt (sonst fehlte jeder Hinweis); folgt der Einstellung „Bekannte Fähigkeiten anzeigen“. „Kein Lehrtier in den Daten“ heißt allein nie „lehrt nichts“ – das klärt erst eine Zähmung; bis dahin „? unklar“.

## 7 Fortschritt

`ns.ZoneProgress(map)`, angezeigt im Reiter „Gebiet“. Y aus allem Bekannten (Daten, Zellen, Zähmungen, Fährten), X je Modus:

| Zähler | Y | X Entdeckermodus | X Komplettmodus |
| --- | --- | --- | --- |
| Tiere „X von Y bekannt“ | Tiere der Zone | selbst gezähmt (`known`) | irgendwer weiß, was es lehrt |
| Lehrtiere | Tiere der Zone, die etwas lehren | selbst identifiziert | alle |
| Fähigkeiten | Ränge, die ein Lehrtier der Zone lehrt | selbst entdeckt | alle |
| Fundorte | – | eigene Zellen | alle Fundorte |

- **Nur „Fähigkeiten bekannt“ treibt den Fortschritt.** Fährte und Fund bewegen den Balken nicht.
- **Immer „X von Y“** (18.10.2026, #19): Auch wenn alles bekannt ist, steht „8 von 8 …“, bei *Tiere* mit vollem Balken – für alle drei Zähler gleich. Vorher stand bei X = Y nur „8“; über den Kacheln wirkte das wie ein kaputter Umbruch. Im Komplettmodus zeigt der Tiere-Balken, wie weit das Datensammeln ist.
- Ränge vom Tierausbilder und Ränge ohne Lehrtier in der Zone zählen nicht – die muss man dort nicht suchen.
- Zahl und Wort sind maßgeblich, der Balken nur zusätzlich. Gezählt wird beim Öffnen, Zonenwechsel und Auswählen.
- **Kacheln statt Balken** bei Lehrtieren und Fähigkeiten (18.10.2026, #19): je Lehrtier bzw. Rang eine Kachel, unentdeckt mit dem roten Fragezeichen der Liste, entdeckt mit dem Icon der Familie bzw. der Fähigkeit – „ich muss diese Kachel noch aufdecken“. Die Reihenfolge ist fest (NPC-ID, Fähigkeit und Rang), eine Kachel dreht sich beim Entdecken an ihrem Platz um. Höchstens zwei Zeilen, der Rest als „+n“. Fundorte stehen als Fußnote unten links.

## 8 Fundorte

- **Der Client nennt nur die Position des Spielers.** Deshalb zählt ein Fundort nur, wenn das Tier in etwa **10 m** steht (`CheckInteractDistance` 3, sonst 2), gerundet auf ein Raster von 2 % der Karte (50 × 50 Zellen, 60–100 m).
- **Genauigkeit vor Menge** (16.10.2026): Eine Anhebung auf 28 m wurde verworfen. Die Karte soll „hier ungefähr“ zeigen, nicht daneben.
- **Zähmen gibt immer einen Fundort**, vom Beginn des Zauberns: „Wildtier zähmen“ reicht nur etwa 30 m, das liegt in derselben oder der Nachbarzelle. Ältere Zähmungen ohne Zelle zählen in ihrer Zone trotzdem als Fundort (`ns.TamedZones`).
- **Kampf:** Während des Kampfs ruht das Addon (geheime Werte). Fundorte entstehen trotzdem – beim Heranlaufen und danach neben dem toten Tier. Eine eigene Behandlung brachte in der Probe nichts.
- **Fernsicht:** Während „Augen des Wildtiers“ (1002) und „Adlerauge“ (6197) entstehen keine Zellen (`ns.Possessing`), weil der Jäger woanders steht als das, was er sieht. `CheckInteractDistance` misst dabei vom Jäger aus; die Sperre ist die zweite Sicherung.
- **Je Tier und Zelle einmal.** Wandernde Tiere ergeben eine Kette – für die Suche nützlicher als ein Punkt.
- **Karte:** Punkte nur für das gewählte Tier, ohne Auswahl nie (sonst hunderte). Die Karte ist so weit aufgedeckt, wie der Charakter die Zone erkundet hat – eine fremde Overlay-Tabelle wurde aus Lizenzgründen abgelehnt, und das eigene Erkunden gehört zum Suchen.

## 9 Fährten

- **Aus jeder Entfernung** (E7): Maus, Ziel, Plakette, „Adlerauge“, „Augen des Wildtiers“ und die Witterung an der Minikarte. Vorher erst ab 28 m – deshalb gab es kaum Fährten, vieles war sofort „gefunden“.
- **Auch ohne Fundort** (Nutzer: „Tiere ohne Fundorte sollen Fährten haben. Das ist ja gerade der Sinn von Fährte“). Hat ein Tier nirgends einen Fundort, zählt seine Fährte in der Zone, in der man es sah. Sobald es irgendwo einen hat, zählt es nur noch dort – eine Fährte über eine Zonengrenze hinweg verschwindet dann.
- **Name aus der Ferne:** Die Sichtung speichert erst ab 28 m. Damit ein Tier nicht „Unbekanntes Tier (#833)“ heißt, merkt sich die Fährte Name und Familie lokal (`trackNames`), **ohne zu teilen** (Kanal-Verkehr). Mit der ersten Sichtung fällt der Eintrag weg.
- **Witterung** (`UI/Scent.lua`): Die Spur-Punkte auf der Minikarte zeigt der Client im GameTooltip (Besitzer `UIParent`), alle Namen in Zeile 1. Das Addon liest sie, solange der Tooltip offen und die Maus über der Minikarte ist, und gibt passenden Tieren der Zone still eine Fährte. **Angezeigt wird dort nichts** (Nutzer: zu überladen, der Tier-Tooltip reicht).
- **Fährten stehen nicht auf der Karte**, nur Fundorte.

## 10 Belegung: was gilt als wahr

| Stufe | Bedeutung | Anzeige |
| --- | --- | --- |
| belegt | eigene Zähmung, oder mindestens 3 verschiedene fremde Melder, oder ein Befund „bestätigt“ | normal |
| unsicher | weniger als 3 fremde Melder | aus; einschaltbar, Zeichen „?“ |
| unbelegt | nur geschätzt (noch keine Schätzungen, Schalter fehlt) | aus; Zeichen „!“ |
| widerlegt | eine Zähmung zeigte den Rang nicht, obwohl die Stufe reichte | nie |

- **Eigene Zähmungen sind Beweis**, gesehen wie nicht gesehen, und gehen allem Fremden vor. Unter Fremden geht gesehen vor widerlegt.
- **Die Fähigkeiten hängen an der NPC-ID**, nur der Rang an der Stufe. Darum widerlegt eine Zähmung ein Paar endgültig – und darum gibt es **keine Wahrscheinlichkeiten**: Was ein Tier mitbringt, ist kein Zufall. Widersprechen sich Zähmungen derselben NPC-ID, meldet der Generator das; dann wackelt die Annahme.
- **Das Zauberbuch zeigt nur den höchsten Rang:** Ein höherer Rang widerlegt keinen niedrigeren.
- **3 Melder** (17.10.2026, M5, #1): anfangs zwei, dann 10; mit einer Gilde als Spielerschaft wurde 10 kaum erreicht. Drei unabhängige Spieler sind für Spieldaten ein guter Beleg; anheben, wenn es viele Spieler gibt.

## 11 Lernstand

- **Aus Sicht des Jägers.** „Verfügbar / nicht verfügbar / bereits bekannt“ meinen den Jäger, nicht das Pet. Was das aktive Pet lernen kann, zeigt nur „Ausbildung“.
- **Ränge einzeln:** Rang 3 schließt Rang 2 nicht ein (Korrektur vom 21.09.2026). Gespeichert je Zauber-ID.
- **Was das Pet kann, ist nicht gelernt** (0.2.1). Ein verfrühter Haken ist gefährlicher als ein fehlender – man ließe das Tier zu früh frei. Angezeigt wird stattdessen „dein Pet kann es“.
- **Quellen:** Wildtierausbildung (Zauber-ID über den Tooltip der Zeile) und Lernmeldung (trägt die ID eines Jäger-Zaubers, zugeordnet über Name und den Rang, den das Pet schon hat).
- **Gesammelt, nie von selbst entfernt:** Die Ausbildung zeigt nur die Familie des aktiven Pets; ein fehlender Eintrag heißt nichts.
- **Von Hand nur mit „Manuelles Editieren“** (Standard aus) – das Kästchen war zu leicht aus Versehen gesetzt.
- **Ausbilden bleibt im Blizzard-Fenster:** Der Client sperrt das Lehren aus Addons; das Addon öffnet das Fenster nur. Trainingspunkte: nur die Differenz zum vorhandenen Rang zählt.

## 12 Teilen im Spiel

- **Warum im Spiel:** Addons kommen nicht ins Internet. Daten wandern als Addon-Nachrichten über Gilde, Gruppe und den verborgenen Kanal `FHPetsNet` zwischen Spielern, die gleichzeitig online sind. Ein Gruß nach dem Einloggen holt Neues von anderen.
- **Was:** Zähmungen (`O1`), Sichtungen (`S1`), Fundort-Zellen (`F1`), Gruß (`H1`). Nicht geteilt: Fährten, Fernnamen, Status, Lernstand.
- **Sparsam:** gedrosselt (eine Nachricht je 2 s, Bündel alle 5 Minuten), nur was die Daten noch nicht kennen, Obergrenzen für Gespeichertes. Einzelheiten und Zahlen in [addon-technik.md](../technik/addon-technik.md).
- **Datenschutz:** Statt Namen ein Kürzel (Hash); gespeichert werden nur Kürzel. Die eigenen stehen in `myReps`, damit eigene Meldungen als eigene zählen. Das Kürzel ist pseudonym, nicht anonym; Geteiltes kann unter MIT in die Stammdaten kommen, darauf weisen README und Anleitung hin ([entscheidungen.md](entscheidungen.md), 17.10.2026).
- **Abschaltbar** („Beobachtungen teilen“, Standard an): dann nichts senden, nichts empfangen, Kanal verlassen.
- **Ungeprüft** mit mehreren Spielern – das gehört zu M5.

## 13 Oberfläche

**Allgemein:** eigenes Fenster mit drei Reitern (Fähigkeiten · Gebiet · Ausbildung), Zahnrad zu den Einstellungen, Modus oben rechts. Eigene Karte im Fenster, keine Fremdbibliothek. Texte: englischer Text ist der Schlüssel in `L[]`, Deutsch in `Locales/deDE.lua`; Fähigkeits- und Zonennamen vom Client.

**Fähigkeiten:**
- Mehrfachauswahl heißt **„Anzeigen“**, nicht „Filter“: Ein Haken heißt „wird gezeigt“.
- Die Quelle (angeboren, Tierausbilder) ist eine eigene Achse neben dem Status.
- Zone und Familie als harte Filter.
- Lehrtiere nach Belegung, dann Aufwand; geteilt in „auf deiner Stufe“ und „erst ab höherer Stufe“.

**Gebiet:**
- Liste links, Karte rechts oben, bündig mit der Liste; der Kartentitel steht in der Kopfzeile neben der Zonenauswahl (wie „Ausbildung“), die Zähler darunter.
- Immer ein Tier gewählt.
- **„Aktuelles Gebiet“** ist vorgewählt und folgt dem Spieler bei jedem Gebietswechsel, wie „Aktuelle Zone“ in „Fähigkeiten“ (#22). Ein fest gewähltes Gebiet bleibt stehen. In einem Gebiet ohne bekannte Tiere bleibt die Auswahl dort und die Liste sagt „Noch kein Tier in diesem Gebiet bekannt.“ – kein stilles Springen. Die Gebietsliste wird beim Öffnen und Gebietswechsel neu gelesen.
- Kästchen aus „Fähigkeiten“, Familien-Icon.
- „lehrt“ mit Fähigkeits-Icons ohne Rang (passt auch bei mehreren); Namen und Ränge im Tooltip der Zeile.
- Erklärung der Status im Tooltip des Zählers „Tiere“.
- Unentdeckte Tiere tragen die zweite Zeile „Gehe auf die Pirsch und finde es.“ (#19) – ohne sie hielten manche das für eine Lücke in den Daten.
- Kachel-Tooltips knapp: erkanntes Lehrtier wie die Zeile (Name, Lehre, Klick zeigt es auf der Karte), entdeckter Rang Name, Rang und das leichteste Lehrtier der Zone (Klick zeigt es, Bewertung wie in „Fähigkeiten“), Unentdecktes nur „? unentdecktes Lehrtier“ bzw. „? unentdeckte Fähigkeit“.

**Tier-Tooltip:**
- Alle Zeilen bündig mit der Kopfzeile „Forever Hunter Pets“.
- Status-Tag (nur Entdeckermodus), Angriffstempo, Ränge mit „– gelernt“ (grau) / „– neu“ (grün), „lehrt nichts“ (grau). Im Komplettmodus, wenn weder Daten noch irgendeine Zähmung sagen, was das Tier lehrt: „Was dieses Tier lehrt, weiß noch kein Jäger. Zähme es und hilf mit!“ (gold, #23) – Lücken sind Aufgaben. Geprüft wird roh: ausgeblendete unsichere Angaben zählen nicht als fehlend. Im Entdeckermodus nicht, dort sagt der Status, was zu tun ist.
- Nur für wilde Tiere (Familie, nicht vom Spieler kontrolliert) – sonst bekämen Wachen Fährten.
- Neue Fährten melden sich nicht im Chat (liefe voll), sondern über den Status im Tooltip.

**Ausbildung:**
- Zustände wie das Classic-Fenster, mit Farbe **und** Wort.
- Knopf öffnet die Wildtierausbildung über einen sicheren Knopf, der außerhalb des Hauptfensters liegt (sonst gälte das Fenster im Kampf als geschützt).

## 14 Verworfen und zurückgestellt

| Idee | Ergebnis | Grund |
| --- | --- | --- |
| Karte, die sich mit eigenen Funden aufdeckt (E6) | entfallen | Die Karte deckt sich durch normales Erkunden auf |
| Fundort ab 28 m | verworfen | Genauigkeit vor Menge |
| Zeilen im Minikarten-Kasten der Spur | verworfen | zu überladen |
| Pfoten-Icon vor „Fährte“ | entfernt | einziges Status-Wort mit Icon, zu viel |
| Fährtenbuch für Namen ohne Tier der Zone | nicht gebaut | Die Spur zeigt auch Unzähmbares – Rauschen |
| Wahrscheinlichkeiten im Tooltip | verworfen | Fähigkeiten hängen an der NPC-ID |
| Familien-Icons fest im Code | verworfen | nicht selbst erhoben; Icons kommen über `GetPetIcon` |
| Kampf eigens auswerten | verworfen | Probe ergab nichts Zusätzliches |
| Erfolge (E8), Design wie Original-Fenster (M3) | zurückgestellt | erst, wenn es viel mehr eigene Daten gibt |
| Lehrtiere schätzen („!“) | offen | nimmt etwas vom Entdecken, kann falsch liegen |

## 15 Arbeitsweise

- **Agil, ein Inkrement nach dem anderen**, jedes für sich im Spiel prüfbar; Commit erst nach dem Test im Spiel (macht der Maintainer).
- **Erst proben, dann bauen:** Unklare API-Fragen klärt eine Probe (`/fhp …`, Protokoll in den SavedVariables), Ergebnisse in [api-befunde.md](../technik/api-befunde.md).
- **Jeder Vorschlag wird bewertet:** Mehrwert, Komplexität, Risiko – in dieser Reihenfolge, je 1–10, mit Begründung.
- **Prüfen ohne Spiel:** `luaparse` und `fengari` mit nachgebildeter WoW-API; Aussehen nur im Spiel – bei UI-Änderungen sagen, dass die Optik ungeprüft ist.
- **GitFlow:** Jede Änderung mit Issue in `feature/<Nr>-<titel>` von `develop`, per PR mit Merge-Commit zurück, Branch löschen; `main` nur Releases. Ein Release bekommt ein Issue und einen Branch `release/<version>-beta` (vor 1.0.0); dort Version und Release Notes, Abschlusstest, dann per PR zuerst nach `main` (Tag `v<version>-beta`), danach zurück nach `develop` (seit 18.10.2026; 0.6.0 bis 0.8.0 liefen ohne Release-Branch). Einzelheiten in [entwicklung.md](../technik/entwicklung.md).
- **Bekanntes, das nicht zum Auftrag gehört,** wird genannt, nicht ungefragt angefasst.
- **Forever ändert sich wöchentlich**, solange die Beta läuft; erhobene Daten können veralten.
- Doku, Kommentare, Commits deutsch; README, NOTICE, CONTRIBUTING und die Anleitung `docs/guide/guide.md` englisch.

## 16 Meilensteine und Stand

| Meilenstein | Inhalt | Stand |
| --- | --- | --- |
| M1 Eigene Daten | fremde Daten raus, Sammeln im Spiel | abgeschlossen (16.10.2026) |
| M2 Entdecken | Modi, Reiter „Gebiet“, Fährten und Witterung (E1–E5, E7) | abgeschlossen (17.10.2026, Release 0.6.0); E8 zurückgestellt |
| M3 Design | Farben, Hintergründe, Rahmen wie Original-Fenster (nur Aussehen) | zurückgestellt |
| M4 Veröffentlichung | Release, neues öffentliches Repo, CurseForge; vorher Screenshots neu | abgeschlossen (17.10.2026): öffentliches Repo, Beta 0.8.0 auf CurseForge, automatischer Upload |
| M5 Beta-Test | Teilen mit mehreren Spielern, Schwellen, Leistung, andere Sprachen | läuft (seit 17.10.2026); Release 0.9.0-beta mit #1–#5 (18.10.2026) |

Seit 17.10.2026 stehen die Meilensteine als [Milestones](https://github.com/Jazzman1976/Forever-Hunter-Pets/milestones) auf GitHub, die Aufgaben als Issues darin und im öffentlichen [Project](https://github.com/users/Jazzman1976/projects/2). Diese Tabelle ist die Kurzfassung.

## 17 Wo was steht

| Dokument | Inhalt |
| --- | --- |
| [guide/guide.md](../guide/guide.md) | Anleitung für Spieler (englisch) |
| [konzept/entscheidungen.md](entscheidungen.md) | jede Entscheidung mit Datum und Wortlaut |
| [konzept/arbeitsweise.md](arbeitsweise.md) | wie gearbeitet wird und warum |
| [technik/addon-technik.md](../technik/addon-technik.md) | Dateien, Ablauf, Formate, Grenzen im Detail |
| [technik/datenformat.md](../technik/datenformat.md) | Felder in `tools/eigene/`, `tools/data.json`, `Data.lua` |
| [technik/quellen.md](../technik/quellen.md) | Sammelwege, Belegung, Grenzen der Daten, Rechte |
| [technik/entwicklung.md](../technik/entwicklung.md) | Einrichten, Prüfen ohne Spiel, Ablauf |
| [technik/api-befunde.md](../technik/api-befunde.md) | was die Forever-API kann, im Spiel geprüft |
