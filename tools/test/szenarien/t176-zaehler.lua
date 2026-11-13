-- #176: Im Entdeckermodus zählt der Zähler „Tiere“ ab „Tier gefunden“ (gefunden und studiert), Lehrtiere und Ränge
-- weiter erst mit „Tier studiert“; die Fährte zählt nirgends. Komplettmodus unverändert.
-- Riesiger Waldschreiter (2323) lehrt nach den Stammdaten Ducken 2 (1753) und lebt im Dämmerwald (1439).
local L = NS.L
local de = NS.Locales.deDE
local NPC, MAP, DUCK2 = 2323, 1439, 1753

ForeverHunterPetsCharDB = { discover = true, modeChosen = true, loc = {}, seenIn = {} }
Login({ loc = {}, seenIn = {} })
ok(NS.Discovering(), "Entdeckermodus")
local p0 = NS.ZoneProgress(MAP)
ok(p0.beasts > 0 and p0.teachers > 0, "Grundgerüst: Tiere und Lehrtiere")
ok(p0.beastsKnown == 0 and p0.teachersKnown == 0 and p0.ranksFound == 0, "nichts gefunden: alles 0")

-- Fährte: zählt nicht
NS.db.seenIn[NPC] = tostring(MAP)
NS.char.seenIn[NPC] = tostring(MAP)
ok(NS.BeastStatus(NPC, MAP) == "track", "Fährte")
local p = NS.ZoneProgress(MAP)
ok(p.beastsKnown == 0, "Fährte zählt bei den Tieren nicht (" .. p.beastsKnown .. ")")
ok(p.track == 1, "aber im Status Fährte")

-- Fund: zählt bei den Tieren, nicht bei Lehrtieren und Rängen
NS.db.loc[NPC] = { [MAP] = "AA" }
NS.char.loc[NPC] = { [MAP] = "AA" }
ok(NS.BeastStatus(NPC, MAP) == "found", "gefunden")
p = NS.ZoneProgress(MAP)
ok(p.beastsKnown == 1, "Fund zählt bei den Tieren (" .. p.beastsKnown .. ")")
ok(p.teachersKnown == 0, "Fund zählt nicht bei den Lehrtieren")
ok(p.ranksFound == 0, "Fund zählt nicht bei den Rängen")
ok(p.found == 1 and p.known == 0, "Status: 1 gefunden, 0 studiert")

-- Zähmung: zählt überall, bei den Tieren nicht doppelt
NS.db.obs = NS.db.obs or {}
table.insert(NS.db.obs, ("%d;20;%d;;1792000100;"):format(NPC, DUCK2))
NS.ObservationsChanged()
ok(NS.BeastStatus(NPC, MAP) == "known", "studiert")
p = NS.ZoneProgress(MAP)
ok(p.beastsKnown == 1, "studiert zählt einmal bei den Tieren (" .. p.beastsKnown .. ")")
ok(p.teachersKnown == 1, "studiert zählt bei den Lehrtieren")
ok(p.ranksFound >= 1, "studiert zählt bei den Rängen (" .. p.ranksFound .. ")")
ok(p.known == 1, "Status: 1 studiert (Zahl der Chatmeldung)")

-- Komplettmodus: X der Tiere aus allem Bekannten, unabhängig von eigenen Funden
NS.char.discover = false
local c = NS.ZoneProgress(MAP)
ok(c.teachersKnown == c.teachers and c.ranksFound == c.ranks, "Komplettmodus: Lehrtiere und Ränge X = Y")
ok(c.beastsKnown >= 1, "Komplettmodus: Tiere mit bekannter Lehre (" .. c.beastsKnown .. ")")
NS.char.discover = true

-- Texte
ok(de["You have found %d of %d beasts"] == "Du hast %d von %d Tieren gefunden", "deutsch: Tiere gefunden")
ok((de["Doing so, you have discovered %d of %d ranks in this zone"]):format(3, 8)
  == "Dabei hast du 3 von 8 Rängen dieses Gebiets entdeckt", "deutsch: Ränge")
ok((de["For %d of %d beasts it is known what they teach"]):format(15, 22)
  == "Bei 15 von 22 Tieren ist bekannt, was sie lehren", "deutsch: Komplettmodus Tiere")
ok((L["Discovered: %s studied – %s: %d of %d beasts studied"]):format("Wolf", "Brachland", 4, 9)
  == "Entdeckt: Wolf studiert – Brachland: 4 von 9 Tieren studiert", "Chatmeldung beim Zähmen")
ok((L["The “%s” counter grows from “%s”, teaching beasts and ranks with “%s”."]):format(L["Beasts"],
  NS.StatusWord("found"), NS.StatusWord("known"))
  == "Der Zähler „Tiere“ wächst ab „Tier gefunden“, Lehrtiere und Ränge mit „Tier studiert“.", "Tooltip am Zähler")
