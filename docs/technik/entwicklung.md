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

`/fhp api` schreibt ein API-Protokoll dorthin (`ForeverHunterPetsDB.probe`). So kommt Spielausgabe in eine Datei, ohne dass jemand Chatzeilen abtippt.

## Prüfen ohne Spiel

Zwei npm-Pakete, in einem Ordner außerhalb des Repos installiert:

- **`luaparse`** (Lua 5.1) prüft die Syntax.
- **`fengari`** führt das Addon gegen eine nachgebildete WoW-API aus: alle Dateien der TOC laden, `ADDON_LOADED` und `PLAYER_LOGIN` auslösen, Fenster und Ansichten öffnen. Achtung: fengari rechnet mit 32-Bit-Ganzzahlen. Rechnungen über 2^31 (etwa das Melder-Kürzel mit `("%08x"):format(h)`) melden dort Fehler, die es im Client nicht gibt; die Nachbildung sollte `string.format` für `%08x` deshalb über die beiden Hälften rechnen.

`luaparse` übersieht ungültige Escapes wie `"Interface\Icons"` – die findet erst `fengari`. Aussehen und echte Client-Aufrufe zeigt nur der Test im Spiel.

## Daten bauen

```
node tools/import-observations.mjs <WoW-Ordner>   # Erhebung, Sichtungen, Zähmungen, Fundort-Zellen und eigene Kürzel nach tools/eigene/
node tools/build-data.mjs      # tools/data.json; bricht ab, wenn einer Angabe der Beleg fehlt
node tools/build-addon.mjs     # erzeugt Data/Data.lua
```

Die Skripte melden am Ende, was auffällt – `build-data.mjs` etwa Widersprüche zwischen Zähmungen derselben NPC-ID oder TP, die nicht zueinander passen. Ein Lauf ohne Änderung an Code oder Daten darf `tools/data.json` nur im Feld `generatedAt` verändern. `tools/lua-table.mjs` liest SavedVariables-Dateien und wird vom Import benutzt.

## Paket bauen

```
node tools/package.mjs            # ZIP nach .pkgmeta in .ignore/dist/, Ordner Forever-Hunter-Pets/, Version aus dem TOC
```

Das Paket enthält alle von git verfolgten Dateien ohne das, was `.pkgmeta` ausnimmt, und ohne Punkt-Dateien – im Stand der Arbeitskopie. Es geht an Tester; 0.8.0 ging so von Hand zu CurseForge.

**Veröffentlichen** übernimmt seit 0.8.0 die GitHub Action `.github/workflows/release.yml` (BigWigs-Packager): Jedes gepushte Tag `v*` wird gepackt und nach CurseForge hochgeladen (Projekt-ID aus `## X-Curse-Project-ID` im TOC) und als GitHub-Release mit ZIP angelegt. Den Typ bestimmt der Tag-Name: `-beta` → Beta, `-alpha` → Alpha, sonst Release. Changelog ist `CHANGELOG.md` (englisch, `manual-changelog` in `.pkgmeta`), vor jedem Release oben um die neue Version ergänzen. Das CurseForge-API-Token liegt als Secret `CF_API_KEY` im Repo. Von Hand gestartet (Actions → Release → Run workflow) baut die Action nur probeweise, ohne Upload, und hängt das ZIP an den Lauf.

## Ablauf

