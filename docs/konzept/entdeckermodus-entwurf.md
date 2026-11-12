# Entwurf: Entdeckermodus verständlich und lohnend machen

**Stand: Entwurf, nichts entschieden.** Der Maintainer denkt das Konzept hier zu Ende und schreibt es selbst weiter, bevor irgendetwas umgesetzt wird. Erst wenn es entschieden ist, entstehen Issues (bei mehreren ein Bündel mit Parent-Issue), und die Entscheidungen kommen mit Datum nach [konzept.md](konzept.md) und [entscheidungen.md](entscheidungen.md).

**Herkunft:** Gespräch vom 11.11.2026, zuerst als Issue #165, dann als Discussion #167 (12.11.2026). Die Ausarbeitung ist am 12.11.2026 hierher umgezogen. Die Discussion #167 bleibt bestehen: Dort sollen Spieler ihre Gedanken zum Thema äußern. Was dort an Rückmeldungen kommt, fließt hier ein.

Bewertung je Idee: Mehrwert | Komplexität | Risiko (je 1–10).

**Inhalt:** [Ausgangslage](#ausgangslage) · [Stufenmodell](#kern-ein-neues-stufenmodell-gedanke-des-maintainers) · [Zähler und Formulierungen](#zähler-und-formulierungen-im-reiter-gebiet) · [Weitere Ideen](#weitere-ideen) · [Betroffene Entscheidungen](#entscheidungen-die-sich-ändern-würden) · [Offene Fragen](#offene-fragen)

## Ausgangslage

Rückmeldungen von Spielern zum Entdeckermodus:

- Viele verstehen nicht, was sie tun sollen oder können.
- Viele wissen nicht, dass es zwei Modi gibt, und nicht, wie man umschaltet.
- Die Belohnungen fürs Entdecken sind zu gering, Fortschritt wird kaum spürbar belohnt, Erfolge fehlen.
- Es ist nicht spannend genug, die Motivation fehlt.

Dahinter stehen vier Probleme:

1. Man **erkennt den Modus nicht**.
2. Man **weiß nicht, was als Nächstes zu tun ist**.
3. Man **spürt den Erfolg nicht**: Fährte und Fund legen heute fast nichts frei, erst das Zähmen bewegt etwas.
4. Es fehlt **ein Ziel über die Zone hinaus**.

## Kern: ein neues Stufenmodell (Gedanke des Maintainers)

Jede Stufe soll sofort etwas Sichtbares freilegen, nicht erst das Zähmen am Ende.

| Stufe | Auslöser | Status und Text in der Liste „Gebiet“ | Was freigelegt wird |
| --- | --- | --- | --- |
| 1 | noch nichts | rotes Fragezeichen, „? unentdecktes Tier“ · „Gehe auf die Pirsch und finde es.“ (wie heute) | nur die Anzahl |
| 2 | gesehen: Ziel, Maus, Namensplakette, Witterung („Wildtiere aufspüren“), aus jeder Entfernung | **Fährte aufgenommen** · „Familie · Stufe · ? Fähigkeiten unklar“ | Name, Familie, Stufe und **alle bekannten Fundorte auf der Karte** |
| 3 | begegnet (etwa 10 m, wie heute ein Fundort) | **Tier gefunden** | **ob** es etwas lehrt oder nichts, aber nicht **was** |
| 4 | gezähmt, später auch mit Wildtierkunde betrachtet | **Tier studiert** (auch, wenn es nichts lehrt) | **was** es lehrt, mit Rang; dazu vielleicht das **3D-Modell** |

### Anmerkungen zu den Stufen

- **Stufe 2, Fundorte:** M 9 | K 3 | R 3. Die Witterung und „Adlerauge“ werden dadurch richtig wertvoll: Man nimmt aus der Ferne eine Fährte auf und weiß sofort, wohin man muss. Das Finden wird dadurch leichter. Das ist gewollt, denn das Ziel liegt dahinter. Zu klären:
  - Gezeigt würden alle Fundorte, die das Addon kennt: Stammdaten, fremde ab 3 Meldern, eigene. Eigene sollten sich nicht nur durch Farbe, sondern auch durch die Form unterscheiden (Barrierefreiheit).
  - Die Witterung ordnet Fährten über den **Namen** zu. Haben mehrere NPC-IDs denselben Namen, bekämen alle eine Fährte und damit ihre Fundorte.
  - Fundorte der Zone, in der die Fährte liegt, oder alle Fundorte des Tiers?
- **Stufe 2, Stufe des Tiers:** Aus der Ferne (über 28 m) speichert die Sichtung keine Stufe; die lokale Fährte merkt sich nur Name und Familie. Die Stufe käme dann aus den Stammdaten. Das verrät nur wenig, muss aber bewusst entschieden werden.
- **Stufe 2, Wort „unklar“:** Heute heißt „? unbekannt“ „das weiß niemand“ und „? unentdeckt“ „bekannt, du hast es nur noch nicht gefunden“. „? unklar“ steht heute bei einem Tier, bei dem noch niemand weiß, was es lehrt. Damit „Gleiches gleich“ bleibt, wäre hier eher „? Fähigkeiten unentdeckt“ richtig. Im Gespräch war auch ein Text mit Handlungsaufforderung, etwa „Geh näher ran“ (Stufe 2) bzw. „Zähme es, um zu erfahren, was es lehrt“ (Stufe 3).
- **Stufe 3:** M 8 | K 3 | R 2. Man spart sich Tiere, die nichts lehren; das ist schon beim Finden ein echter Mehrwert. Das Zähmen behält sein Geheimnis. Weiß niemand, was das Tier lehrt, steht dort ehrlich „? unbekannt – zähme es und finde es heraus“ (Grundsatz „Nicht raten“).
- **Stufe 4:** „Tier studiert“ würde „Fähigkeiten bekannt“ ersetzen. Das Leitbild nennt „Fähigkeiten bekannt“ als Ziel des Spiels (§1); der Wortlaut dort müsste mit.
- **Stufe 4, 3D-Modell freischalten:** M 7 | K 2 | R 2. Das Modell gibt es schon auf der Tierseite. Vorher eine Silhouette oder ein Platzhalter, danach das Tier: eine kleine, sichtbare Trophäe.
- **Was zählt je NPC-ID, was je Zone?** Was ein Tier lehrt, hängt an der NPC-ID, nur der Rang an der Stufe. Vorschlag: „gefunden“ und „studiert“ legen die Lehre überall frei; Fährte, Fundort und Status bleiben je Zone wie heute.

### Wildtierkunde als zweiter Weg zu „studiert“

M 9 | K 4 | R 4. Wildtierkunde bekommt damit ihre alte Aufgabe aus Vanilla zurück: sehen, was ein Tier kann, **bevor** man es zähmt. Das passt zum Leitbild (alte Jägerzauber werden Werkzeuge der Suche).

- **Früh im Spiel blockiert es nichts**, weil Zähmen der andere Weg bleibt. Im klassischen Spiel lernt man Wildtierkunde mit Stufe 24. Am Anfang ist Zähmen billig. Später, wenn es teurer wird (Elite, lange Wege), spart Wildtierkunde Zeit.
- **Tooltip:** Das Ergebnis erscheint im Tooltip des Tiers, wo der Abschnitt des Addons schon steht, etwa:
  ```
  Forever Hunter Pets
  Studiert – du weißt jetzt, was es dir beibringt:
    Beißen Rang 3 – fehlt dir
    Knurren Rang 2 – hast du
  ```
  Ein ganzer Satz im Tooltip widerspricht Grundsatz 7 („knapp“). Entweder wird er wie #23 eine ausdrücklich gewollte Ausnahme, oder der Satz kommt nur beim ersten Studieren (als Einblendung) und der Tooltip sagt danach nur „Studiert“.
- **Weiß niemand, was es lehrt:** „Studiert – aber kein Jäger weiß noch, was es lehrt. Zähme es!“
- **Heute** zeigt Wildtierkunde in Forever keine Fähigkeiten (an Blizzard gemeldet, siehe `docs/konzept/entscheidungen.md`). Was sie sonst noch zeigt und ab welcher Stufe es sie in Forever gibt, ist nicht dokumentiert.
- **Probe vorher:** Erkennt das Addon sicher, dass Wildtierkunde auf **dieses** Tier gewirkt wurde (Zauber gelungen samt Ziel, oder der Effekt auf dem Ziel)? Im Kampf liefert der Client geheime Werte, also nur außerhalb des Kampfs werten.
- **Speichern:** „studiert“ je Charakter und NPC-ID, wenige Bytes, nicht geteilt. Studieren ist Wissen aus den Daten, keine Beobachtung, und beweist deshalb nichts.
- **Behebt Blizzard den Fehler,** zeigt das Spiel die Fähigkeiten selbst. Das schadet dem Weg nicht; vielleicht ließe es sich dann sogar zum Sammeln nutzen (eigene Probe).
- Vorschlag zum Schnitt: eigenes Issue nach dem Bündel, das mit der Probe beginnt, damit das Bündel nicht an einer offenen API-Frage hängt.

### Was dem Zähmen allein bleibt

Wenn „studiert“ auch über Wildtierkunde erreichbar ist, braucht das Zähmen eine eigene Belohnung. Vorschlag: **Wissen** (Studieren oder Zähmen) und **Besitz** (nur Zähmen) trennen.

| Idee | M | K | R |
| --- | --- | --- | --- |
| **Haken nur fürs Zähmen** (Symbol, nicht nur Farbe): sichtbar, welches studierte Tier noch auf die Zähmung wartet | 8 | 2 | 2 |
| **„Dein Beleg zählt“**: Bestätigt die eigene Zähmung etwas Unsicheres oder Unbekanntes, sagt das Addon es, etwa „Bestätigt! Jetzt wissen alle Jäger, was das Tier lehrt.“ Belegung und Melder kennt das Addon schon. | 8 | 3 | 2 |
| **Pionier**: Das Tier steht nicht in den Daten der installierten Version („Pionier! Kein Jäger mit deiner Version kannte dieses Tier.“). Regel steht schon in §7 (#65). | 9 | 2 | 2 |
| **Einblendung mit Sound** mitten im Bild (Spielsound aus dem Client, abschaltbar), statt nur der Chatzeile | 8 | 2 | 2 |
| **Revier gemeistert**: alle Lehrtiere einer Zone gezähmt; erster Erfolg, an dem sich E8 ausrichten kann | 8 | 4 | 3 |
| **Trophäenwand**: die gezähmten Lehrtiere als 3D-Modell, nach Familie | 7 | 5 | 3 |

Offen: Ist „gezähmt“ ein eigener Status nach „studiert“ oder nur eine Markierung (Haken) an „studiert“?

## Zähler und Formulierungen im Reiter „Gebiet“

Heute: „0 von 22 bekannt“, „0 von 11 identifiziert“, „0 von 8 Rängen entdeckt“. Vorschlag des Maintainers: in ganzen Sätzen, die den Spieler ansprechen. Mit dem Stufenmodell könnte jeder Zähler genau einer Stufe gehören:

| Zähler | Vorschlag | Stufe |
| --- | --- | --- |
| Tiere | „Du hast 5 von 22 Tieren entdeckt“ | ab Fährte |
| Lehrtiere | „Du hast 2 von 11 Lehrtieren gefunden“, oder „… gezähmt“ | Fund bzw. Zähmen |
| Ränge | „Du kennst 3 von 8 Rängen dieses Gebiets“ | studiert |

Dazu ein einmaliger Lernhinweis bei der ersten Fährte eines Charakters, etwa „Du weißt jetzt, wo dieses Tier lebt. Seine Fährte erkennst du ab jetzt.“ Danach nicht mehr: Fährten melden sich bewusst nicht im Chat, sonst kämen bei der Witterung zehn Zeilen auf einmal.

Stolpersteine:

- **„gelernt“** heißt im Addon immer Lernstand, das Kästchen „hast du“ (#77). Zähmen oder Studieren ist nicht Lernen. Für die Ränge deshalb „kennen“, nicht „gelernt“. Der Lernstand bleibt getrennt.
- **„entdeckt“** ist schon besetzt: Die Chatmeldung beim Zähmen heißt „Entdeckt: Beißen Rang 3 …“ (#51). Heißt „entdeckt“ künftig „ab Fährte“, braucht die Meldung ein anderes Wort.
- **Komplettmodus:** „Du hast …“ passt dort nicht, weil X dort heißt „ist überhaupt bekannt“. Er braucht eigene Texte.
- **Länge:** „Du hast 0 von 11 Tieren gezähmt, die dir Fähigkeiten beibringen können“ ist für den Platz unter der Karte zu lang. „Lehrtier“ erklärt der Tooltip.

## Weitere Ideen

### A: Den Modus erkennen und umschalten

| # | Idee | M | K | R |
| --- | --- | --- | --- | --- |
| A1 | **Modusschalter im Fenster:** oben rechts ein Schalter „Entdecken \| Komplett“ statt des kleinen Textes; beim Wechsel zu „Komplett“ eine Rückfrage gegen versehentliches Spoilern | 8 | 3 | 2 |
| A2 | **Fußzeile im Reiter „Gebiet“**, wenn anonyme Tiere da sind: „Entdeckermodus: Namen erscheinen, sobald du ein Tier aufspürst. · *Alles zeigen*“; erklärt die Fragezeichen und zeigt den Schalter | 9 | 2 | 2 |
| A3 | **Klarere Namen für die Modi**, etwa „Jagdbuch (selbst entdecken)“ und „Nachschlagewerk (alles zeigen)“; Anleitung und Screenshots müssten mit | 6 | 2 | 3 |
| A4 | `/fhp modus` zum Umschalten, mit derselben Rückfrage | 3 | 1 | 1 |
| A5 | **CurseForge-Seite:** die Modi mit zwei Screenshots derselben Zone nebeneinander erklären (kein Code) | 6 | 2 | 1 |

### B: Was soll ich tun?

| # | Idee | M | K | R |
| --- | --- | --- | --- | --- |
| B1 | **Anleitung im leeren Zustand:** Solange ein Charakter in einer Zone nichts entdeckt hat, steht im Reiter „Gebiet“ statt einer Wand aus „?“: „Hier warten 9 Tiere. 1. Fahr mit der Maus über Tiere → Fährte. 2. Geh nah ran → Fundort. 3. Zähme es → …“; verschwindet mit der ersten Fährte. Größter Hebel für den kleinsten Aufwand. | 9 | 2 | 1 |
| B2 | **Nächster Schritt am Status**, ein Wort: „Fährte aufgenommen → näher ran“, „Tier gefunden → zähmen“ | 8 | 2 | 2 |
| B3 | **„Wo lohnt sich die Jagd?“:** eigener Stand je Zone in der Zonenauswahl („Brachland 3/12“), nach Stufe sortiert; dazu der Gesamtfortschritt aus #53 („37 von 134 Tieren“) | 8 | 4 | 2 |
| B4 | **Checkliste „Jägerlehrling“:** fünf Schritte, die sich selbst abhaken (Tier anvisieren, nah ran, zähmen, Wildtierausbildung öffnen, „Wildtiere aufspüren“ an der Minikarte); Einführung und erste Erfolge in einem, bringt nebenbei die Witterung bei | 9 | 4 | 2 |

### C: Belohnungen

Zusätzlich zu „Was dem Zähmen allein bleibt“:

| # | Idee | M | K | R |
| --- | --- | --- | --- | --- |
| C1 | **„Dein Fund ist jetzt im Addon“:** Nach einem Update zählt das Addon eigene Zähmungen, die neu in den Stammdaten stehen: „3 deiner Entdeckungen helfen jetzt allen Jägern.“ Dafür merkt es sich je Version, welche Tiere in den Daten standen. Zeigt, wozu das Teilen gut ist. | 8 | 4 | 3 |
| C2 | **Erfolge (E8)** als eigene Ansicht mit Einblendungen: Zonen, Familien, Fähigkeiten (Beißen 1–8), Pionier, Seltenes Wild (Rare, Elite), Fährtenleser (Witterung), Kartograph (Fundorte). Die Regeln stehen schon in §7 (#65, #66). | 10 | 6 | 3 |
| C3 | **Jägerrang:** Titel nach Gesamtfortschritt (Fährtenleser → Pirschjäger → Wildhüter → Meister der Wildnis) im Fenstertitel, zunächst nur lokal | 7 | 3 | 2 |

Zu C2: Erfolge sind laut §14 zurückgestellt, „bis es mehr eigene Daten gibt“. Da sie nur an **eigenen** Funden hängen (#65), brauchen sie keine vollständigen Stammdaten; mit 190 Tieren und 127 Lehrtier-Paaren gibt es schon genug zu holen. Das wäre eine neue Entscheidung.

### D: Spannung und Motivation

| # | Idee | M | K | R |
| --- | --- | --- | --- | --- |
| D1 | **Hinweis auf Wunsch:** Klick auf eine unentdeckte Kachel deckt nur Familie oder Stufenbereich auf („eine Katze, Stufe 30–35“); berührt Grundsatz 4 „nicht spoilern“ | 8 | 4 | 4 |
| D2 | **Jagd der Woche:** aus der Kalenderwoche eine Zone oder Familie, für alle gleich, ohne Server und ohne Verkehr („Diese Woche: die Lehrtiere im Sumpfland“) | 6 | 3 | 2 |
| D3 | **Vergleich in der Gilde:** ein paar Zahlen mit dem Gruß („Gilde: A 37 Tiere, B 22“); starker sozialer Anreiz, kostet aber Verkehr (Grundsatz 2) und verrät den Modus – höchstens später und nur auf Wunsch | 7 | 6 | 5 |

## Entscheidungen, die sich ändern würden

- §1 Leitbild und §7: „Nur ‚Fähigkeiten bekannt‘ treibt den Fortschritt“ – künftig bewegt die Fährte den Tiere-Zähler, und „Fähigkeiten bekannt“ hieße „Tier studiert“.
- §5 und §8: Im Entdeckermodus zeigt die Karte nicht mehr nur eigene Fundorte.
- §6: Status, Wörter und was jede Stufe freilegt.
- §2 Grundsatz 7 „knapp“: gegebenenfalls Ausnahme für den Wildtierkunde-Satz und die Fußzeile A2.
- §14: Erfolge (E8) nicht mehr zurückgestellt, falls C2 kommt.
- `docs/konzept/entscheidungen.md`: Wildtierkunde wird wieder genutzt.

Was entschieden wird, kommt mit Datum nach `docs/konzept/konzept.md` und `docs/konzept/entscheidungen.md`, die Anleitung `docs/guide/guide.md` geht mit.

## Offene Fragen

Je Frage der Stand aus der Discussion (12.11.2026) und darunter die Antworten des Maintainers. Erst wenn alle geklärt sind, wird das Konzept in Issues geschnitten.

### Frage 1: Stufenmodell

Passt das Stufenmodell oben – unentdeckt → **Fährte aufgenommen** (Name, Familie, Stufe, alle Fundorte) → **Tier gefunden** (lehrt etwas oder nichts) → **Tier studiert** (was genau, mit Rang; durch Zähmen oder später Wildtierkunde)? Oder soll es anders aussehen?

Dazu gehört: „Tier studiert“ würde „Fähigkeiten bekannt“ ersetzen, und das Leitbild nennt „Fähigkeiten bekannt“ als Ziel des Spiels (Konzept §1, §7).

#### Antwort des Maintainers (12.11.2026)

Ich denke die Stufen sind eine gute Idee und sind so in Ordnung.

##### Stufe 1 - Unentdeckt

Hier finde ich wichtig, dass man das anhand des Statusnamen schon versteht, dass das Addon die Daten kennt und man sie noch entdecken muss. Das man dafür das Pet einfach nur "sehen" muss sollte jedem sofort klar werden. Sehen bedeutet: man hatte es im Target, Mouse Over, über die Fährtenlesen Fähigkeit auf der Minimap, mit der Fähigkeit Augen des Adlers gesehen, die Namensplakette beim vorbeigehen erkannt, etc.

Sobald man ein Pet "gesehen" hat, wird der Status "Fährte aufgenommen" erreicht.

Jedem sollte intuitiv klar werden was zu tun ist wenn ein Pet im Status "Unentdeckt" ist.

Weiterhin sollte jedem der Unterschied zwischen "Unentdeckt" und "Unbekannt" klar sein. "Unbekannt" meint: Das Addon kennt die Daten nicht. Das finde ich Stand heute zu nah beieinander und verwirrt eher. Das sollte klarer sein, z.B. "Keine Daten" oder etwas noch passenderes.

##### Stufe 2 - Fährte aufgenommen

Hier sollte das Icon (Pet Familie) in der Liste freigeschaltet werden und die Infos welche Stufen das Pet hat und auch alle Pins auf der Karte.

Hier habe ich lange damit gehadert ob wir alle Pins anzeigen wollen oder nicht. Das würde nämlich viel verändern zu heute. Der Spieler würde nicht mehr ausschließlich seine eigenen Daten sehen die er mit seinem Charakter gesammelt hat sondern ALLE.

Ich denke heute, dass das trotzdem besser ist, denn es bringt deutlich mehr Wert als bisher und der eigentliche Spaß am Entdecken geht ja dadurch nicht verloren.

Es sollte dem Spieler jetzt klar gemacht werden was der nächste Schritt ist: das Tier "finden" indem er nah heran geht, am besten bekämpft. Das sollte sofort intuitiv klar werden.

##### Step 3 - Tier gefunden

Passt ebenfalls so wie geplant: Der Spieler erhält Zugang zu der Information OB das Pet etwas lehrt oder nicht, aber nicht WAS genau es lehren kann.

Dem Spieler sollte jetzt klar sein was er machen muss: er muss jetzt dieses Tier zähmen oder mit Wildtierkunde scannen. Dann erreicht er den finalen Step: "Tier studiert".

##### Stufe 4 - Tier studiert

Finale Stude.

Hier wird dem Spieler alles freigeschaltet was das Addon kennt. Das sind unter anderem jetzt noch die Fähigkeiten die es lehrt.

Alle Texte sollten jetzt an "Tier studiert" angepasst werden (Gleiches stets gleich).

### Frage 2: Was zeigt die Fährte?

- **Fundorte:** nur die der Zone, in der die Fährte liegt, oder alle Fundorte des Tiers?
- **Stufe:** Aus der Ferne kennt das Addon die Stufe nur aus den Stammdaten. Soll sie trotzdem schon bei der Fährte stehen?
- **Wort:** „? Fähigkeiten unklar“ kollidiert mit dem heutigen „? unklar“ (= das weiß niemand). Lieber „? Fähigkeiten unentdeckt“, oder ein Text mit Handlungsaufforderung wie „Geh näher ran“?
- **Gleichnamige Tiere:** Die Witterung ordnet über den Namen zu. Haben mehrere NPC-IDs denselben Namen, bekämen alle eine Fährte und damit ihre Fundorte. Hinnehmen?

#### Antwort

_offen_

### Frage 3: Gezähmt nach studiert – eigener Status oder Haken?

Wenn „Tier studiert“ auch über Wildtierkunde erreichbar ist, braucht das Zähmen etwas Eigenes. Ist „gezähmt“ ein eigener, fünfter Status nach „studiert“, oder bleibt es bei „studiert“ mit einem Haken (Symbol, nicht nur Farbe)?

Was dem Zähmen außerdem bleiben könnte: „Dein Beleg zählt“, Pionier, Einblendung mit Sound, „Revier gemeistert“, Trophäenwand (siehe „Was dem Zähmen allein bleibt“).

#### Antwort

_offen_

### Frage 4: Zähler im Reiter „Gebiet“

Vorschlag: jeder Zähler gehört zu einer Stufe.

- Tiere: „Du hast 5 von 22 Tieren entdeckt“ (ab Fährte)
- Lehrtiere: „Du hast 2 von 11 Lehrtieren **gefunden**“ oder „… **gezähmt**“?
- Ränge: „Du kennst 3 von 8 Rängen dieses Gebiets“ (studiert) – nicht „gelernt“, weil das im Addon den Lernstand meint.

Dazu: Die Chatmeldung beim Zähmen heißt heute „Entdeckt: …“ und braucht ein anderes Wort, und der Komplettmodus braucht eigene Texte.

#### Antwort

_offen_

### Frage 5: Wildtierkunde – im Bündel oder danach?

Vorschlag: als eigenes Issue nach dem Bündel. Es beginnt mit einer Probe, ob das Addon sicher erkennt, dass Wildtierkunde auf dieses Tier gewirkt wurde, und ab welcher Stufe es sie in Forever gibt. So hängt das Bündel nicht an einer offenen API-Frage.

Außerdem offen: Wird der Satz im Tooltip („Studiert – du weißt jetzt, was es dir beibringt:“) eine gewollte Ausnahme von „knapp“, oder kommt er nur einmal als Einblendung?

#### Antwort

_offen_

### Frage 6: Welche Ideen A–D?

Welche der Ideen oben kommen ins Bündel, welche als eigene Issues ins Backlog, welche gar nicht?

Aus meiner Sicht am stärksten für wenig Aufwand: **B1** Anleitung im leeren Zustand, **A2** Fußzeile mit „Alles zeigen“, **A1** Modusschalter im Fenster, **B2** nächster Schritt am Status, dazu Einblendung mit Sound und Pionier.

#### Antwort

_offen_

### Frage 7: Erfolge (E8) jetzt oder später?

Erfolge sind laut Konzept §14 zurückgestellt, „bis es mehr eigene Daten gibt“. Da sie nur an eigenen Funden hängen (#65), brauchen sie keine vollständigen Stammdaten; mit 190 Tieren und 127 Lehrtier-Paaren gibt es schon genug zu holen. Jetzt angehen – vielleicht klein, mit „Revier gemeistert“ und der Checkliste „Jägerlehrling“ (B4) – oder weiter zurückstellen?

#### Antwort

_offen_
