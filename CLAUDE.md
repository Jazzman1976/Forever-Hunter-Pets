# Forever Hunter Pets

Ein Addon für WoW Forever (Client `## Interface: 16001`): Es zeigt Jägern, welches Tier welchen Rang einer Pet-Fähigkeit beibringt und wo es steht, und führt den Lernstand. Die Daten sammeln die Spieler selbst im Spiel; Suchen und Sammeln ist Teil des Spiels (Leitbild in `docs/konzept/konzept.md`). Veröffentlicht werden soll es bei CurseForge.

**Stand:** Meilenstein M1 „Eigene Daten“ ist abgeschlossen und auf `develop` (16.10.2026): keine fremden Daten mehr; gesammelt wird im Spiel über Erhebung (`Core/Survey.lua`), Sichtung (`Core/Sightings.lua`), Zähmen (`Core/Observe.lua`) und Fundort-Zellen (`Core/Places.lua`). M2 „Entdecken“ ist abgeschlossen (17.10.2026, Release 0.6.0 auf `main`): Entdeckermodus, Reiter „Gebiet“, Fährten und Witterung; Erfolge (E8) und M3 Design sind zurückgestellt, bis es mehr eigene Daten gibt. M4 Veröffentlichung läuft (17.10.2026: Release 0.7.0 mit `/fhp teilen`, öffentliches Repo, Beta 0.8.0 auf CurseForge, Projekt-ID 1750003), dann M5 Beta-Test – siehe „Meilensteine und Stand“ in `docs/konzept/konzept.md`. Pläne und Aufgaben sollen künftig als GitHub-Issues (englisch) geführt werden; dieser Umzug ist ein eigener Meilenstein. Vorschläge werden nach Mehrwert, Komplexität und Risiko (in dieser Reihenfolge, je 1–10) bewertet.

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
node tools/import-observations.mjs <WoW-Ordner>   # Erhebung, Sichtungen, Zähmungen, Zellen und eigene Kürzel aus den SavedVariables nach tools/eigene/
node tools/package.mjs               # Addon-Paket (ZIP) nach .ignore/dist/
```

Es gibt keinen Build, keine Tests und keinen Linter im Repo.

## Regeln

- **Generiert, nie von Hand bearbeiten:** `tools/data.json`, `Data/Data.lua`. Daten werden in `tools/eigene/` gepflegt.
- **Nur eigene Daten:** In die Daten kommt nur, was im Spiel selbst erhoben wurde (Ausbildungsfenster, Anvisieren, Zähmen, Befund) oder was der Client zur Laufzeit liefert. Jeder Eintrag in `tools/eigene/` braucht einen Beleg (`beleg` bzw. `quelle` und `datum`). Daten von fremden Seiten oder aus fremden Addons kommen nie ins Repo oder ins Addon.
- **Lizenz:** Code und selbst erhobene Daten sind MIT. Ins Addon kommt nichts aus fremden Addons (weder Code noch Datentabellen). Jede neue Quelle (nur mit ausdrücklicher schriftlicher Erlaubnis) gehört in `NOTICE.md` und `docs/technik/quellen.md`.
- **Öffentliches Repo:** Alles hier ist öffentlich. Keine Namen fremder Datenquellen, keine Anleitungen oder Zahlen zum Scraping, keine unbewiesenen Behauptungen über andere Projekte, nichts, was man uns später vorwerfen kann – im Zweifel weglassen.
- **Sprache:** Doku, Kommentare, Commit-Meldungen deutsch. Nur `README.md`, `NOTICE.md`, `CONTRIBUTING.md`, die Anleitung `docs/guide/guide.md` und Issues sind englisch. Addon-Texte: englischer Text ist der Schlüssel in `L[]`, die Übersetzung steht in `Locales/deDE.lua`.
- **Barrierefreiheit:** Kein Zustand wird nur durch Farbe unterschieden, immer auch durch ein Symbol oder ein Wort.
- **Testen:** Auf dem Entwicklungsrechner ist kein Lua installiert, und das Spiel lässt sich nicht automatisch starten. Syntax über `luaparse`, Logik über `fengari` mit nachgebildeter WoW-API; den Test im Spiel macht ein Mensch. Bei jeder UI-Änderung dazusagen, dass die Optik ungeprüft ist.
- **Ablauf (GitFlow nach Atlassian):** Gearbeitet wird auf `develop`: Kleinigkeiten direkt dort, Umfangreicheres in `feature/<thema>`, das von `develop` abgeht und mit `--no-ff` dorthin zurückkommt. Für ein Release wird `release/<version>` abgezweigt, getestet und nach `main` und zurück nach `develop` gemergt. `main` bekommt nur Releases – bis zum Release nichts nach `main` mergen. Ein Inkrement nach dem anderen; Commit erst nach dem Test im Spiel; Feature-Branch nach dem Merge löschen. Die Versionsnummer im TOC wird erst im Release-Branch erhöht, nie vorher – sonst entstehen übersprungene Versionen. Bis zur ersten Produktivversion (Entscheidung des Nutzers, 17.10.2026) gibt es **keinen Release-Branch**: Ein Release erhöht die Version im TOC direkt auf `develop` und wird von dort mit `--no-ff` nach `main` gemergt, Tag `v<version>` auf `main`. Getestet wird ohnehin laufend; Release-Branches kommen, sobald es eine richtige Produktivversion gibt. Releases erhöhen die mittlere Ziffer, die letzte ist für Hotfixes von `main` reserviert. Einzelheiten in docs/technik/entwicklung.md.
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
