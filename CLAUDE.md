# Forever Hunter Pets

Ein Addon für WoW Forever (Client `## Interface: 16001`): Es zeigt Jägern, welches Tier welchen Rang einer Pet-Fähigkeit beibringt und wo es steht, und führt den Lernstand. Die Daten sammeln die Spieler selbst im Spiel; Suchen und Sammeln ist Teil des Spiels (Leitbild in `docs/konzept/konzept.md`). Veröffentlicht werden soll es bei CurseForge.

**Stand:** Meilenstein M1 „Eigene Daten“ ist abgeschlossen und auf `develop` (16.10.2026): keine fremden Daten mehr; gesammelt wird im Spiel über Erhebung (`Core/Survey.lua`), Sichtung (`Core/Sightings.lua`), Zähmen (`Core/Observe.lua`) und Fundort-Zellen (`Core/Places.lua`). M2 „Entdecken“ ist abgeschlossen (17.10.2026, Release 0.6.0 auf `main`): Entdeckermodus, Reiter „Gebiet“, Fährten und Witterung; Erfolge (E8) und M3 Design sind zurückgestellt, bis es mehr eigene Daten gibt. M4 Veröffentlichung ist abgeschlossen (17.10.2026: Release 0.7.0 mit `/fhp teilen`, öffentliches Repo, Beta 0.8.0 auf CurseForge, Projekt-ID 1750003, automatischer Upload); M5 Beta-Test läuft, Release 0.9.0-beta mit #1–#5 (18.10.2026), Release 0.10.0-beta mit #12–#32 (18.10.2026) – siehe „Meilensteine und Stand“ in `docs/konzept/konzept.md`. Meilensteine, Aufgaben und Pläne stehen seit 17.10.2026 auf GitHub: Milestones M1–M5, Issues, öffentliches Project „Forever Hunter Pets“ (https://github.com/users/Jazzman1976/projects/2); jede Änderung hat ein Issue, einen Branch und einen PR (siehe Regeln). Die privaten Pläne in `.ignore/plaene/` sind Archiv. Vorschläge werden nach Mehrwert, Komplexität und Risiko (in dieser Reihenfolge, je 1–10) bewertet.

## Aufbau

Die Wurzel des Repos ist der Addon-Ordner: Sie wird als `Interface/AddOns/Forever-Hunter-Pets` geklont oder per Junction eingehängt.

| Ordner | Inhalt |
| --- | --- |
| `Core/`, `UI/`, `Locales/`, `Data/`, `Forever-Hunter-Pets.toc` | das Addon (Lua, keine Fremdbibliotheken) |
| `tools/` | Node-Skripte ohne Abhängigkeiten |
| `tools/eigene/` | die selbst erhobenen Daten (JSON), die einzige Datenquelle |
| `docs/guide/` | Anleitung für Spieler (englisch) |
| `docs/konzept/` | Konzept, Entscheidungen, Arbeitsweise (deutsch) |
| `docs/technik/` | technische Dokumentation (deutsch) |
| `.ignore/` | privat, nicht im Repo: Screenshots, Arbeitsnotizen, Pakete |

`.pkgmeta` nimmt `tools/` und `docs/` aus dem CurseForge-Paket.

```
tools/eigene/*.json  ──>  tools/build-data.mjs  ──>  tools/data.json  ──>  tools/build-addon.mjs  ──>  Data/Data.lua
```

## Befehle

```
node tools/build-data.mjs            # tools/data.json aus tools/eigene/ (bricht ab, wenn ein Beleg fehlt)
node tools/build-addon.mjs           # Data/Data.lua aus tools/data.json
node tools/import-observations.mjs [--ohne-tierausbilder] <WoW-Ordner>   # Erhebung, Sichtungen, Zähmungen, Zellen, Herkunft und eigene Kürzel aus den SavedVariables nach tools/eigene/ (Schalter: docs/technik/entwicklung.md)
node tools/package.mjs               # Addon-Paket (ZIP) nach .ignore/dist/  (Veröffentlichen macht die Action beim Tag)
```

Es gibt keinen Build, keine Tests und keinen Linter im Repo.

## Regeln