- **Branches: GitFlow nach Atlassian.**
  - `develop` ist der Arbeitsstand. Direkt dorthin wird nichts committet (seit 17.10.2026, siehe „Issue, Branch, PR“).
  - `feature/<Nr>-<issue-titel-als-slug>` für jede Änderung: Der Branch geht von `develop` ab und kommt per Pull Request mit Merge-Commit (`--no-ff`) dorthin zurück; danach wird er lokal und auf origin gelöscht.
  - `release/<version>` geht von `develop` ab, wird getestet, bekommt nur noch Korrekturen und die Versionsnummer, und wird dann nach `main` **und** zurück nach `develop` gemergt. Der Merge auf `main` bekommt das Tag `v<version>`.
  - `hotfix/<version>` geht von `main` ab und wird ebenfalls nach `main` und `develop` gemergt.
  - `main` enthält nur veröffentlichte Stände.
  - **Geschützt** (Ruleset „Protect develop and main“ auf GitHub, 17.10.2026): `develop` und `main` lassen sich nicht löschen und nicht per Force-Push überschreiben; Änderungen kommen nur per Pull Request mit einer Freigabe hinein. Ausgenommen ist die Rolle „Repository admin“ – der Maintainer pusht und mergt weiter direkt (GitHub meldet das als „Bypassed rule violations“).
  - **Vorerst:** Bis zur ersten Produktivversion (Entscheidung des Nutzers, 17.10.2026) gibt es **keinen Release-Branch**: Ein Release erhöht die Version im TOC direkt auf `develop` und wird von dort mit `--no-ff` nach `main` gemergt, Tag `v<version>` auf `main`. Getestet wird ohnehin laufend; Release-Branches kommen, sobald es eine richtige Produktivversion gibt.
  - **Tags vor 1.0.0 sind Betas** (Nutzer, 17.10.2026): `v<version>-beta`, etwa `v0.9.0-beta`; die Version im TOC bleibt `0.9.0`. Ab `v1.0.0` ohne Zusatz. Der Zusatz steuert den Typ auf CurseForge (siehe „Veröffentlichen“). `v0.8.0` stammt von vor dieser Regel.
- **Issue, Branch, PR** (Regel des Nutzers, 17.10.2026):
  - **Ablauf eines Issues** (Regel des Nutzers, 17.10.2026), abgebildet in der Spalte *Status* des Projects:

    | Status | Bedeutung | Wer handelt |
    | --- | --- | --- |
    | Todo | noch nicht begonnen | – |
    | Approved | vom Maintainer freigegeben; der Umsetzungsplan wird geschrieben | Claude: Plan als Kommentar ins Issue |
    | Ready | Umsetzungsplan steht, wartet auf Freigabe | Maintainer: Plan freigeben oder ändern |
    | Ready for development | Plan freigegeben, die Arbeit kann beginnen | Claude: umsetzen |
    | In Progress | wird bearbeitet | Claude |
    | Testing | wartet auf den Test im Spiel oder wird getestet | Maintainer: testen, Ergebnis ins Issue |
    | Test passed | getestet, wartet auf den PR | Claude: Commit, Push, PR |
    | In pull request | PR offen, wartet auf Review und Merge | Maintainer: mergen |
    | Done | gemergt und geschlossen | Claude: aufräumen |

    Ohne Freigabe des Maintainers wird weder ein Plan geschrieben (*Approved*) noch umgesetzt (*Ready for development*). Der Umsetzungsplan steht als Kommentar im Issue: was sich ändert und wo, Bewertung nach Mehrwert, Komplexität und Risiko, was geprüft wird und was der Maintainer testen soll. Den Status setzt, wer gerade handelt.
  - **Issue:** Jede Änderung hat ein GitHub-Issue. Gibt es keins, wird eins angelegt.
  - **Branch:** `feature/<Nr>-<issue-titel-als-slug>`, Titel klein, Wörter mit Bindestrich, etwa `feature/3-tiernamen-in-der-sprache-des-clients`, Umlaute als ae, oe, ue, ss. Gemeint ist das Muster „[Issue-Nummer] [Issue-Name]“; Git erlaubt in Branch-Namen weder Leerzeichen noch eckige Klammern.
  - **Commits:** `#<Nr> <Issue-Titel> => <was im Commit passiert ist>`, etwa `#3 Tiernamen in der Sprache des Clients => Namen aus der Sichtung vor den Daten`. Bei einem englischen Issue bleibt der Titel englisch, der Teil nach `=>` ist deutsch wie alle Commit-Meldungen.
  - **Pull Request:** Nach `develop` kommt nichts direkt, nur per PR, in der Sprache des Issues. Er erklärt genau, **was** geändert wurde, **warum** und **welche Folgen** es hat (Daten, Speicher, Verkehr im Kanal, Verhalten im Spiel, Doku), dazu, was wie geprüft ist. `Fixes #<Nr>` im PR schließt das Issue beim Merge. Gemergt wird erst nach dem Test im Spiel.
  - **Test im Spiel:** Was der Maintainer im Spiel prüfen soll, kommt als Kommentar ins Issue (Checkliste in der Sprache des Issues mit Schritten und erwartetem Ergebnis), sobald es bereitsteht. So ist es auch in der nächsten Sitzung auffindbar; das Ergebnis wird dort ebenfalls festgehalten.
  - **Ausnahmen** sind erlaubt, wenn sie vorher abgesprochen sind: etwa kein Issue für eine Kleinigkeit, mehrere Issues in einem Branch (dann `feature/<Nr>-<Nr>-<slug>` und `#<Nr> #<Nr> …` in den Commits) oder ein Commit direkt auf `develop`. Die Regel soll Überblick und ein ruhiges Review jeder Änderung ermöglichen, nicht verbieten.
