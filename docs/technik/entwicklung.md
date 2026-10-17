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
  - `develop` ist der Arbeitsstand. Dort wird gearbeitet, bis ein Release ansteht. Kleinigkeiten werden direkt auf `develop` committet.
  - `feature/<thema>` ist für alles Umfangreichere: Der Branch geht von `develop` ab und wird mit `--no-ff` dorthin zurückgemergt; danach wird der Branch lokal und auf origin gelöscht.
  - `release/<version>` geht von `develop` ab, wird getestet, bekommt nur noch Korrekturen und die Versionsnummer, und wird dann nach `main` **und** zurück nach `develop` gemergt. Der Merge auf `main` bekommt das Tag `v<version>`.
  - `hotfix/<version>` geht von `main` ab und wird ebenfalls nach `main` und `develop` gemergt.
  - `main` enthält nur veröffentlichte Stände.
  - **Geschützt** (Ruleset „Protect develop and main“ auf GitHub, 17.10.2026): `develop` und `main` lassen sich nicht löschen und nicht per Force-Push überschreiben; Änderungen kommen nur per Pull Request mit einer Freigabe hinein. Ausgenommen ist die Rolle „Repository admin“ – der Maintainer pusht und mergt weiter direkt (GitHub meldet das als „Bypassed rule violations“).
  - **Vorerst:** Bis zur ersten Produktivversion (Entscheidung des Nutzers, 17.10.2026) gibt es **keinen Release-Branch**: Ein Release erhöht die Version im TOC direkt auf `develop` und wird von dort mit `--no-ff` nach `main` gemergt, Tag `v<version>` auf `main`. Getestet wird ohnehin laufend; Release-Branches kommen, sobald es eine richtige Produktivversion gibt.
  - **Tags vor 1.0.0 sind Betas** (Nutzer, 17.10.2026): `v<version>-beta`, etwa `v0.9.0-beta`; die Version im TOC bleibt `0.9.0`. Ab `v1.0.0` ohne Zusatz. Der Zusatz steuert den Typ auf CurseForge (siehe „Veröffentlichen“). `v0.8.0` stammt von vor dieser Regel.
- **Inkremente:** ein Schritt nach dem anderen, jeder im Spiel prüfbar. Committet wird, nachdem der Schritt im Spiel getestet ist.
- **Meilensteine, Vorhaben, Pläne und Änderungswünsche** stehen auf GitHub: Meilensteine als Milestones, Aufgaben als englische Issues mit Label (`bug`, `enhancement`, `data`, `documentation`), alles im öffentlichen Project „Forever Hunter Pets“. Commits nennen ihr Issue (`(#n)`), der letzte schließt es (`Fixes #n`).
- **Moderation:** Fremde können Issues anlegen und kommentieren – gewollt für Fehler und Funde. Die Vorlagen (`.github/ISSUE_TEMPLATE/`) helfen nur, Pflichtfelder gibt es keine, Freitext bleibt erlaubt. Regeln in `CODE_OF_CONDUCT.md`. Bei Störungen: Kommentar ausblenden (*Hide*, Grund Spam/Missbrauch/Off-Topic), Gespräch sperren (*Lock conversation*), Person blockieren (Profil-Einstellungen → *Blocked users*, gilt für alle Repos), bei einer Welle zeitweise *Settings → Moderation → Interaction limits*. Dauerhaft wird nichts eingeschränkt. Das Wiki ist aus, Discussions auch; das Project ist öffentlich, aber nur für den Maintainer bearbeitbar.
- **Version:** `## Version` in `Forever-Hunter-Pets.toc`. Auf `develop` und in Feature-Branches bleibt dort die Nummer des letzten Releases stehen; erhöht wird sie **erst im Branch `release/<version>`**, als Teil des Releases. So entsteht keine Nummer, die nie veröffentlicht wird (0.4.0 wurde so übersprungen, entschieden am 14.10.2026).
  - **Schema:** Ein Release aus `develop` erhöht die mittlere Ziffer (0.5.0 → 0.6.0). Die letzte Ziffer bleibt Hotfixes vorbehalten: `hotfix/0.5.1` geht von `main` ab, bekommt die Nummer 0.5.1 und wird nach `main` (Tag `v0.5.1`) und zurück nach `develop` gemergt. Weil `develop` die Nummer nie vorab erhöht, gibt es dabei keinen Konflikt um die Versionszeile.
- **Sprache:** Doku, Kommentare und Commit-Meldungen deutsch; README, NOTICE, CONTRIBUTING, CODE_OF_CONDUCT, CHANGELOG, die Vorlagen in `.github/` und die Anleitung englisch, Issues englisch. Oberflächentexte des Addons englisch als Schlüssel, deutsch in `Locales/deDE.lua`.

## Lizenz und Fremdinhalte

In die Daten kommt nur, was im Spiel selbst erhoben wurde oder was der Client zur Laufzeit liefert (entschieden am 15.10.2026, siehe [entscheidungen.md](../konzept/entscheidungen.md)). Daten von fremden Seiten und aus fremden Addons kommen nicht hinein. Jede Quelle wird in [NOTICE.md](../../NOTICE.md) genannt.
