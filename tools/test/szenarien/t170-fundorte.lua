-- #170: Im Entdeckermodus zeigt die Karte eines Tiers in einer Zone alle bekannten Fundorte (Stammdaten, fremde
-- Zellen ab 3 Meldern, eigene), sobald es dort studiert ist; vorher nur die eigenen Zellen.
-- Riesiger Waldschreiter (2323) steht in den Stammdaten im Dämmerwald (1439).
local NPC, MAP, OTHER = 2323, 1439, 1436
local via = { a0000001 = "e0000001", a0000002 = "e0000002", a0000003 = "e0000003" }
local mine = "AA"   -- eine eigene Zelle
ForeverHunterPetsCharDB = { discover = true, modeChosen = true,
  seenIn = { [NPC] = tostring(MAP) }, loc = { [NPC] = { [MAP] = mine } } }
Login({ via = via, seenIn = { [NPC] = tostring(MAP) }, loc = { [NPC] = { [MAP] = mine } },
  locIn = { [NPC] = {
    [MAP] = { a0000001 = "0A", a0000002 = "0A", a0000003 = "0A" },        -- fremd, 3 Melder
    [OTHER] = { a0000001 = "1B", a0000002 = "1B", a0000003 = "1B" },      -- fremd in einer zweiten Zone
  } } })
local data = #NS.Coords(NPC, MAP)   -- noch Entdeckermodus: nur die eigene
ok(NS.Discovering(), "Entdeckermodus")
ok(NS.BeastStatus(NPC, MAP) == "found", "gefunden, nicht studiert")
ok(data == 1, "nur gefunden: nur die eigene Zelle (" .. data .. ")")
ok(NS.ZoneCounts(NPC)[MAP] == 1, "ZoneCounts: 1")
local full = NS.ZoneCounts(NPC, true)[MAP]
ok(full > 2, "voller Bestand: Stammdaten, fremde und eigene (" .. full .. ")")
ok(NS.ZoneProgress(MAP).shown >= 1, "Fußzeile zählt die eigene Zelle")

-- eigene Zähmung: im Dämmerwald studiert, dort alle Fundorte
NS.db.obs = NS.db.obs or {}
table.insert(NS.db.obs, ("%d;14;;;1792000010;"):format(NPC))
NS.ObservationsChanged()
ok(NS.BeastStatus(NPC, MAP) == "known", "studiert")
ok(#NS.Coords(NPC, MAP) == full, "studiert: alle Fundorte (" .. #NS.Coords(NPC, MAP) .. ")")
ok(NS.ZoneCounts(NPC)[MAP] == full, "ZoneCounts: volle Zahl")
local p = NS.ZoneProgress(MAP)
ok(p.shown >= full, "Fußzeile zählt alle Fundorte des studierten Tiers")
for _, pt in ipairs(NS.Coords(NPC, MAP)) do
  ok(pt.own == nil, "kein Kennzeichen für eigene Punkte")
  break
end

-- zweite Zone: dort nie gesehen – keine Punkte, keine Zone auf der Tierseite
ok(NS.BeastStatus(NPC, OTHER) ~= "known", "andere Zone: nicht studiert (" .. NS.BeastStatus(NPC, OTHER) .. ")")
ok(#NS.Coords(NPC, OTHER) == 0, "andere Zone: keine Punkte")
ok(NS.ZoneCounts(NPC)[OTHER] == nil, "andere Zone: nicht auf der Tierseite")

-- dritte Zone: dort nur von Weitem gesehen (Fährte), gezähmt anderswo – nicht studiert, keine Punkte; die Lehre
-- steht trotzdem da (#169). Erst eine eigene Zelle dort macht es zu „Tier studiert“.
local FAR = 1437
NS.db.locIn[NPC][FAR] = { a0000001 = "2C", a0000002 = "2C", a0000003 = "2C" }
NS.db.seenIn[NPC] = MAP .. "," .. FAR
NS.char.seenIn[NPC] = MAP .. "," .. FAR
ok(NS.BeastStatus(NPC, FAR) == "track", "nur gesehen, anderswo gezähmt: Fährte (" .. NS.BeastStatus(NPC, FAR) .. ")")
ok(#NS.Coords(NPC, FAR) == 0, "nur gesehen: keine Punkte")
ok(NS.TeachInfo(NPC, true) ~= nil, "Lehre trotzdem bekannt")
NS.char.loc[NPC][FAR] = "2C"
NS.db.loc[NPC][FAR] = "2C"
ok(NS.BeastStatus(NPC, FAR) == "known", "eigene Zelle dort: studiert")
ok(#NS.Coords(NPC, FAR) >= 1, "dann alle Fundorte dort")

-- Komplettmodus: alles, überall
NS.char.discover = false
ok(#NS.Coords(NPC, MAP) == full and #NS.Coords(NPC, OTHER) > 0, "Komplettmodus: alle Fundorte in beiden Zonen")