- **Generiert, nie von Hand bearbeiten:** `tools/data.json`, `Data/Data.lua`. Daten werden in `tools/eigene/` gepflegt.
- **Nur eigene Daten:** In die Daten kommt nur, was im Spiel selbst erhoben wurde (Ausbildungsfenster, Anvisieren, Zähmen, Befund) oder was der Client zur Laufzeit liefert. Jeder Eintrag in `tools/eigene/` braucht einen Beleg (`beleg` bzw. `quelle` und `datum`). Daten von fremden Seiten oder aus fremden Addons kommen nie ins Repo oder ins Addon.
- **Lizenz:** Code und selbst erhobene Daten sind MIT. Ins Addon kommt nichts aus fremden Addons (weder Code noch Datentabellen). Jede neue Quelle (nur mit ausdrücklicher schriftlicher Erlaubnis) gehört in `NOTICE.md` und `docs/technik/quellen.md`.
- **Öffentliches Repo:** Alles hier ist öffentlich. Keine Namen fremder Datenquellen, keine Anleitungen oder Zahlen zum Scraping, keine unbewiesenen Behauptungen über andere Projekte, nichts, was man uns später vorwerfen kann – im Zweifel weglassen.
- **Sprache:** Doku, Konzepte, Kommentare, Commit-Meldungen deutsch. Nur `README.md`, `NOTICE.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, die Vorlagen in `.github/` und die Anleitung `docs/guide/guide.md` sind englisch. **Sprache der Issues** (Regel des Nutzers, 17.10.2026): Issues, die wir selbst anlegen, sind deutsch und werden deutsch bearbeitet – Titel, Beschreibung, Kommentare, Testaufträge, Branch-Name, Commit-Titel und PR. Ein Issue, das jemand anderes in einer anderen Sprache anlegt, wird auf Englisch bearbeitet (Kommentare, PR). Mit dem Nutzer wird immer deutsch gesprochen, auch wenn das Issue englisch ist. Addon-Texte: englischer Text ist der Schlüssel in `L[]`, die Übersetzung steht in `Locales/deDE.lua`.
- **Barrierefreiheit:** Kein Zustand wird nur durch Farbe unterschieden, immer auch durch ein Symbol oder ein Wort.
- **Testen:** Auf dem Entwicklungsrechner ist kein Lua installiert, und das Spiel lässt sich nicht automatisch starten. Syntax über `luaparse`, Logik über `fengari` mit nachgebildeter WoW-API; den Test im Spiel macht ein Mensch. Bei jeder UI-Änderung dazusagen, dass die Optik ungeprüft ist.
- **Status folgt dem Stand:** Steht ein PR, kommt das Issue direkt nach *In pull request*.
- **Ablauf je Issue (Regel des Nutzers, 17.10.2026):** Maintainer gibt frei (*Approved*) → Umsetzungsplan als Kommentar ins Issue (*Ready*) → Maintainer gibt den Plan frei (*Ready for development*) → umsetzen (*In Progress*) → Maintainer testet (*Testing*; fehlgeschlagen: *Test failed*, nachbessern; bestanden: *Test passed*) → PR (*In pull request*) → Maintainer mergt (*Done*). Nichts ohne Freigabe planen oder umsetzen; den Status im Project setzt, wer gerade handelt. Jeder (erneute) Testauftrag: Issue nach *Testing*, Kommentar beschreibt Schritt für Schritt, was zu tun und zurückzumelden ist. Tabelle in docs/technik/entwicklung.md.
- **Issue, Branch, PR (Regel des Nutzers, 17.10.2026):** Jede Änderung hat ein GitHub-Issue (sonst eins anlegen) und einen eigenen Branch `feature/<Nr>-<issue-titel-als-slug>` von `develop`, etwa `feature/3-tiernamen-in-der-sprache-des-clients` (Git erlaubt in Branch-Namen weder Leerzeichen noch eckige Klammern; Umlaute als ae, oe, ue, ss). Commit-Meldungen: `#<Nr> <Issue-Titel> => <was im Commit passiert ist>`. Nach `develop` kommt nichts direkt, nur per PR, und der PR erklärt genau, **was** geändert wurde, **warum** und **welche Folgen** es hat. Gemergt wird erst nach dem Test im Spiel. **Was der Nutzer testen soll, steht als Kommentar im Issue** (als Checkliste, in der Sprache des Issues), nicht nur im Chat – dort findet er es sitzungsübergreifend wieder. Ausnahmen (kein Issue, mehrere Issues in einem Branch, direkt auf `develop`) sind erlaubt, wenn sie vorher mit dem Nutzer abgesprochen sind – die Regel soll Überblick und ruhiges Review ermöglichen, nicht verbieten.
- **Ablauf (GitFlow nach Atlassian):** `feature/…` geht von `develop` ab und kommt per PR mit Merge-Commit (`--no-ff`) dorthin zurück. `main` bekommt nur Releases. Ein Inkrement nach dem anderen; Commit und Merge erst nach dem Test im Spiel; Feature-Branch nach dem Merge löschen. **Release:** Ein Release hat ein Issue. `release/<version>` (vor 1.0.0 mit `-beta`, etwa `release/0.9.0-beta`) geht von `develop` ab; erst dort werden die Version im TOC erhöht und die Release Notes in `CHANGELOG.md` (englisch, daraus macht die Action die Notizen für CurseForge und das GitHub-Release) geschrieben. Es folgen der Abschlusstest des Maintainers am lokalen Release-Branch (Status *Testing*, nur was im Release neu ist – nichts doppelt testen) und gegebenenfalls kleine Korrekturen im Release-Branch. Erst wenn der Test bestanden ist (noch kein PR vorher), kommt der Release-Branch **zuerst per PR nach `main`** (ausführlich, mit Zusammenfassung zur Abnahme und Verweisen auf alle Issues und PRs des Releases), danach per PR zurück nach `develop` (knapp: „Rückführung der Release-Änderungen nach `develop`, siehe PR #X“). Nach dem Merge in `main` bekommt der Merge-Commit das Tag `v<version>` – vor 1.0.0 `v<version>-beta`, etwa `v0.9.0-beta`; das Tag löst den Upload zu CurseForge und das GitHub-Release aus. Danach wird der Release-Branch gelöscht. Die Versionsnummer im TOC wird erst im Release-Branch erhöht, nie vorher – sonst entstehen übersprungene Versionen. Vor 1.0.0 trägt alles den Zusatz `-beta` (Branch, TOC, CHANGELOG, Tag). Releases erhöhen die mittlere Ziffer, die letzte ist für Hotfixes von `main` reserviert. Einzelheiten in docs/technik/entwicklung.md.
- **Pragmatisch vor aufwendig (Regel des Nutzers, 18.10.2026):** Gibt es für ein einfaches Problem eine pragmatische Lösung, ist sie besser als eine aufwendige. Vorschläge und Pläne nennen zuerst die einfachste Lösung, die das Problem behebt; Aufwendigeres nur, wenn sie nicht reicht.
- **Client-API:** In Kampf und Instanzen liefert der Client „secret values“. Alles aus der API läuft durch `ns.clean()`, der Lernstand wird nur außerhalb des Kampfs gelesen.
- **Lua-Texturpfade** (`"Interface\\Icons\\…"`) nicht über Shell-Heredocs schreiben – die halbieren Backslashes.

## Weiterlesen

| Seite | Wofür |
| --- | --- |
| [docs/konzept/konzept.md](docs/konzept/konzept.md) | **der rote Faden:** Leitbild, Grundsätze, Modi, Status, Fortschritt, Fundorte, Fährten, Belegung, alle Entscheidungen mit Begründung – zuerst lesen |
| [docs/konzept/entscheidungen.md](docs/konzept/entscheidungen.md) | Entscheidungen, die man dem Code nicht ansieht – vor Änderungen an Filtern und Lernstand lesen |
| [docs/konzept/arbeitsweise.md](docs/konzept/arbeitsweise.md) | wie gearbeitet wird und warum |
| [docs/guide/guide.md](docs/guide/guide.md) | Anleitung für Spieler (englisch); bei jeder sichtbaren Änderung mitpflegen |
| [docs/technik/entwicklung.md](docs/technik/entwicklung.md) | Einrichten, Junction in den Client, Prüfen ohne Spiel, Ablauf |
| [docs/technik/addon-technik.md](docs/technik/addon-technik.md) | Dateien des Addons, was vom Client kommt, Lernstand, Ausbilden, geheime Werte |
| [docs/technik/datenformat.md](docs/technik/datenformat.md) | Felder der Daten in `tools/eigene/`, `tools/data.json` und `Data.lua` |
| [docs/technik/quellen.md](docs/technik/quellen.md) | Sammelwege, Belegung, Grenzen der Daten, Rechte |
| [docs/technik/api-befunde.md](docs/technik/api-befunde.md) | was die Forever-API kann und was nicht, im Spiel geprüft |
