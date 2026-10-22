# Entwicklung

Einrichten, prüfen, Ablauf. Für alle, die am Addon oder an den Skripten mitarbeiten.

## Was man braucht

- **Node 18 oder neuer** – nur für die Skripte in `tools/`. Keine Abhängigkeiten, kein `npm install`.
- **Einen WoW-Forever-Client**, um das Addon zu testen.

Lua muss nicht installiert sein (siehe „Prüfen ohne Spiel“).

## Aufbau des Repos

Die Wurzel des Repos ist der Addon-Ordner.

| Ordner | Inhalt |
| --- | --- |
| Wurzel: `Core/`, `UI/`, `Locales/`, `Data/`, `Forever-Hunter-Pets.toc` | das Addon |
| `tools/` | Skripte: Beobachtungen importieren, Daten und `Data.lua` bauen |
| `tools/eigene/` | die selbst erhobenen Daten, jede Angabe mit Beleg |
| `docs/guide/` | Anleitung für Spieler (englisch) |
| `docs/konzept/` | Konzept, Entscheidungen, Arbeitsweise |
| `docs/technik/` | technische Dokumentation: Addon, Datenformat, Quellen, API-Befunde, Entwicklung |

Der Datenfluss:

```
tools/eigene/*.json  ──>  tools/build-data.mjs  ──>  tools/data.json  ──>  tools/build-addon.mjs  ──>  Data/Data.lua
```

`tools/data.json` und `Data.lua` sind generiert und werden nicht von Hand bearbeitet. `.pkgmeta` nimmt `tools/` und `docs/` aus dem CurseForge-Paket.

## Addon in den Client hängen

Der Ordner im Client muss wie die TOC heißen: `Forever-Hunter-Pets`. Wer nur spielt, klont das Repo direkt dorthin und aktualisiert mit `git pull`:

```
cd "<World of Warcraft>\_classic_beta_\Interface\AddOns"
git clone <Repo-URL> Forever-Hunter-Pets
```

Zum Entwickeln das Repo verknüpfen – dann wirkt jede Änderung nach `/reload`. Unter Windows als Junction (braucht keine Administratorrechte):

```
mklink /J "<World of Warcraft>\_classic_beta_\Interface\AddOns\Forever-Hunter-Pets" "<Repo>"
```

Die gespeicherten Daten des Addons liegen nach `/reload` oder Logout hier:

```
<World of Warcraft>\_classic_beta_\WTF\Account\<Account>\SavedVariables\Forever-Hunter-Pets.lua
```

Bis 0.5.0 hieß der Ordner `ForeverHunterPets`. Wer von dort kommt, benennt die Dateien `ForeverHunterPets.lua` (im Konto und je Charakter) einmal in `Forever-Hunter-Pets.lua` um. Die Variablen darin heißen weiter `ForeverHunterPetsDB`.

`/fhp start` zeigt den Startdialog noch einmal, auch wenn der Charakter schon gewählt hat (Entwicklerwerkzeug, nicht in der Befehlsübersicht); Schließen ändert dann nichts, eine Wahl setzt den Modus. Ganz zurück auf „noch nicht gewählt“: `/run ForeverHunterPetsCharDB.modeChosen = nil`, danach `/fhp`.

`/fhp api` schreibt ein API-Protokoll dorthin (`ForeverHunterPetsDB.probe`). So kommt Spielausgabe in eine Datei, ohne dass jemand Chatzeilen abtippt.

## Prüfen ohne Spiel

Zwei npm-Pakete, in einem Ordner außerhalb des Repos installiert:

- **`luaparse`** (Lua 5.1) prüft die Syntax.
- **`fengari`** führt das Addon gegen eine nachgebildete WoW-API aus: alle Dateien der TOC laden, `ADDON_LOADED` und `PLAYER_LOGIN` auslösen, Fenster und Ansichten öffnen. Achtung: fengari rechnet mit 32-Bit-Ganzzahlen. Rechnungen über 2^31 (etwa das Melder-Kürzel mit `("%08x"):format(h)`) melden dort Fehler, die es im Client nicht gibt; die Nachbildung sollte `string.format` für `%08x` deshalb über die beiden Hälften rechnen.

