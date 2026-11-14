# Konzept: Ziele, Modelle, Entscheidungen

Das Nachschlagewerk für den roten Faden: **was** das Addon sein soll, **wie** es gedacht ist und **warum** es so entschieden wurde. Stand 10.11.2026. Wie es gebaut ist, steht in [addon-technik.md](../technik/addon-technik.md); dieses Dokument verweist dorthin und auf den Code, statt ihn zu wiederholen. Die Anwender-Sicht steht in der englischen Anleitung [guide.md](../guide/guide.md).

Wer etwas ändert, prüft hier zuerst, ob es einer Entscheidung widerspricht. Entscheidungen werden nicht stillschweigend umgedreht; neue kommen hierher und nach [entscheidungen.md](entscheidungen.md) (dort mit Datum und Wortlaut).

**Inhalt:** [1 Zweck und Leitbild](#1-zweck-und-leitbild) · [2 Grundsätze](#2-grundsätze-in-dieser-rangfolge) · [3 Begriffe](#3-begriffe) · [4 Daten: woher, wohin](#4-daten-woher-wohin) · [5 Die zwei Modi](#5-die-zwei-modi) · [6 Status eines Tiers](#6-status-eines-tiers) · [7 Fortschritt](#7-fortschritt) · [8 Fundorte](#8-fundorte) · [9 Fährten](#9-fährten) · [10 Belegung](#10-belegung-was-gilt-als-wahr) · [11 Lernstand](#11-lernstand) · [12 Teilen](#12-teilen-im-spiel) · [13 Oberfläche](#13-oberfläche) · [14 Verworfen und zurückgestellt](#14-verworfen-und-zurückgestellt) · [15 Arbeitsweise](#15-arbeitsweise) · [16 Meilensteine und Stand](#16-meilensteine-und-stand) · [17 Wo was steht](#17-wo-was-steht)

## 1 Zweck und Leitbild

**Zweck:** Jäger in WoW Forever lernen Pet-Fähigkeiten von Tieren. Das Addon sagt, **welches Tier welchen Rang lehrt und wo es lebt**, und führt den Lernstand.

**Leitbild „Zähmen als Spiel“** (15.10.2026). Das ist der Kern, an dem sich alles ausrichtet:

- **Alles finden, alles katalogisieren.** Jede Fähigkeit, jeder Rang, jedes Lehrtier, jeder Fundort.
- **Suchen und Sammeln soll Spaß machen und belohnt werden**, auch wenn es für Raid-Spieler unnötig ist. Das unterscheidet das Addon von anderen.
- **Lücken sind Aufgaben, keine Schwäche.** Was niemand kennt, kann man entdecken. Daraus sollen später Erfolge werden („Pionier: 10 Tiere gefunden, die die Daten deiner Version noch nicht kannten“, siehe §7).
- **Was man nicht kennt, sucht man nicht.** Das Addon verrät deshalb im Entdeckermodus, *dass* und *wie viel* es zu finden gibt, aber nicht *was*.
- **Ziel des Spiels ist „Tier studiert“** (17.10.2026, bis #171 „Fähigkeiten bekannt“): Nur das deckt Lehrtiere und Ränge auf. Fährte und Fund sind Schritte dorthin; der Fund lässt seit #176 schon den Zähler „Tiere“ wachsen, damit auch dieser Schritt sichtbar belohnt wird.
- **Nebenbei werden alte Jäger-Fähigkeiten sinnvoll:** „Wildtiere aufspüren“, „Adlerauge“ und „Augen des Wildtiers“ bringen Fährten – in WoW eher Nebensache, hier Werkzeuge der Suche.
- **Das Classic-Gefühl zurückholen,** wo der Forever-Client es schlechter macht (Beispiel: Ansicht „Ausbildung“).

**Warum nur eigene Daten:** In frühen Entwicklungsständen stammten Daten aus fremden Quellen, deren Bedingungen das Weiterverbreiten nicht erlaubten oder deren Rechte sich nicht zweifelsfrei klären ließen. Dieser Bestand wurde vollständig verworfen. Seit 15.10.2026 enthält das Addon nur, was im Spiel selbst erhoben wurde, und was der Client zur Laufzeit liefert. Aus der Not wurde das Spielprinzip: Die Lücken füllen die Spieler.

## 2 Grundsätze (in dieser Rangfolge)

1. **Nur eigene Daten und Client-Daten.** Keine fremden Datenquellen – nie im Repo, nie im Addon, auch nicht als Herkunftsangabe in Texten. Nichts aus fremden Addons (Code oder Tabellen). Lizenz: MIT für Code, erhobene Daten (auch von anderen Spielern geteilte) und Logo.
2. **Wenig Verkehr, wenig Speicher, wenig Rechenzeit – vor Komfort** (16.10.2026). Das Teilen darf nicht ausarten: so wenig wie möglich, so viel wie nötig. Auf einen Gruß aus dem Kanal antworten deshalb im Schnitt nur ein bis zwei Spieler, egal wie viele online sind, und eigene Meldungen gehen vor Antworten (#52). Gezählt wird bei Bedarf (beim Öffnen einer Ansicht), nicht im Hintergrund.
3. **Eigenes zählt sofort, überall** (16.10.2026). Was man selbst sichtet, zähmt oder erhebt, gilt im Addon sofort, nicht erst nach dem Import in die mitgelieferten Daten. Neue Stellen lesen nie nur `D.beasts`, `D.families` oder `a.teach`, sondern nehmen die Helfer, die Daten und eigene Funde zusammenführen ([§4](#zur-laufzeit-daten-und-eigene-funde-zusammen)).
4. **Nicht spoilern.** Wer entdecken will, bekommt nichts verraten – das Addon fragt jeden Charakter beim ersten Start und zeigt bis dahin nichts.
5. **Barrierefreiheit:** Kein Zustand nur über Farbe, immer auch ein Wort oder Symbol.
6. **Gleiches sieht gleich aus und ist gleich** (Regel für immer, 16.10.2026). Derselbe Zustand bekommt überall dasselbe Element, Wort und Symbol; neue Ansichten nehmen vorhandene Bausteine (Kästchen aus „Fähigkeiten“, `ns.FamilyIcon`, `ns.StatusWord`, `ns.TeachText`).
7. **Knapp.** Keine Erklärtexte in Listen und Tooltips; Markierungen sind ein Wort oder „?“ / „!“. Erklärt wird in den Einstellungen und im Startdialog. Ausnahmen: der Erklär-Tooltip am Zähler „Tiere“ (dort sucht man es), der Tooltip an der Modusanzeige (#42, ausdrücklich gewünscht), die Zeile für Tiere, deren Lehre noch niemand kennt (#23, sonst wirkt das Tier, als könne es nichts), und im Entdeckermodus die Hinweise im Reiter „Gebiet“, was als Nächstes zu tun ist (ganze Sätze im Tooltip der Zeile und auf der Karte, #175; Rückmeldungen der Spieler, #186: viele verstanden nicht, was sie tun sollen).
8. **Nicht raten.** Was niemand weiß, sagt das Addon („Keine Daten“ mit rotem X, „Fundort unbekannt“). Keine Wahrscheinlichkeiten, keine Hochrechnung aus Familie und Stufe.

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
| **Lernstand: hast du / fehlt dir** | ob der Jäger einen Rang hat; „hat dein Pet“, wenn nur das aktive Pet ihn hat. Jeder Zustand nennt, wen er meint (#77); beim Tier heißt der Zustand „Tier studiert“ (bis #171 „Fähigkeiten bekannt“) | `ns.IsKnown`, `ns.char.known` |
| **Komplett-/Entdeckermodus** | was angezeigt wird (alles / nur Eigenes), je Charakter | `ns.Discovering()` |

## 4 Daten: woher, wohin

### Sammelwege im Spiel

| Weg | Auslöser | Liefert |
| --- | --- | --- |
| **Erhebung** | Wildtierausbildung öffnen, Tierausbilder besuchen, Pet rufen | Fähigkeiten, Ränge (Zauber-ID), Pet-Stufe, Kosten, Familien; Familien-Icon (`GetPetIcon`) |
| **Sichtung** | Ziel, Maus, Namensplakette; außerhalb Kampf und Instanz | Fährte (jede Entfernung), Stammdaten (28 m), Fundort (10 m) |
| **Witterung** | Maus über einem Punkt von „Wildtiere aufspüren“ auf der Minikarte | Fährte (über den Namen zugeordnet) |
| **Zähmen** | „Wildtier zähmen“ gelingt | Zauber-IDs, Stufe, Tempo, Fundort (immer), Fährte |
| **Fremde Ränge** | eine fremde Zähmung zeigt einen unbekannten Zauber (#103) | Name und Rang vom eigenen Client |
| **Lernmeldung, Ausbildungsfenster** | „Ihr habt einen neuen Zauber erlernt“, Wildtierausbildung | Lernstand des Jägers |

Wildtierkunde zeigt in Forever keine Fähigkeiten (an Blizzard gemeldet) und taugt deshalb nicht zum Sammeln; ihr Icon ist trotzdem das Addon-Icon.

### Ablage

Kontoweit in `ForeverHunterPetsDB` (`survey`, `sights`, `obs`, `loc`, `locIn`, `seenIn`, `trackNames`, `myReps`, `spellNames`), je Charakter in `ForeverHunterPetsCharDB` (`known`, `discover`, `modeChosen`, `shareFinds`, `filters`, dazu die eigenen Funde `seenIn` und `loc`). Gesammelt und geteilt wird kontoweit; im Entdeckermodus zählen die Funde des Charakters, auf Wunsch die des Kontos (#43). Der Modus gilt je Charakter. Formate in [addon-technik.md](../technik/addon-technik.md).

### Vom Spiel ins Repo

```
SavedVariables ──tools/import-observations.mjs──> tools/eigene/*.json ──build-data.mjs──> tools/data.json ──build-addon.mjs──> Data/Data.lua
```

Jeder Eintrag in `tools/eigene/` braucht einen Beleg. Der Generator rechnet die Belegung ([§10](#10-belegung-was-gilt-als-wahr)) und bricht ab, wenn ein Beleg fehlt. `tools/data.json` und `Data/Data.lua` sind generiert und werden nie von Hand bearbeitet. Fremde Fundort-Zellen werden je Melder gespeichert und wie Zähmungen und Sichtungen ab 3 Meldern ausgeliefert (#2), fremde Ränge ebenso (#103).

### Zur Laufzeit: Daten und eigene Funde zusammen

Die mitgelieferten Daten sind nur ein Teil. Was das Addon zeigt, setzt sich zusammen – und genau dafür gibt es Helfer, die immer zu nehmen sind:

| Frage | Helfer | Quellen |
| --- | --- | --- |
| Welche Fähigkeiten und Ränge gibt es? | `ns.MergeSurveyAbilities` (beim Einloggen und nach jeder Erhebung; Zwischenspeicher über `ns.OnAbilitiesChanged`) | Daten + eigene Erhebung + fremde Ränge bekannter Fähigkeiten ab 3 Meldern (`ns.ForeignRankCandidates`, #103) |
| Stufe, Familie, Einstufung eines Tiers | `ns.BeastInfo`, `ns.BeastFamily` | Daten → Sichtung (`ns.TrustedSighting`) → Zähmung → Fernname; Sichtung und Zähmung je eigene sofort, fremde ab 3 Meldern (#103) |
| Name eines Tiers | `ns.BeastName` | eigene Sichtung (Client-Sprache) → Daten → Fernname → fremde Sichtung ab 3 Meldern, die genau diesen Namen nennen (#103) → „Unbekanntes Tier (#ID)“ |
| Name und Icon einer Familie | `ns.FamilyName`, `ns.FamilyIds`, `ns.FamilyIcon` | Daten → Erhebung → Ersatz-Icon „Wildtier zähmen“ |
| Lehrtiere eines Rangs | `ns.Teachers`, `ns.ObservedTeachers` | Daten + Zähmungen (eigene und geteilte) |
| Was lehrt ein Tier? | `ns.TeachInfo(npc, discover)`, `ns.Studied` | Daten + alle Zähmungen; im Entdeckermodus erst, wenn das Tier studiert ist (#169) |
| Fundorte, Zonen | `ns.Coords`, `ns.ZoneCounts`, `ns.BeastZones` (gezeigt), `ns.BeastZonesAll` (gezählt, #193), `ns.TamedZones` | Daten + Zellen (fremde ab 3 Meldern je Tier und Karte, `ns.ForeignCellsOk`) + eigene Zähmungen |

Anlass für den Grundsatz: Ein gezähmter Kojote fehlte bei „Beißen 2“, ein Junger Fleischreißer „brachte keine Fähigkeit mit“ – beides, weil nur die mitgelieferten Daten gelesen wurden.

## 5 Die zwei Modi

Wortlaut des Nutzers (17.10.2026), maßgeblich:

> „Komplettmodus will nichts suchen. Da soll alles was bekannt ist immer vollständig präsentiert werden, auch wenn das von anderen Spielern oder den Stammdaten kommt. Was der Spieler noch nie gesehen oder gezähmt hat ist im Komplettmodus völlig irrelevant. Ganz im Gegenteil zum Entdeckermodus. Da zählt im Gegenteil dazu nur das, was der Spieler wirklich gesehen und gezähmt und entdeckt hat. Die Stammdaten und die Daten anderer Spieler dienen dann nur als Quelle für das Grundgerüst was man sehen muss damit man danach sucht, z.B. die Fortschrittsbalken. Da sollen dann auch Tiere als ‚Unbekanntes Tier‘ in der Liste des Gebiets auftauchen und Statusbalken angezeigt werden. Damit man eben danach auch sucht. Alle Tiere nur anonymisiert quasi. Bis man eine Fährte hat. Ab da dann mit Namen und Status Tag.“

| Stelle | Komplettmodus | Entdeckermodus |
| --- | --- | --- |
| Lehrtiere, Namen, Fundorte | alles Bekannte | nur Eigenes; ab „Tier studiert“ dieselben Daten wie im Komplettmodus (#169) |
| Grundgerüst | – | alle Fähigkeiten und Ränge (Spielwissen), **wie viele** Lehrtiere und Tiere es gibt |
| Fähigkeiten, Liste und Details | alle Lehrtiere | selbst gezähmte, bei jedem Rang, den sie nach den Daten lehren (#169); die übrigen als „N noch nicht studiert“ bzw. „verborgenes Tier“; Zonenauswahl und Ränge je Zone nach den kompletten Daten wie im Reiter „Gebiet“ (#193) |
| Karte (Gebiet, Kartenseite) | alle Fundorte | eigene Zellen; ist das Tier in der Zone studiert, dort alle bekannten Fundorte (#170) |
| Tier-Tooltip | Ränge aus allen Daten, kein Status | Status-Tag; bei „Tier gefunden“ „lehrt etwas“ bzw. „lehrt nichts“ (#173); nach der eigenen Zähmung Ränge aus allen Daten (#169) |
| Reiter „Gebiet“, Liste | alle Tiere benannt, anklickbar, kein Status | alle anklickbar (#175); anonym bis zur Fährte, dann Name und Status-Tag; ab „Tier gefunden“ „lehrt etwas“ bzw. „lehrt nichts“, ab „Tier studiert“ die Lehre (#173); Hinweise, was als Nächstes zu tun ist, im Tooltip der Zeile und auf der Karte (#175) |
| Reiter „Gebiet“, Fortschritt | Stand des Datensammelns | eigener Stand |
| Ausbildung | unverändert | unverändert |
| Sammeln und Teilen | an | an |

- **Dieselben Daten, nur das Wann ist anders** (Maintainer, 13.11.2026, Epic #186): Auch im Entdeckermodus sind die kompletten Daten die Grundlage – Stammdaten, fremde Meldungen ab 3 Meldern und eigene Funde, mit denselben Einstellungen zur Belegung. Der Modus entscheidet nur, *wann* etwas erscheint; das hängt von der Entdeckung ab, je Zone. Hat man ein Tier selbst gezähmt (`ns.Studied`, NPC-ID), zeigt es seine Lehre aus den kompletten Daten, auch in anderen Zonen ab der Fährte (#169). Bis 1.2.0 zeigte der Entdeckermodus nur, was die eigene Zähmung zeigte; ein Tier, das man auf niedriger Stufe zähmte, verschwieg so für immer die Ränge, die es erst höher mitbringt.
- **Modus und Funde je Charakter** (#43, 20.10.2026; vorher Funde je Konto). Jeder Charakter wählt seinen Modus und entdeckt im Entdeckermodus alles selbst. Die Unteroption „Funde anderer Charaktere“ (Standard aus, je Charakter) zählt die Funde des ganzen Kontos, wie bis 0.10.0. Gesammelt und geteilt wird weiter kontoweit; jeder Charakter merkt sich seine Fährten und Zellen zusätzlich selbst, eigene Zähmungen erkennt er an seinem Kürzel. Die Funde bis 0.10.0 tragen keinen Charakter: Sie übernimmt einmal der Hauptcharakter, der mit den meisten eigenen Sichtungen und Zähmungen.
- **Der Entdeckermodus ist der Standard, aber keine Empfehlung mehr** (Maintainer, 13.11.2026, #177, Epic #186; vom 20.10.2026 bis #177 „der empfohlene und der Standard“, #42). Die Startansicht stellt beide Modi gleichrangig nebeneinander vor, je mit Icon (Fernrohr, Buch), einer ehrlichen Beschreibung und einem Knopf; darunter ein Hinweis, dass die Daten noch gesammelt werden. Wer die Ansicht ohne Wahl schließt, spielt im Entdeckermodus; auch „Standard wiederherstellen“ in den Einstellungen ergibt ihn. Werben darf das Addon weiter: Der Tooltip der Modusanzeige im Komplettmodus lädt ein, den Entdeckermodus auszuprobieren (Maintainer, 14.11.2026).
- **Startdialog** beim ersten Öffnen je Charakter; bis zur Wahl zeigt das Addon nichts, was spoilern könnte (Tooltip leer), sammelt aber. Bis 0.13.0-beta mit einem Absatz zur Beta (ermutigend: Lücken warten darauf, entdeckt zu werden), mit 1.0.0 entfernt. Umschaltbar in den Einstellungen und mit `/fhp modus` (#179: vor dem Komplettmodus eine Rückfrage, weil er alles verrät; zurück ohne; nur in der Hilfe erwähnt, nicht beworben). Der aktuelle Modus steht klein oben rechts vor dem Zahnrad; Hover erklärt ihn (im Komplettmodus mit „Probier doch mal den Entdeckermodus aus.“, ohne Empfehlung, #177), Klick öffnet die Einstellungen.
- **Tour beim ersten Öffnen im Entdeckermodus** (Maintainer, 13.11.2026, #178, Epic #186; Rückmeldungen der Spieler: viele verstanden nicht, was sie tun sollen): Sieben Sprechblasen zeigen, wo was steht – Liste, Kästchen, Karte, Zähler im Reiter „Gebiet“, dann „Fähigkeiten“ und „Ausbildung“. Die Hinweissätze aus #175 wiederholt sie nicht, sie zeigt, wo sie stehen. Einmal je Account (Maintainer, 14.11.2026: die Oberfläche ist für alle Charaktere gleich, Twinks sollen sie nicht erneut sehen), auch für bisherige Spieler einmal nach dem Update; jederzeit abbrechbar (X, ESC, Fenster schließen); `/fhp tour` zeigt sie erneut, nur in der Hilfe erwähnt.
- **Zwei Wörter für Lücken:** „Keine Daten“ mit rotem X – das weiß niemand (beide Modi, überall derselbe Text, `ns.NoData`, #172; bis dahin „? unbekannt“ in „Fähigkeiten“ und „? unklar“ in „Gebiet“; zuerst „Keine Daten bekannt“, das schnitt die Zeilen in „Gebiet“ ab, Maintainer, 13.11.2026, beim Test von #197). Im Tier-Tooltip sagen es stattdessen die goldenen Zeilen (#23, #40). „Noch nie gesehen“ mit Fragezeichen-Icon – es ist bekannt, du hast es nur noch nicht gefunden (nur Entdeckermodus; in der Liste als „verborgenes Tier“, bis #171 „? unentdeckt“, weil das zu nah an „? unbekannt“ lag). X und Fragezeichen unterscheiden sich in der Form; vor „Keine Daten“ steht kein „?“, damit es niemand für einen Status hält. „Fundort unbekannt“ (Karte) und die Quelle „Unbekannt“ (Fähigkeiten) bleiben ohne X: Sie tragen kein „?“ und werden nicht mit einem Status verwechselt (Maintainer, 13.11.2026).
- **Der Fund verrät, *ob* ein Tier etwas lehrt** (Maintainer, 13.11.2026, #173): Bei „Tier gefunden“ steht „lehrt etwas“ bzw. „lehrt nichts“, aus den kompletten Daten mit denselben Einstellungen zur Belegung (`ns.TeachSummary`); weiß niemand etwas, „Keine Daten“, im Tier-Tooltip die goldenen Zeilen wie im Komplettmodus. *Was*, bleibt dem Zähmen. Ein Tier, das nur ein Angriffstempo mitbringt, gilt als „lehrt etwas“, passend zum Zähler und zu dem, was nach dem Studieren dasteht. Sind alle Angaben unsicher, steht „lehrt etwas?“ wie „lehrt nichts?“ (#136). Bei der Fährte steht nichts (bis #173 „? unklar“), außer das Tier ist anderswo studiert: Dann steht seine Lehre schon da, sie hängt an der NPC-ID.
- **Tipp Namensplaketten:** ein Satz am Ende der Moduswahl in den Einstellungen, bewusst unauffällig (nicht jeder mag Plaketten).

## 6 Status eines Tiers

Nur im Entdeckermodus. Im Komplettmodus gibt es keinen Status.

| Status (Code) | Tag | Wann | Kästchen |
| --- | --- | --- | --- |
| `unknown` | **Noch nie gesehen**; in der Liste anonym als „verborgenes Tier“ | noch nichts in dieser Zone | keins |
| `track` | **Fährte aufgenommen** | in dieser Zone gesehen, nie nah gewesen | leer |
| `found` | **Tier gefunden** | eigene Zelle in dieser Zone (jede Zähmung speichert eine) | Punkt |
| `known` | **Tier studiert** | gefunden und selbst gezähmt (`ns.Studied`), auch wenn es nichts lehrt | Haken |

- **Kästchen je Stufe** (Maintainer, 13.11.2026, #174; vorher erst ab „Tier gefunden“ leer, mit Haken bei „Tier studiert“): Jede Stufe hat im Reiter „Gebiet“ ihre eigene Form – nichts, leer, Punkt, Haken –, nicht nur eine Farbe. Der Punkt ist die runde Scheibe der Karten-Pins im Goldgelb des Hakens (`box.dot` in `W.CheckBox`, Scheibe `W.DISK`); „Fähigkeiten“ nutzt ihn nicht, das Lernstand-Kästchen bleibt, wie es ist. Der Tooltip am Zähler „Tiere“ nennt je Status sein Kästchen. Im Komplettmodus unverändert: leer, Haken, wenn bekannt ist, was das Tier lehrt.
- **Je NPC-ID und je Zone.** Jede Zone ist ein eigenes Jagdrevier; ein Tier, das über eine Grenze läuft, muss in jeder Zone selbst gefunden werden. Innerhalb einer Zone reicht ein Tier dieser ID.
- **Gefunden nur mit eigener Zelle** (Maintainer, 13.11.2026, #170): „Tier gefunden“ und „Tier studiert“ hängen in einer Zone an einer eigenen Zelle dort; eine einzige genügt für die ganze Zone. Eine Zähmung anderswo plus eine Fährte hier reicht nicht. Dann steht hier „Fährte aufgenommen“, die Lehre ist aber schon da (#169).
- **Was ein Tier lehrt, gilt zonenübergreifend:** Die Fähigkeiten hängen an der NPC-ID, nur der Rang an der Stufe. „Bekannt“ wird ein Tier in einer Zone trotzdem erst, wenn es dort gefunden ist.
- **Wo lebt ein Tier?** (`ns.LivesIn`) Wo es einen echten Fundort hat: Daten, Zelle oder eigene Zähmung. Hat es nirgends einen, zählt seine Fährte, wo man es gesehen hat ([§9](#9-fährten)).
- **Wörter:** Jäger-Sprache, als Zustand formuliert, ohne Icon. Verlauf: „Fährte“ mit Pfoten-Icon, dann „gesichtet / gefunden / bekannt“ – zu nah beieinander, der Unterschied war unklar; seit 13.11.2026 (#171) „Noch nie gesehen“ statt „? unentdeckt“ und „Tier studiert“ statt „Fähigkeiten bekannt“, weil das beschreibt, was der Spieler getan hat. „Tier studiert“ ist in allen Punkten gleich „gezähmt“ (später auch über Wildtierkunde, #183). Im Code heißen die Status weiter `unknown`, `track`, `found`, `known`. Texte: `ns.StatusWord`, `ns.StatusText` (liefert im Komplettmodus `nil`).
- **„lehrt nichts“** steht grau im Tooltip, wenn feststeht, dass ein Tier nichts lehrt (sonst fehlte jeder Hinweis); folgt der Einstellung „Auch Ränge zeigen, die du hast“. „Kein Lehrtier in den Daten“ heißt allein nie „lehrt nichts“ – das klärt erst eine Zähmung; bis dahin „Keine Daten“ (#172, vorher „? unklar“). Im Entdeckermodus erscheint das ab „Tier gefunden“ zusammen mit „lehrt etwas“ (#173); bei der Fährte steht nichts.

## 7 Fortschritt

`ns.ZoneProgress(map)`, angezeigt im Reiter „Gebiet“. Y aus allem Bekannten (Daten, Zellen, Zähmungen, Fährten), X je Modus:

| Zähler | Y | X Entdeckermodus | X Komplettmodus |
| --- | --- | --- | --- |
| Tiere | Tiere der Zone | gefunden oder studiert (`found`, `known`, #176) | irgendwer weiß, was es lehrt |
| Lehrtiere | Tiere der Zone, die etwas lehren | selbst studiert | alle |
| Fähigkeiten | Ränge, die ein Lehrtier der Zone lehrt | von studierten Tieren entdeckt | alle |
| Fundorte | – | was die Karte zeigt: eigene Zellen, bei studierten Tieren alle Fundorte (#170) | alle Fundorte |

- **Der Zähler „Tiere“ zählt ab „Tier gefunden“, Lehrtiere und Ränge ab „Tier studiert“** (Maintainer, 13.11.2026, #176, Epic #186; vom 17.10.2026 bis #176 trieb nur „Tier studiert“ den Fortschritt, und der Tiere-Balken bewegte sich erst mit dem Zähmen). Die Fährte zählt nirgends. Im Code bleibt `beastsKnown` das X des Zählers „Tiere“.
- **Zähler als ganze Sätze** (#176): Links stehen die kurzen Titel („Tiere“, „Lehrtiere“, „Fähigkeiten“), daneben ein Satz, der umbrechen darf; Kacheln und der nächste Zähler rücken um seine Höhe nach unten. Entdeckermodus: „Du hast 5 von 22 Tieren gefunden“, „Du hast 2 von 11 Lehrtieren studiert“, „Dabei hast du 3 von 8 Rängen entdeckt“. Komplettmodus: „Bei 15 von 22 Tieren ist bekannt, was sie lehren“, „11 von 11 Lehrtieren sind bekannt“, „8 von 8 Rängen sind bekannt“. Bei den Rängen heißt es „entdeckt“ wie in der Meldung und auf den Kacheln, nicht „studiert“: Studiert wird das Tier, dabei entdeckt man seine Ränge (Maintainer, 14.11.2026, beim Test; der erste Entwurf „Sie lehren 8 von 8 Rängen dieses Gebiets“ las sich holprig, „dieses Gebiets“ sagt schon die Gebietsauswahl). „gelernt“ bleibt dem Lernstand vorbehalten; „entdeckt“ passt zur Meldung „Entdeckt: …“. Vorher „X von Y bekannt / identifiziert / Rängen entdeckt“.
- **Meldung „Entdeckt“** (20.10.2026, #51): Der Fortschritt wächst nur beim Zähmen, und genau dann sagt es der Chat – sonst bliebe der wichtigste Moment des Sammelspiels unbemerkt, bis man den Reiter öffnet. Nur im Entdeckermodus, eine Zeile unter „Beobachtet“, für die Zone, in der man zähmte: neue Rang-Kacheln („Entdeckt: Beißen Rang 3 – Dämmerwald: 5 von 12 Rängen“), sonst das Tier, das studiert wurde („Entdeckt: Wolf studiert – Brachland: 4 von 9 Tieren studiert“; die Zahl sind die studierten Tiere der Zone, nicht der Zähler „Tiere“, der seit #176 ab dem Fund zählt); nichts Neues, keine Zeile. Ein Fund meldet sich nicht. Die Zahlen kommen aus derselben Zählung wie im Reiter (`ns.ZoneProgress` vorher und nachher). Der Zonenname steht vorne, weil deutsche Zonen sonst je einen eigenen Artikel bräuchten. Wird das Tier dadurch auch in einer anderen Zone bekannt, sagt das nur der Reiter. Fährten melden sich weiter nicht (sonst liefe der Chat voll).
- **Neues ist eine gute Nachricht** (21.10.2026, #66): Y wächst auch durch andere (fremde Zellen und Zähmungen, neue Stammdaten), und aus „8 von 8“ wird still „8 von 9“. Damit das nicht wie ein Rückschritt wirkt, steht im Entdeckermodus über den Tieren einmal „+ Seit du zuletzt hier nachgesehen hast, haben andere Jäger 1 neues Tier entdeckt – die Jagd geht weiter.“ Gemerkt werden je Charakter und Zone die Tiere vom letzten Nachsehen (`ForeverHunterPetsCharDB.zoneSeen`), gezählt nur Tiere, die man selbst nicht gefunden hat (Status „unknown“); nur Tiere, keine Ränge, denn neue Ränge kommen auch aus eigenen Zähmungen. Beim ersten Besuch einer Zone wird nur gemerkt. Die Zeile bleibt, bis man eine andere Zone wählt oder das Fenster schließt. Ein Übergang: Wenn alle Tiere bekannt sind, kommt sie nicht mehr.
- **Erfolge hängen an eigenen Funden** (10.11.2026, #65, für E8). Ein Erfolg zählt, was man selbst gefunden hat („10 Lehrtiere selbst identifiziert“). „Pionier“ heißt „nicht in den Daten der installierten Version“: Ob ein Tier wirklich noch niemand kannte, kann das Addon ohne Server nicht wissen, es kennt nur die ausgelieferten Daten und das eigene Konto. Dabei bleibt eine Spannung, die gewollt ist: Das Projekt will die Lücken schließen, und jedes Release macht Pionier-Funde seltener. Eine spätere Ansicht „Erfolge“ kann den **Gesamtfortschritt über alle Zonen** ausbauen, etwa um die Ränge („12 von 80 Rängen entdeckt“, Idee aus #53); die Tiere zeigt seit #180 schon die Zonenauswahl (siehe unten).
- **Ein Erfolg bleibt erreicht** (21.10.2026, #66, für E8): Wird eine Zone später größer, bleibt „Alle Tiere aus Das Brachland gefunden“ erreicht. Die Zone zeigt dann „Neu in dieser Zone“ und es gibt etwas zu holen, aber nichts wird zurückgenommen.
- **Stand je Zone und Gesamtfortschritt** (Maintainer, 14.11.2026, #180, Epic #186): „Wo lohnt sich die Jagd?“ Im Entdeckermodus trägt jede Zone in der Zonenauswahl des Reiters „Gebiet“ ihren eigenen Stand, „Brachland 3/12“: gefundene von allen Tieren, dieselbe Zahl wie der Zähler „Tiere“ (gefunden und studiert, #176; die Fährte zählt nicht). Eine Zone, in der alles gefunden ist, trägt zusätzlich einen Haken, damit „fertig“ nicht nur an der Zahl hängt. Ganz oben in der aufgeklappten Liste steht eine Zeile ohne Wahl: „Alle Gebiete: 37 von 134 Tieren gefunden“. Ein Tier, das in mehreren Zonen lebt, zählt in jeder Zone; in der Summe einmal, gefunden, sobald es in irgendeiner Zone gefunden ist. Gezählt wird mit `ns.ZoneTallies` (nur Tiere und Status, nicht `ns.ZoneProgress` je Zone, das auch Lehrtiere, Ränge und Kacheln rechnet), nur wenn der Reiter neu gezeichnet wird. Die Zonen bleiben alphabetisch: Die Daten haben keine Stufe je Zone, eine abgeleitete läge bei wenigen Daten leicht daneben, und alphabetisch findet man jede Zone sofort (das Ziel „nach Stufe sortiert“ aus #180 entfiel). Im Komplettmodus kein Stand und keine Gesamtzeile: „3/12“ hieße dort „bei 3 von 12 ist die Lehre bekannt“, ein Stand des Datensammelns, kein eigener.
- **Immer „X von Y“** (18.10.2026, #19): Auch wenn alles bekannt ist, steht „8 von 8“ im Satz, bei *Tiere* mit vollem Balken – für alle drei Zähler gleich. Vorher stand bei X = Y nur „8“; über den Kacheln wirkte das wie ein kaputter Umbruch. Im Komplettmodus zeigt der Tiere-Balken, wie weit das Datensammeln ist.
- Ränge vom Tierausbilder und Ränge ohne Lehrtier in der Zone zählen nicht – die muss man dort nicht suchen.
- **Komplettmodus: Es zählt, was gezeigt wird** (20.10.2026, #40). Die Zähler und Kacheln nehmen die Lehren aus `ns.TeachInfo`, wie Liste und Tooltip. Ist „Unsichere Angaben zeigen“ aus, zählen unsichere Lehren weder in X noch in Y; X wird nie größer als Y. Vorher zählten sie mit, auch wenn die Liste sie verschwieg, und eine einzelne fremde Zähmung zählte sofort. Der Entdeckermodus bleibt: Y ist das Grundgerüst aus allen Daten.
- Zahl und Wort sind maßgeblich, der Balken nur zusätzlich. Gezählt wird beim Öffnen, Zonenwechsel und Auswählen.
- **Kacheln statt Balken** bei Lehrtieren und Fähigkeiten (18.10.2026, #19): je Lehrtier bzw. Rang eine Kachel, verborgen mit dem roten Fragezeichen der Liste, entdeckt mit dem Icon der Familie bzw. der Fähigkeit – „ich muss diese Kachel noch aufdecken“. Die Reihenfolge ist fest (NPC-ID, Fähigkeit und Rang), eine Kachel dreht sich beim Entdecken an ihrem Platz um. Höchstens zwei Zeilen, der Rest als „+n“. Fundorte stehen als Fußnote unten links.

## 8 Fundorte

- **Der Client nennt nur die Position des Spielers.** Deshalb zählt ein Fundort nur, wenn das Tier in etwa **10 m** steht (`CheckInteractDistance` 3, sonst 2), gerundet auf ein Raster von 2 % der Karte (50 × 50 Zellen, 60–100 m).
- **Genauigkeit vor Menge** (16.10.2026): Eine Anhebung auf 28 m wurde verworfen. Die Karte soll „hier ungefähr“ zeigen, nicht daneben.
- **Zähmen gibt immer einen Fundort**, vom Beginn des Zauberns: „Wildtier zähmen“ reicht nur etwa 30 m, das liegt in derselben oder der Nachbarzelle. Ältere Zähmungen ohne Zelle zählen nur dafür, wo ein Tier lebt (`ns.TamedZones`, `ns.LivesIn`), nicht als eigener Fund: Eine Zähmung speichert ihre Zone nicht, und sonst stand ein anderswo gezähmtes Tier in jeder Zone, in der man es nur von Weitem sah, als „Tier studiert“ da (#170, 13.11.2026).
- **Kampf:** Während des Kampfs ruht das Addon (geheime Werte). Fundorte entstehen trotzdem – beim Heranlaufen und danach neben dem toten Tier. Eine eigene Behandlung brachte in der Probe nichts.
- **Fernsicht:** Während „Augen des Wildtiers“ (1002) und „Adlerauge“ (6197) entstehen keine Zellen (`ns.Possessing`), weil der Jäger woanders steht als das, was er sieht. `CheckInteractDistance` misst dabei vom Jäger aus; die Sperre ist die zweite Sicherung.
- **Je Tier und Zelle einmal.** Wandernde Tiere ergeben eine Kette – für die Suche nützlicher als ein Punkt.
- **Karte:** Punkte nur für das gewählte Tier, ohne Auswahl nie (sonst hunderte). Alle Punkte sehen gleich aus, rund und rot (gold bei seltenen Tieren): Die Karte unterscheidet nicht, woher ein Fundort stammt (Maintainer, 13.11.2026, #170: „Einem Spieler sollte es egal sein, woher die Daten kommen.“). Die Karte ist so weit aufgedeckt, wie der Charakter die Zone erkundet hat – eine fremde Overlay-Tabelle wurde aus Lizenzgründen abgelehnt, und das eigene Erkunden gehört zum Suchen.

## 9 Fährten

- **Aus jeder Entfernung** (E7): Maus, Ziel, Plakette, „Adlerauge“, „Augen des Wildtiers“ und die Witterung an der Minikarte. Vorher erst ab 28 m – deshalb gab es kaum Fährten, vieles war sofort „gefunden“.
- **Auch ohne Fundort** (Nutzer: „Tiere ohne Fundorte sollen Fährten haben. Das ist ja gerade der Sinn von Fährte“). Hat ein Tier nirgends einen Fundort, zählt seine Fährte in der Zone, in der man es sah. Sobald es irgendwo einen hat, zählt es nur noch dort – eine Fährte über eine Zonengrenze hinweg verschwindet dann.
- **Name aus der Ferne:** Die Sichtung speichert erst ab 28 m. Damit ein Tier nicht „Unbekanntes Tier (#833)“ heißt, merkt sich die Fährte Name und Familie lokal (`trackNames`), **ohne zu teilen** (Verkehr). Mit der ersten Sichtung fällt der Eintrag weg.
- **Witterung** (`UI/Scent.lua`): Die Spur-Punkte auf der Minikarte zeigt der Client im GameTooltip (Besitzer `UIParent`), alle Namen in Zeile 1. Das Addon liest sie, solange der Tooltip offen und die Maus über der Minikarte ist, und gibt passenden Tieren der Zone still eine Fährte. **Angezeigt wird dort nichts** (Nutzer: zu überladen, der Tier-Tooltip reicht).
- **Fährten stehen nicht auf der Karte**, nur Fundorte.

## 10 Belegung: was gilt als wahr

| Stufe | Bedeutung | Anzeige |
| --- | --- | --- |
| belegt | eigene Zähmung, oder mindestens 3 verschiedene fremde Melder, oder ein Befund „bestätigt“ | normal |
| unsicher | 2 fremde Melder (weniger als 3), für jede Datenart (#136); was nur einer meldet, wird gespeichert, aber weder ausgeliefert noch gezeigt | aus; einschaltbar, Zeichen „?“ |
| unbelegt | nur geschätzt (noch keine Schätzungen, Schalter fehlt) | aus; Zeichen „!“ |
| widerlegt | eine Zähmung zeigte den Rang nicht, obwohl die Stufe reichte | nie |

- **Eigene Zähmungen sind Beweis**, gesehen wie nicht gesehen, und gehen allem Fremden vor. Unter Fremden geht gesehen vor widerlegt.
- **Die Fähigkeiten hängen an der NPC-ID**, nur der Rang an der Stufe. Darum widerlegt eine Zähmung ein Paar endgültig – und darum gibt es **keine Wahrscheinlichkeiten**: Was ein Tier mitbringt, ist kein Zufall. Widersprechen sich Zähmungen derselben NPC-ID, meldet der Generator das; dann wackelt die Annahme.
- **Das Zauberbuch zeigt nur den höchsten Rang:** Ein höherer Rang widerlegt keinen niedrigeren.
- **3 Melder** (17.10.2026, M5, #1): anfangs zwei, dann 10; mit einer Gilde als Spielerschaft wurde 10 kaum erreicht. Gezählt werden **Charaktere, nicht Spieler** (#64): Das Kürzel gilt je Charakter, ein Konto ist im Spiel nicht sichtbar, und wer mehrere Charaktere hat, zählt mehrfach – jeder Twink sendet unter eigenem Namen, auch die Zwei-Absender-Regel (#15) greift dann nicht. Gut genug gegen Versehen und Unsinn, nicht gegen Absicht; was in die Stammdaten kommt, entscheiden wir ohnehin beim Import (Maintainer, 10.11.2026: keine Änderung am Verhalten). Die Texte sagen deshalb „Charaktere“, wo eine Zahl von Meldern steht. Anheben, wenn es viele Spieler gibt.
- **Eine Regel für alles** (23.10.2026, umgesetzt mit #103): Alles, was wir selbst sammeln, sammeln auch andere, und Fremdes gilt erst ab 3 Meldern über mindestens zwei Absender (#15) – Lehrtier-Paare, Fähigkeiten und Ränge, Tiernamen, Familie, Einstufung und Stufen aus Sichtungen und Zähmungen, Fundort-Zellen in den Stammdaten **und im Spiel** (gezählt je Tier und Karte; darunter erscheint ein Tier weder in *Gebiet* noch in „X von Y“). *Unsicher* ab 2 Meldern gilt seit #136 für jede Datenart, nur im Spiel und nur mit „Unsichere Angaben zeigen“, gekennzeichnet mit „?“ direkt hinter dem Wert („Name?“, „Stufe 12?“, „Bär?“, „Rang 5?“, „lehrt nichts?“); es zählt dann in „X von Y“ mit. In die Stammdaten kommt Unsicheres nur als Lehrtier-Paar, sonst gelten sie als belegt (#124). Das Angriffstempo ist eine Fähigkeit wie jede andere, zählt aber nur nach dem Zauberbuch einer Zähmung, nie nach einem gemessenen Wert (#189: Buffs des Jägers verfälschen ihn): Fremde Zähmungen mit dem Tempo-Zauber gelten ab 2 unsicher, ab 3 belegt; einen neuen Tempo-Zauber legt das Addon nur aus einer eigenen Zähmung zur Laufzeit an, mit dem Tempo aus seiner Beschreibung. Beide Zahlen stehen an je einer Stelle (`ns.FOREIGN_SURE`, `ns.FOREIGN_UNSURE` in `Core/Init.lua`, dieselben oben in `tools/build-data.mjs`), weil sie mit der Zahl der Spieler steigen sollen.
- **Fremde Ränge** (#103): Eine fremde Zähmung mit einem Zauber, den noch keine Fähigkeit kennt, wird über den eigenen Client in Name und Rang aufgelöst. Im Spiel wird daraus nur ein **neuer Rang einer bekannten Fähigkeit**, die man von Tieren lernt, ab 3 Meldern belegt, ab 2 unsicher (#136). **Ganz neue Fähigkeiten kommen nur über die Stammdaten**, nach Durchsicht beim Import (Abbruch bei neuen Fähigkeiten #37, Prüfung auf Jägerzauber): Das Addon kann einen Jägerzauber oder Unsinn nicht von einer Pet-Fähigkeit unterscheiden. Ein solcher Rang hat keine Pet-Stufe und keine TP, bis jemand die Wildtierausbildung öffnet, und **ein Rang ohne Pet-Stufe widerlegt nichts**.

## 11 Lernstand

- **Aus Sicht des Jägers.** „fehlt dir, erreichbar / fehlt dir, außer Reichweite / hast du“ meinen den Jäger, nicht das Pet. Was das aktive Pet lernen kann, zeigt nur „Ausbildung“.
- **Erreichbar in beiden Modi gleich** (13.11.2026, #192): Im Entdeckermodus zählen für „fehlt dir, erreichbar“ auch die noch nicht studierten Lehrtiere. Der Filter verrät damit nur, *dass* es auf der eigenen Stufe etwas zu finden gibt, nicht *was*: In den Details bleibt es bei „verborgenes Tier“ ohne Stufe und Familie. Vorher zählten nur studierte, also selbst gezähmte Lehrtiere, deren Ränge man meist schon hat; fast jeder fehlende Tier-Rang stand so „außer Reichweite“.
- **Ränge einzeln:** Rang 3 schließt Rang 2 nicht ein (Korrektur vom 21.09.2026). Gespeichert je Zauber-ID.
- **Was das Pet kann, ist nicht gelernt** (0.2.1). Ein verfrühter Haken ist gefährlicher als ein fehlender – man ließe das Tier zu früh frei. Angezeigt wird stattdessen „hat dein Pet“.
- **Quellen:** Wildtierausbildung (Zauber-ID über den Tooltip der Zeile) und Lernmeldung (trägt die ID eines Jäger-Zaubers, zugeordnet über Name und den Rang, den das Pet schon hat).
- **Gesammelt, nie von selbst entfernt:** Die Ausbildung zeigt nur die Familie des aktiven Pets; ein fehlender Eintrag heißt nichts.
- **Von Hand nur mit „Manuelles Editieren“** (Standard aus) – das Kästchen war zu leicht aus Versehen gesetzt.
- **Ausbilden bleibt im Blizzard-Fenster:** Der Client sperrt das Lehren aus Addons; das Addon öffnet das Fenster nur. Trainingspunkte: nur die Differenz zum vorhandenen Rang zählt.

## 12 Teilen im Spiel

- **Warum im Spiel:** Addons kommen nicht ins Internet. Daten wandern als Addon-Nachrichten über Gilde und Gruppe zwischen Spielern, die gleichzeitig online sind; Antworten auf Grüße per Flüstern. Ein Gruß nach dem Einloggen und beim Beitritt in eine Gruppe holt Neues von anderen; wer in einer Gruppe oder per Flüstern gegrüßt wird, grüßt einmal zurück, damit der Austausch in beide Richtungen geht (#156).
- **Kein Kanal mehr** (10.11.2026, #153): Bis 1.1.0 lief der Austausch über Gilde und Gruppe hinaus über den verborgenen Kanal `FHPetsNet`. Seit dem Start von Forever lehnt der Server Addon-Nachrichten darin ab; in der Beta ging es noch. `YELL`, das andere Addons in Classic-Clients statt eines Kanals nehmen, lehnt der Forever-Client ab. Es bleiben Gilde, Gruppe und Flüstern; Spieler außerhalb davon erreicht das Addon vorerst nicht. Seit #154 erreicht das Addon andere Jäger über die Wer-Liste: `/fhp suchen` (oder ein eigenes `/who`) grüßt jeden Jäger darin einmal je Sitzung per Flüstern, nur auf Befehl des Spielers, nie im Hintergrund. Ganz aufgegeben sind beide nicht (#158): `YELL` prüft das Addon einmal je Sitzung und nutzt es, sobald der Client es wieder annimmt; den Kanal prüft der Selbsttest `/fhp teilen test` von Hand, ohne ihn dauerhaft zu betreten. Das Addon verlässt den alten Kanal beim Einloggen; damit ist auch #149 (der Kanal auf Platz 1) erledigt.
- **Was:** Zähmungen (`O1`), Sichtungen (`S1`), Fundort-Zellen (`F1`), Gruß (`H1`). Nicht geteilt: Fährten, Fernnamen, Status, Lernstand.
- **Alle eigenen Charaktere:** Was ein Twink zähmt, sichtet oder findet, zählt beim Konto als eigen und geht in jeder Antwort auf einen Gruß mit, auch über die Gilde eines anderen Charakters (Sichtungen seit #157). So tragen Twinks auf anderen Realms oder bei der anderen Fraktion ihre Daten weiter.
- **Sparsam:** gedrosselt (eine Nachricht je 2 s, Bündel alle 5 Minuten), nur was die Daten noch nicht kennen, Obergrenzen für Gespeichertes. Einzelheiten und Zahlen in [addon-technik.md](../technik/addon-technik.md).
- **Datenschutz:** Statt Namen ein Kürzel (Hash); gespeichert werden nur Kürzel. Die eigenen stehen in `myReps`, damit eigene Meldungen als eigene zählen. Das Kürzel ist pseudonym, nicht anonym; Geteiltes kann unter MIT in die Stammdaten kommen, darauf weisen README und Anleitung hin ([entscheidungen.md](entscheidungen.md), 17.10.2026). Im öffentlichen Repo stehen fremde Einträge seit #48 mit gesalzenem Kürzel und nur dem Tag (20.10.2026).
- **Abschaltbar** („Beobachtungen teilen“, Standard an): dann nichts senden, nichts empfangen.
- **Leise:** Geht ein Grüßender offline, bevor die Antwort fertig ist, bricht sie ab, und die Meldungen „kein Spieler mit dem Namen …“ des Clients bleiben aus dem Chat (#28).
- **Mit mehreren Spielern geprüft:** mit der Gilde bei #12 und #15 (18.10.2026); seit dem Release auf CurseForge im Betrieb (M5). Mit Spielern außerhalb der Gilde lief seit dem Start von Forever (5.11.2026) nichts, weil der Kanal gesperrt war (#153).

## 13 Oberfläche

**Allgemein:** eigenes Fenster mit drei Reitern (Fähigkeiten · Gebiet · Ausbildung), Zahnrad zu den Einstellungen, Modus oben rechts. Im Entdeckermodus beim ersten Öffnen eine Tour in Sprechblasen mit goldenem Rahmen um das, worum es geht (#178, §5). Eigene Karte im Fenster, keine Fremdbibliothek. Texte: englischer Text ist der Schlüssel in `L[]`, Deutsch in `Locales/deDE.lua`; Fähigkeits- und Zonennamen vom Client.

**Fähigkeiten:**
- Mehrfachauswahl heißt **„Anzeigen“**, nicht „Filter“: Ein Haken heißt „wird gezeigt“.
- Die Quelle (angeboren, Tierausbilder) ist eine eigene Achse neben dem Status.
- Zone und Familie als harte Filter.
- Die Gebietsauswahl wächst mit: Sie wird nach jeder neuen Zähmung oder Fähigkeit und beim Gebietswechsel neu gebaut, ein fest gewähltes Gebiet bleibt (#24, vorher fehlte bis /reload ein Gebiet, in dem beim Einloggen noch kein Lehrtier stand, und „Aktuelles Gebiet“ zeigte nichts).
- Lehrtiere nach Belegung, dann Aufwand; geteilt in „auf deiner Stufe“ und „erst ab höherer Stufe“.

**Gebiet:**
- Liste links, Karte rechts oben, bündig mit der Liste; der Kartentitel steht in der Kopfzeile neben der Zonenauswahl (wie „Ausbildung“), die Zähler darunter.
- Immer ein Tier gewählt.
- **Zonenauswahl mit eigenem Stand** (#180, §7): im Entdeckermodus „Brachland 3/12“ je Zone, ein Haken bei einer fertigen Zone, oben eine Zeile ohne Wahl „Alle Gebiete: 37 von 134 Tieren gefunden“ (grau wie die Überschriften der Mehrfachauswahl); alphabetisch; im Komplettmodus nur die Namen.
- **„Aktuelles Gebiet“** ist vorgewählt und folgt dem Spieler bei jedem Gebietswechsel, wie „Aktuelle Zone“ in „Fähigkeiten“ (#22). Ein fest gewähltes Gebiet bleibt stehen. In einem Gebiet ohne bekannte Tiere bleibt die Auswahl dort und die Liste sagt „Noch kein Tier in diesem Gebiet bekannt.“ – kein stilles Springen. Die Gebietsliste wird beim Öffnen und Gebietswechsel neu gelesen.
- Kästchen aus „Fähigkeiten“ (im Entdeckermodus mit Punkt bei „Tier gefunden“, #174), Familien-Icon.
- „lehrt“ mit Fähigkeits-Icons ohne Rang (passt auch bei mehreren); Namen und Ränge im Tooltip der Zeile. Im Entdeckermodus vor dem Studieren: bei „Tier gefunden“ „lehrt etwas“, „lehrt nichts“ oder „Keine Daten“ in Zeile und Zeilen-Tooltip, bei der Fährte nichts (#173).
- Nicht Belegtes trägt dasselbe „?“ bzw. „!“ (`ns.ConfMark`) wie Tooltip und „Fähigkeiten“ (#40): in der Zeile hinter dem Icon, im Tooltip der Zeile und der Lehrtier-Kachel hinter dem Rang, im Tooltip der Rang-Kachel, wenn kein gezeigtes Lehrtier der Zone den Rang belegt lehrt. Gezeigt wird nur, was die Einstellungen erlauben. Das „?“ steht nur hinten als Belegungszeichen; vorn steht keins mehr, seit „? unklar“ und „? unbekannt“ zu „Keine Daten“ mit rotem X wurden (#172). Verborgenes trägt seit #171 kein „?“ mehr, nur das Fragezeichen-Icon. Seit #169 kann auch im Entdeckermodus „?“ bzw. „!“ hinter einem Rang stehen, wenn ein studiertes Tier unsichere Angaben hat und die Einstellung sie zeigt. Ein drittes Zeichen hätte „Gleiches gleich“ gebrochen; wenn einmal alles belegt ist, spielt die Doppelbedeutung keine Rolle mehr (Maintainer).
- „lehrt nichts“ aus fremden Zähmungen gilt erst ab 3 Meldern, wie Ränge; eine eigene Zähmung zählt sofort (#40). Vorher reichte eine einzige fremde Zähmung, was eine Falschaussage sein konnte.
- Erklärung der Status im Tooltip des Zählers „Tiere“.
- **Hinweise, was als Nächstes zu tun ist** (Maintainer, 13.11.2026, #175, Epic #186): Im Entdeckermodus sagt jede Stufe selbst, wie es weitergeht, in ganzen Sätzen (bewusste Ausnahme von Grundsatz 7). Im Tooltip der Zeile steht in Gold unter der Lehre (`ns.StatusHint`): bei „Noch nie gesehen“, dass man es nur irgendwo sehen muss, um die Fährte aufzunehmen, auch mit „Wildtiere aufspüren“, „Adlerauge“ oder „Augen des Wildtiers“ (Namen vom Client); bei der Fährte, dass man näher ran muss (auch wenn die Lehre aus einer anderen Zone schon bekannt ist); bei „Tier gefunden“, dass Zähmen die Fähigkeiten verrät; bei „Tier studiert“ nichts. Auf der Karte steht der Satz (`ns.MapHint`) in einem halb durchsichtigen dunklen Rahmen in der Mitte, solange sie für das gewählte Tier keinen Fundort zeigt: bei „Noch nie gesehen“ ohne Namen, bei der Fährte mit Namen; die Zeile darunter bleibt dann leer statt „Fundort unbekannt“. Ab „Tier gefunden“ stehen dort die eigenen Fundorte. Der Tier-Tooltip in der Welt bleibt ohne diese Sätze, der Komplettmodus auch.
- **Verborgene Tiere sind anklickbar** (#175): Damit die Karte ihren Hinweis zeigen kann, lässt sich auch ein „verborgenes Tier“ wählen. Kartentitel und Zeilen-Tooltip sagen dann „verborgenes Tier“, nicht den Namen, und der Tooltip zeigt keine Lehre – sonst verrieten sie, was die Liste verbirgt. Die automatische Auswahl nimmt das erste Tier der Liste, erst die mit Status, dann die verborgenen; „Noch kein Tier gefunden“ steht nur noch in einer Zone ohne Tiere. Bis #175 waren diese Zeilen ausgegraut und nicht anklickbar.
- Unentdeckte Tiere tragen die zweite Zeile „Gehe auf die Pirsch und finde es.“ (#19) – ohne sie hielten manche das für eine Lücke in den Daten.
- Kachel-Tooltips knapp: erkanntes Lehrtier wie die Zeile (Name, Lehre, Klick zeigt es auf der Karte), entdeckter Rang Name, Rang und das leichteste Lehrtier der Zone (Klick zeigt es, Bewertung wie in „Fähigkeiten“), Verborgenes nur „noch nicht studiertes Lehrtier“ bzw. „noch nicht entdeckter Rang“ (bis #171 „? unentdeckt…“).

**Tier-Tooltip:**
- Alle Zeilen bündig mit der Kopfzeile „Forever Hunter Pets“.
- Status-Tag (nur Entdeckermodus), Angriffstempo, Ränge mit „– hast du“ (grau) / „– fehlt dir“ (grün), „lehrt nichts“ (grau). Im Komplettmodus und im Entdeckermodus bei „Tier gefunden“, wenn weder Daten noch irgendeine Zähmung sagen, was das Tier lehrt: „Was dieses Tier lehrt, weiß noch kein Jäger. Zähme es und hilf mit!“ (gold, #23) – Lücken sind Aufgaben. Geprüft wird roh: ausgeblendete unsichere Angaben zählen nicht als fehlend. Bei „Fährte aufgenommen“ und „Tier studiert“ nicht, dort sagt der Status, was zu tun ist. Bei „Tier gefunden“ steht dazu grau „lehrt etwas“ bzw. „lehrt nichts“ (#173); „lehrt nichts“ folgt der Einstellung „Auch Ränge zeigen, die du hast“. Nur wenn keine goldene Zeile passt, steht dort „Keine Daten“. Dass im Entdeckermodus bei „Tier gefunden“ dieselben goldenen Zeilen stehen, entschied der Maintainer am 13.11.2026 beim Test von #197: Derselbe Zustand sieht in beiden Modi gleich aus, und vor dem Tier ist die Aufforderung zum Zähmen am wertvollsten; vorher stand dort „✖ Keine Daten bekannt“.
- Im Komplettmodus und im Entdeckermodus bei „Tier gefunden“, wenn es zum Tier Angaben unter der Schwelle gibt (unsicherer oder unbelegter Rang, fremde Zähmungen von weniger als 3 Meldern, sofern die Daten den gezeigten Rang nicht schon belegen – eine solche Zähmung bestätigt nur, #144): „Die Jäger brauchen noch mehr Belege, was dieses Tier lehrt. Zähme es!“ (gold, einmal, #40). Auch roh geprüft, anders begründet als #23: Die Aussage stimmt auch bei ausgeblendeten Angaben, und ohne die Zeile bliebe ein Tier mit nur unsicheren Lehren bei ausgeschalteter Einstellung stumm. Nach einer eigenen Zähmung (jeder Charakter des Kontos) ist alles belegt, die Zeile fällt weg.
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

- **Agil, ein Inkrement nach dem anderen**, jedes für sich im Spiel prüfbar. Im `feature/…`-Branch wird jederzeit committet, auch vor dem Test; PR und Merge erst nach dem Test im Spiel (macht der Maintainer; seit 21.10.2026, vorher Commit erst nach dem Test).
- **Erst proben, dann bauen:** Unklare API-Fragen klärt eine Probe (`/fhp …`, Protokoll in den SavedVariables), Ergebnisse in [api-befunde.md](../technik/api-befunde.md).
- **Jeder Vorschlag wird bewertet:** Mehrwert, Komplexität, Risiko – in dieser Reihenfolge, je 1–10, mit Begründung; Bugs zusätzlich nach Schwere (Skala in [arbeitsweise.md](arbeitsweise.md)).
- **Prüfen ohne Spiel:** `luaparse` und `fengari` mit nachgebildeter WoW-API; Aussehen nur im Spiel – bei UI-Änderungen sagen, dass die Optik ungeprüft ist.
- **GitFlow:** Jede Änderung mit Issue in `feature/<Nr>-<titel>` von `develop`, per PR mit Merge-Commit zurück, Branch löschen; Issues, die zusammengehören, als Bündel unter einem Parent-Issue in einem Branch (#109); `main` nur Releases. Ein Release bekommt ein Issue und einen Branch `release/<version>` (eine Beta mit Zusatz, seit 1.0.0 zur Zielversion nummeriert, etwa `1.1.0-beta.1` → `1.1.0-beta.2` → `1.1.0`; ein echtes Release wie 1.0.0 ohne Zusatz, danach wieder Betas bis zum nächsten echten Release); dort Version und Release Notes, Abschlusstest, dann per PR zuerst nach `main` (Tag `v<version>`, etwa `v1.1.0-beta.1`), danach zurück nach `develop` (seit 18.10.2026; 0.6.0 bis 0.8.0 liefen ohne Release-Branch). Einzelheiten in [entwicklung.md](../technik/entwicklung.md).
- **Bekanntes, das nicht zum Auftrag gehört,** wird genannt, nicht ungefragt angefasst.
- **Forever ändert sich noch**, auch nach dem Start am 5.11.2026 (in der Beta wöchentlich); erhobene Daten können veralten.
- Doku, Kommentare, Commits deutsch; README, NOTICE, CONTRIBUTING und die Anleitung `docs/guide/guide.md` englisch.

## 16 Meilensteine und Stand

| Meilenstein | Inhalt | Stand |
| --- | --- | --- |
| M1 Eigene Daten | fremde Daten raus, Sammeln im Spiel | abgeschlossen (16.10.2026) |
| M2 Entdecken | Modi, Reiter „Gebiet“, Fährten und Witterung (E1–E5, E7) | abgeschlossen (17.10.2026, Release 0.6.0); E8 zurückgestellt |
| M3 Design | Farben, Hintergründe, Rahmen wie Original-Fenster (nur Aussehen) | zurückgestellt |
| M4 Veröffentlichung | Release, neues öffentliches Repo, CurseForge; vorher Screenshots neu | abgeschlossen (17.10.2026): öffentliches Repo, Beta 0.8.0 auf CurseForge, automatischer Upload |
| M5 Beta-Test | Teilen mit mehreren Spielern, Schwellen, Leistung, andere Sprachen | läuft (seit 17.10.2026); Release 0.9.0-beta mit #1–#5 (18.10.2026), Release 0.10.0-beta mit #12–#32 (18.10.2026), Release 0.11.0-beta mit #37–#80 (20.10.2026), Release 0.12.0-beta mit #49–#90 (22.10.2026), Release 0.13.0-beta mit #55–#114 (29.10.2026, vor dem Start von WoW Forever ohne Test im Spiel; Test am Starttag 5.11.2026 bestanden), Release 1.0.0 mit #124 (05.11.2026, erstes Release ohne Beta), Release 1.1.0-beta.1 mit #62–#139 (07.11.2026, erste nummerierte Beta), Release 1.1.0 mit #144 (08.11.2026, Stand von 1.1.0-beta.1 als echtes Release), Release 1.2.0 mit #154–#160 (11.11.2026, Teilen ohne Kanal, ohne Beta) |

Mit dem Release 1.0.0 ist der Beta-Hinweis aus dem Startdialog entfernt (`UI/ModeDialog.lua`, Texte in `Locales/deDE.lua`, Anleitung; #42, #115).

Seit 17.10.2026 stehen die Meilensteine als [Milestones](https://github.com/Jazzman1976/Forever-Hunter-Pets/milestones) auf GitHub, die Aufgaben als Issues darin und im öffentlichen [Project](https://github.com/users/Jazzman1976/projects/2). Diese Tabelle ist die Kurzfassung.

## 17 Wo was steht

| Dokument | Inhalt |
| --- | --- |
| [guide/guide.md](../guide/guide.md) | Anleitung für Spieler (englisch) |
| [konzept/entscheidungen.md](entscheidungen.md) | jede Entscheidung mit Datum und Wortlaut |
| [konzept/arbeitsweise.md](arbeitsweise.md) | wie gearbeitet wird und warum || [technik/addon-technik.md](../technik/addon-technik.md) | Dateien, Ablauf, Formate, Grenzen im Detail |
| [technik/datenformat.md](../technik/datenformat.md) | Felder in `tools/eigene/`, `tools/data.json`, `Data.lua` |
| [technik/quellen.md](../technik/quellen.md) | Sammelwege, Belegung, Grenzen der Daten, Rechte |
| [technik/entwicklung.md](../technik/entwicklung.md) | Einrichten, Prüfen ohne Spiel, Ablauf |
| [technik/api-befunde.md](../technik/api-befunde.md) | was die Forever-API kann, im Spiel geprüft |