- **Inkremente:** ein Schritt nach dem anderen, jeder im Spiel prüfbar. Committet und gemergt wird, nachdem der Schritt im Spiel getestet ist.
- **Meilensteine, Vorhaben, Pläne und Änderungswünsche** stehen auf GitHub: Meilensteine als Milestones, Aufgaben als Issues mit Label (`bug`, `enhancement`, `data`, `documentation`), alles im öffentlichen Project „Forever Hunter Pets“.
- **Moderation:** Fremde können Issues anlegen und kommentieren – gewollt für Fehler und Funde. Die Vorlagen (`.github/ISSUE_TEMPLATE/`) helfen nur, Pflichtfelder gibt es keine, Freitext bleibt erlaubt. Regeln in `CODE_OF_CONDUCT.md`. Bei Störungen: Kommentar ausblenden (*Hide*, Grund Spam/Missbrauch/Off-Topic), Gespräch sperren (*Lock conversation*), Person blockieren (Profil-Einstellungen → *Blocked users*, gilt für alle Repos), bei einer Welle zeitweise *Settings → Moderation → Interaction limits*. Dauerhaft wird nichts eingeschränkt. Das Wiki ist aus, Discussions auch; das Project ist öffentlich, aber nur für den Maintainer bearbeitbar.
- **Version:** `## Version` in `Forever-Hunter-Pets.toc`. Auf `develop` und in Feature-Branches bleibt dort die Nummer des letzten Releases stehen; erhöht wird sie **erst im Branch `release/<version>`**, als Teil des Releases. So entsteht keine Nummer, die nie veröffentlicht wird (0.4.0 wurde so übersprungen, entschieden am 14.10.2026).
  - **Schema:** Ein Release aus `develop` erhöht die mittlere Ziffer (0.5.0 → 0.6.0). Die letzte Ziffer bleibt Hotfixes vorbehalten: `hotfix/0.5.1` geht von `main` ab, bekommt die Nummer 0.5.1 und wird nach `main` (Tag `v0.5.1`) und zurück nach `develop` gemergt. Weil `develop` die Nummer nie vorab erhöht, gibt es dabei keinen Konflikt um die Versionszeile.
- **Sprache:** Doku, Konzepte, Kommentare und Commit-Meldungen deutsch; README, NOTICE, CONTRIBUTING, CODE_OF_CONDUCT, CHANGELOG, die Vorlagen in `.github/` und die Anleitung englisch.
  - **Sprache der Issues** (Regel des Nutzers, 17.10.2026): Issues, die wir selbst anlegen, sind deutsch und werden deutsch bearbeitet – Titel, Beschreibung, Kommentare, Testaufträge, Branch-Name, Commit-Titel und PR. Ein Issue, das jemand anderes in einer anderen Sprache anlegt, wird auf Englisch bearbeitet (Kommentare, PR). Mit dem Nutzer wird immer deutsch gesprochen, auch wenn das Issue englisch ist. Grund: Deutsch ist die Muttersprache des Maintainers; so wird besser gearbeitet. Die Vorlagen in `.github/` bleiben englisch, damit jeder melden kann.
  - Oberflächentexte des Addons englisch als Schlüssel, deutsch in `Locales/deDE.lua`.

## Lizenz und Fremdinhalte

In die Daten kommt nur, was im Spiel selbst erhoben wurde oder was der Client zur Laufzeit liefert (entschieden am 15.10.2026, siehe [entscheidungen.md](../konzept/entscheidungen.md)). Daten von fremden Seiten und aus fremden Addons kommen nicht hinein. Jede Quelle wird in [NOTICE.md](../../NOTICE.md) genannt.