`luaparse` übersieht ungültige Escapes wie `"Interface\Icons"` – die findet erst `fengari`. Aussehen und echte Client-Aufrufe zeigt nur der Test im Spiel.

## Daten bauen

```
node tools/import-observations.mjs <WoW-Ordner>   # Erhebung, Sichtungen, Zähmungen, Fundort-Zellen und eigene Kürzel nach tools/eigene/
node tools/build-data.mjs      # tools/data.json; bricht ab, wenn einer Angabe der Beleg fehlt oder sich Fähigkeiten ändern
node tools/build-addon.mjs     # erzeugt Data/Data.lua
```

**Salz für fremde Kürzel (#48):** Der Import rechnet fremde Kürzel mit dem Salz aus `.ignore/melder-salz.txt` neu und rundet die Zeit fremder Einträge auf den Tag (Format in [datenformat.md](datenformat.md)). Fehlt die Datei, legt der Import ein neues Salz an und sagt das. **Die Datei sichern:** Mit einem neuen Salz bekommen dieselben Melder neue Kürzel und zählen doppelt, Daten könnten zu früh als belegt gelten. Wer sonst importiert, braucht dieselbe Datei (privat weitergeben, nie ins Repo).

**Vergleich mit dem Stand in Git (#37):** `build-data.mjs` vergleicht das Ergebnis mit `tools/data.json` in `HEAD` (nicht mit der Datei auf der Platte, sonst meldete ein zweiter Lauf nichts mehr) und gibt eine Übersicht alt → neu aus: Fähigkeiten, Ränge, Lehrtier-Paare, Tiere, Fundorte, dazu neue Ränge bekannter Fähigkeiten. Kommt eine Fähigkeit dazu, fällt eine weg oder wechselt eine die Herkunft (von Tieren ↔ beim Tierausbilder), bricht es ab, ohne `tools/data.json` zu schreiben, und listet sie mit Rängen, Familien und Zahl der Lehrtiere auf. Erst prüfen – so sahen die Jägerzauber aus #34 aus: von Tieren, mit Familien, aber ohne ein einziges Lehrtier –, dann mit `node tools/build-data.mjs --neue-faehigkeiten` bestätigen. Fähigkeiten gelten als dieselben, wenn sie einen Rang (Zauber-ID) teilen. Der Vergleich von Hand nach jedem Import entfällt damit; vor einem Release bleibt der Probe-Import, dessen Übersicht man liest.

**Import vor jedem Release (#39):** Die Stammdaten wachsen nur durch einen Import. Er kommt einmal vor jedem Release als eigenes Issue, vor dem Release-Branch (im Release-Branch kommen keine neuen Daten): im Spiel `/reload` oder Logout, Import, `build-data.mjs` (neue Fähigkeiten im Issue auflisten und vom Maintainer bestätigen lassen), `build-addon.mjs`, Test im Spiel, PR nach `develop`.

`--ohne-tierausbilder` (vor dem Pfad) übernimmt aus den SavedVariables weder das Kennzeichen „Tierausbilder“ noch Jägerstufe und Goldpreis; was `erhebung.json` schon hat, bleibt. Nötig war das für Erhebungen bis Version 8, in denen das Addon die Wildtierausbildung manchmal als Tierausbilder erhob (#30: Pet-Stufen standen als Jägerstufe, TP als Preis da, und Beißen, Ducken, Sturmangriff und Gespinst hätten als „beim Tierausbilder, jede Familie“ alle Lehrtiere verloren). Seit #32 ordnet das Addon das Fenster richtig ein, bereinigt die SavedVariables beim Wechsel auf Version 9, und der Import liest ältere Erhebungen nicht mehr (seit #34 erst ab Version 10, weil Version 9 Jägerzauber enthalten kann); der Schalter bleibt als Vorsicht.

Die Skripte melden am Ende, was auffällt – `build-data.mjs` etwa Widersprüche zwischen Zähmungen derselben NPC-ID oder TP, die nicht zueinander passen. Ein Lauf ohne Änderung an Code oder Daten darf `tools/data.json` nur im Feld `generatedAt` verändern. `tools/lua-table.mjs` liest SavedVariables-Dateien und wird vom Import benutzt.

## Paket bauen

```
node tools/package.mjs            # ZIP nach .pkgmeta in .ignore/dist/v<Version>.zip, Ordner Forever-Hunter-Pets/, Version aus dem TOC
```

Das Paket enthält alle von git verfolgten Dateien ohne das, was `.pkgmeta` ausnimmt, und ohne Punkt-Dateien – im Stand der Arbeitskopie. Es geht an Tester; 0.8.0 ging so von Hand zu CurseForge.

**Veröffentlichen** übernimmt seit 0.8.0 die GitHub Action `.github/workflows/release.yml` (BigWigs-Packager): Jedes gepushte Tag `v*` wird gepackt und nach CurseForge hochgeladen (Projekt-ID aus `## X-Curse-Project-ID` im TOC) und als GitHub-Release mit ZIP angelegt. Den Typ bestimmt der Tag-Name: `-beta` → Beta, `-alpha` → Alpha, sonst Release. Changelog ist `CHANGELOG.md` (englisch, `manual-changelog` in `.pkgmeta`), vor jedem Release oben um die neue Version ergänzen. Das CurseForge-API-Token liegt als Secret `CF_API_KEY` im Repo. Von Hand gestartet (Actions → Release → Run workflow) baut die Action nur probeweise, ohne Upload, und hängt das ZIP an den Lauf.

**Name des ZIPs** (Regel des Nutzers, 18.10.2026, gilt für jedes Release): `v<version>.zip`, also wie das Tag, etwa `v0.10.0-beta.zip`; auf CurseForge heißt die Datei ebenso. Die Action setzt das mit `-n "{project-version}"`, `tools/package.mjs` genauso. Wichtig ist nur, dass CurseForge Beta und Spielversion richtig erkennt: Beta kommt aus dem Tag (`-beta`), die Spielversion „Forever“ aus `## Interface` im TOC – nicht aus dem Dateinamen. Im ZIP liegt weiter der Ordner `Forever-Hunter-Pets/`, sonst lädt WoW das Addon nicht. Bis 0.9.0 hieß das ZIP `Forever-Hunter-Pets-v<version>-forever.zip`.

## Ablauf

- **Branches: GitFlow nach Atlassian.**
  - `develop` ist der Arbeitsstand. Direkt dorthin wird nichts committet (seit 17.10.2026, siehe „Issue, Branch, PR“).
  - `feature/<Nr>-<issue-titel-als-slug>` für jede Änderung: Der Branch geht von `develop` ab und kommt per Pull Request mit Merge-Commit (`--no-ff`) dorthin zurück; danach wird er lokal und auf origin gelöscht.
  - `release/<version>` (vor 1.0.0 `release/<version>-beta`) geht von `develop` ab, bekommt die Versionsnummer, die Release Notes und nur noch Korrekturen aus dem Abschlusstest, und wird dann per PR **zuerst** nach `main` und danach zurück nach `develop` gemergt. Der Merge auf `main` bekommt das Tag. Einzelheiten unter „Release“.
  - `hotfix/<version>` geht von `main` ab und wird ebenfalls nach `main` und `develop` gemergt.
  - `main` enthält nur veröffentlichte Stände.
  - **Geschützt** (Ruleset „Protect develop and main“ auf GitHub, 17.10.2026): `develop` und `main` lassen sich nicht löschen und nicht per Force-Push überschreiben; Änderungen kommen nur per Pull Request mit einer Freigabe hinein. Ausgenommen ist die Rolle „Repository admin“ – der Maintainer pusht und mergt weiter direkt (GitHub meldet das als „Bypassed rule violations“).
  - **Release nach GitFlow** (Regel des Nutzers, 18.10.2026; PR erst nach dem Abschlusstest): Ein Release hat ein Issue. `release/<version>` (vor 1.0.0 mit `-beta`, etwa `release/0.9.0-beta`) geht von `develop` ab; erst dort werden die Version im TOC erhöht und die Release Notes in `CHANGELOG.md` (englisch, daraus macht die Action die Notizen für CurseForge und das GitHub-Release) geschrieben. Es folgen der Abschlusstest des Maintainers und gegebenenfalls kleine Korrekturen im Release-Branch. Ist der Test bestanden, kommt der Release-Branch **zuerst per PR nach `main`** (ausführlich, mit Zusammenfassung zur Abnahme und Verweisen auf alle Issues und PRs des Releases), danach per PR zurück nach `develop` (knapp: „Rückführung der Release-Änderungen nach `develop`, siehe PR #X“). Nach dem Merge in `main` bekommt der Merge-Commit das Tag `v<version>` – vor 1.0.0 `v<version>-beta`, etwa `v0.9.0-beta`; das Tag löst den Upload zu CurseForge und das GitHub-Release aus. Danach wird der Release-Branch gelöscht. Bis 0.8.0 lief ein Release ohne Release-Branch direkt von `develop` nach `main`.
    - **Immer ein eigener Branch** (Nutzer, 18.10.2026): Das Release liegt bis zum Abschluss auf `release/<version>-beta`, damit auf `develop` parallel weiterentwickelt werden kann, während das Release gründlich getestet wird. Neue Features gehen in dieser Zeit ganz normal nach `develop`, nicht in den Release-Branch; dort landen nur Korrekturen aus dem Abschlusstest. Da das Spiel über die Junction nur das Arbeitsverzeichnis sieht, liegt der Stand, der gerade getestet wird, im Arbeitsverzeichnis und die parallele Arbeit in einem Git-Worktree daneben (`git worktree add ../Forever-Hunter-Pets-<Nr> <branch>`).
    1. Issue „Release <version>“ mit Plan, Freigabe wie bei jedem Issue.
    2. `git switch -c release/<version> develop`; Version im TOC, Abschnitt in `CHANGELOG.md`, Stand in `CLAUDE.md` und `konzept.md`. **Datum des Releases** ist der Tag, an dem der Release-Branch angelegt wird, unabhängig von der Veröffentlichung (Regel des Nutzers, 18.10.2026).
    3. Probelauf der Action auf dem Release-Branch (Actions → Release → *Run workflow*, ohne Upload) und das ZIP daraus prüfen.
    4. Status *Testing*: Abschlusstest des Maintainers am lokalen Release-Branch, Schritt für Schritt im Issue – **nur, was im Release neu ist** (Version, Release Notes, Korrekturen im Release-Branch, Paket); die einzelnen Issues sind schon getestet und werden nicht noch einmal geprüft. Korrekturen im Release-Branch.
    5. **Erst nach *Test passed*:** PR `release/<version>` → `main`, Status *In pull request*. Der PR listet alles auf, was im Release steckt, und verweist auf jedes Issue und jeden PR (Zusammenfassung zur Abnahme). Der Maintainer mergt.
    6. Tag `v<version>` auf den Merge-Commit in `main` und pushen – erst nach ausdrücklichem OK des Maintainers, denn das Tag veröffentlicht sofort.
    7. PR `release/<version>` → `develop`, knapp; der Maintainer mergt. Release-Branch löschen, Issue schließen.
  - **Vor 1.0.0 ist alles Beta** (Nutzer, 17.10.2026; seit 18.10.2026 überall mit Zusatz): Tag `v<version>-beta`, Branch `release/<version>-beta`, Version im TOC `<version>-beta`, Abschnitt im CHANGELOG `<version>-beta`, etwa `0.9.0-beta`. Ab 1.0.0 ohne Zusatz. Der Zusatz steuert den Typ auf CurseForge (siehe „Veröffentlichen“). `v0.8.0` stammt von vor dieser Regel.
- **Issue, Branch, PR** (Regel des Nutzers, 17.10.2026):
  - **Ablauf eines Issues** (Regel des Nutzers, 17.10.2026), abgebildet in der Spalte *Status* des Projects:

    | Status | Bedeutung | Wer handelt |
    | --- | --- | --- |
    | Todo | noch nicht begonnen | – |
    | Approved | vom Maintainer freigegeben; der Umsetzungsplan wird geschrieben | Claude: Plan als Kommentar ins Issue |
    | Ready | Umsetzungsplan steht, wartet auf Freigabe | Maintainer: Plan freigeben oder ändern |
    | Ready for development | Plan freigegeben, die Arbeit kann beginnen | Claude: umsetzen |
    | In Progress | wird bearbeitet | Claude |
    | Test failed | Test im Spiel fehlgeschlagen; Befund steht im Issue | Claude: nachbessern oder Diagnose anfragen |
    | Testing | wartet auf den Test im Spiel oder wird getestet | Maintainer: testen, Ergebnis ins Issue |
    | Test passed | getestet, wartet auf den PR | Claude: Commit, Push, PR |
    | In pull request | PR offen, wartet auf Review und Merge | Maintainer: mergen |
    | Done | gemergt nach `develop` und geschlossen (automatisch über `Closes #<Nr>`) | Claude: aufräumen |

    Ohne Freigabe des Maintainers wird weder ein Plan geschrieben (*Approved*) noch umgesetzt (*Ready for development*). Der Umsetzungsplan steht als Kommentar im Issue: was sich ändert und wo, Bewertung nach Mehrwert, Komplexität und Risiko, was geprüft wird und was der Maintainer testen soll. Den Status setzt, wer gerade handelt. Nur *Test passed* setzt immer der Maintainer selbst, Claude nur auf seine ausdrückliche Bitte (22.10.2026); auch ein vollständig abgehakter Testauftrag ist noch keine Abnahme. Soll der Maintainer (wieder) testen, kommt das Issue nach *Testing*, und der Kommentar beschreibt **Schritt für Schritt**, was er tun soll – vom `/reload` über jeden Klick bis zu dem, was er zurückmelden soll.
  - **Issue:** Jede Änderung hat ein GitHub-Issue. Gibt es keins, wird eins angelegt.
  - **Branch:** `feature/<Nr>-<issue-titel-als-slug>`, Titel klein, Wörter mit Bindestrich, etwa `feature/3-tiernamen-in-der-sprache-des-clients`, Umlaute als ae, oe, ue, ss. Gemeint ist das Muster „[Issue-Nummer] [Issue-Name]“; Git erlaubt in Branch-Namen weder Leerzeichen noch eckige Klammern.
  - **Commits:** `#<Nr> <Issue-Titel> => <was im Commit passiert ist>`, etwa `#3 Tiernamen in der Sprache des Clients => Namen aus der Sichtung vor den Daten`. Bei einem englischen Issue bleibt der Titel englisch, der Teil nach `=>` ist deutsch wie alle Commit-Meldungen.
  - **Pull Request:** Nach `develop` kommt nichts direkt, nur per PR, in der Sprache des Issues. Er erklärt genau, **was** geändert wurde, **warum** und **welche Folgen** es hat (Daten, Speicher, Verkehr im Kanal, Verhalten im Spiel, Doku), dazu, was wie geprüft ist. Der PR-Text beginnt mit `Closes #<Nr>`, auch bei einem deutschen PR (Regel des Nutzers, 20.10.2026): GitHub versteht nur englische Schlüsselwörter (`Closes`, `Fixes`, `Resolves`), „Schließt #47“ verknüpft nichts. Weil `develop` der Standard-Branch ist, schließt schon der Merge nach `develop` das Issue, und die Automatik des Projects setzt es auf *Done*. Release-PRs nach `main` tragen kein `Closes`. **Definition of Done:** Das Issue ist dokumentiert, lokal im Spiel getestet und nach `develop` gemergt. Gemergt wird erst nach dem Test im Spiel.
  - **Test im Spiel:** Was der Maintainer im Spiel prüfen soll, kommt als Kommentar ins Issue (Checkliste in der Sprache des Issues mit Schritten und erwartetem Ergebnis), sobald es bereitsteht. So ist es auch in der nächsten Sitzung auffindbar; das Ergebnis wird dort ebenfalls festgehalten.
  - **Ausnahmen** sind erlaubt, wenn sie vorher abgesprochen sind: etwa kein Issue für eine Kleinigkeit, mehrere Issues in einem Branch (dann `feature/<Nr>-<Nr>-<slug>` und `#<Nr> #<Nr> …` in den Commits) oder ein Commit direkt auf `develop`. Die Regel soll Überblick und ein ruhiges Review jeder Änderung ermöglichen, nicht verbieten.
- **Inkremente:** ein Schritt nach dem anderen, jeder im Spiel prüfbar. Committet und gemergt wird, nachdem der Schritt im Spiel getestet ist.
- **Meilensteine, Vorhaben, Pläne und Änderungswünsche** stehen auf GitHub: Meilensteine als Milestones, Aufgaben als Issues mit Label (`bug`, `enhancement`, `data`, `documentation`), alles im öffentlichen Project „Forever Hunter Pets“.
- **Moderation:** Fremde können Issues anlegen und kommentieren – gewollt für Fehler und Funde. Die Vorlagen (`.github/ISSUE_TEMPLATE/`) helfen nur, Pflichtfelder gibt es keine, Freitext bleibt erlaubt. Regeln in `CODE_OF_CONDUCT.md`. Bei Störungen: Kommentar ausblenden (*Hide*, Grund Spam/Missbrauch/Off-Topic), Gespräch sperren (*Lock conversation*), Person blockieren (Profil-Einstellungen → *Blocked users*, gilt für alle Repos), bei einer Welle zeitweise *Settings → Moderation → Interaction limits*. Dauerhaft wird nichts eingeschränkt. Das Wiki ist aus, Discussions auch; das Project ist öffentlich, aber nur für den Maintainer bearbeitbar.
- **Version:** `## Version` in `Forever-Hunter-Pets.toc`. Auf `develop` und in Feature-Branches bleibt dort die Nummer des letzten Releases stehen; erhöht wird sie **erst im Branch `release/<version>`**, als Teil des Releases (vor 1.0.0 mit `-beta`). So entsteht keine Nummer, die nie veröffentlicht wird (0.4.0 wurde so übersprungen, entschieden am 14.10.2026).
  - **Schema:** Ein Release aus `develop` erhöht die mittlere Ziffer (0.5.0 → 0.6.0). Die letzte Ziffer bleibt Hotfixes vorbehalten: `hotfix/0.5.1` geht von `main` ab, bekommt die Nummer 0.5.1 und wird nach `main` (Tag `v0.5.1`) und zurück nach `develop` gemergt. Weil `develop` die Nummer nie vorab erhöht, gibt es dabei keinen Konflikt um die Versionszeile.
- **Sprache:** Doku, Konzepte, Kommentare und Commit-Meldungen deutsch; README, NOTICE, CONTRIBUTING, CODE_OF_CONDUCT, CHANGELOG, die Vorlagen in `.github/` und die Anleitung englisch.
  - **Sprache der Issues** (Regel des Nutzers, 17.10.2026): Issues, die wir selbst anlegen, sind deutsch und werden deutsch bearbeitet – Titel, Beschreibung, Kommentare, Testaufträge, Branch-Name, Commit-Titel und PR. Ein Issue, das jemand anderes in einer anderen Sprache anlegt, wird auf Englisch bearbeitet (Kommentare, PR). Mit dem Nutzer wird immer deutsch gesprochen, auch wenn das Issue englisch ist. Grund: Deutsch ist die Muttersprache des Maintainers; so wird besser gearbeitet. Die Vorlagen in `.github/` bleiben englisch, damit jeder melden kann.
  - Oberflächentexte des Addons englisch als Schlüssel, deutsch in `Locales/deDE.lua`.

## Lizenz und Fremdinhalte

In die Daten kommt nur, was im Spiel selbst erhoben wurde oder was der Client zur Laufzeit liefert (entschieden am 15.10.2026, siehe [entscheidungen.md](../konzept/entscheidungen.md)). Daten von fremden Seiten und aus fremden Addons kommen nicht hinein. Jede Quelle wird in [NOTICE.md](../../NOTICE.md) genannt.
