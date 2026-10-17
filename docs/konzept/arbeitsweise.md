# Arbeitsweise

Wie in diesem Projekt gearbeitet wird. Die Kurzfassung für Contributors steht in [entwicklung.md](../technik/entwicklung.md); hier steht das Warum.

- **Agil, ein Inkrement nach dem anderen.** Jedes muss für sich im Spiel prüfbar sein, bevor das nächste beginnt. Grund: Die Forever-API ist kaum dokumentiert, und fast jede Annahme musste im Spiel geprüft werden – große Schritte scheitern spät.
- **Commit erst nach dem Test im Spiel.** Den Test macht der Maintainer; aus dem Entwicklungswerkzeug heraus lässt sich WoW nicht starten.
- **Erst proben, dann bauen.** Unklare API-Fragen klärt eine Probe (`/fhp api` schreibt in die SavedVariables), nicht eine Vermutung. Ergebnisse stehen in [api-befunde.md](../technik/api-befunde.md).
- **Screenshots aus dem Spiel** legt der Maintainer lokal in `.ignore/` ab; der Ordner ist nicht eingecheckt.
- **Releases ohne Release-Branch, bis es eine Produktivversion gibt** (17.10.2026): Es gibt **keinen Release-Branch**: Ein Release erhöht die Version im TOC direkt auf `develop` und wird von dort mit `--no-ff` nach `main` gemergt, Tag `v<version>` auf `main`. Getestet wird ohnehin laufend; Release-Branches kommen, sobald es eine richtige Produktivversion gibt. Erstes so: 0.6.0.
- **GitFlow nach Atlassian** (seit 13.10.2026). Gearbeitet wird auf `develop`, und dort bleibt die Arbeit, bis ein Release gemacht wird; `main` bekommt nur Releases. Kleinigkeiten gehen direkt auf `develop`, Umfangreicheres in einen `feature/`-Branch; beizeiten entsteht ein `release/`-Branch, der getestet, nachgebessert und dann nach `main` und zurück nach `develop` gemergt wird. Vorher wurde jedes Feature direkt nach `main` gemergt. Gemergte Feature-Branches werden lokal und auf origin gelöscht – es bleiben keine Altbranches stehen.
- **Bekanntes, das nicht zum Auftrag gehört, wird genannt, aber nicht ungefragt angefasst.** Es wird als offener Punkt festgehalten.
- **Bei UI-Änderungen ehrlich sagen, was geprüft ist:** Logik lässt sich ohne Spiel und ohne Browser prüfen, Aussehen nicht.
- **Forever ändert sich wöchentlich**, solange die Beta läuft (Start: 04.11.2026). Erhobene Daten können veralten; ein Widerspruch zwischen Zähmungen derselben NPC-ID (Meldung von `tools/build-data.mjs`) ist oft das erste Zeichen.
- **Daten sammeln läuft neben der Entwicklung.** Gesammelt wird parallel; das ist keine Voraussetzung für neue Inkremente (16.10.2026).
- **Jeder Vorschlag wird bewertet** (Wunsch des Nutzers, 16.10.2026): Changes, Features und Anpassungen nach **Mehrwert** (Business Value), **Komplexität** und **Risiko** – in dieser Reihenfolge –, je auf einer Skala von 1 (gering) bis 10 (hoch), mit kurzer Begründung. So lässt sich vergleichen, was sich lohnt.
- **Gleiches sieht immer gleich aus und ist gleich** (Regel des Nutzers für immer, 16.10.2026). Derselbe Zustand bekommt im ganzen Addon dasselbe Element, Symbol und Wort – etwa das Kästchen aus „Fähigkeiten“ mit Haken für „bekannt“ auch im Reiter „Gebiet“, das Familien-Icon überall über `ns.FamilyIcon`. Neue Ansichten nehmen vorhandene Bausteine, statt eigene zu erfinden.
