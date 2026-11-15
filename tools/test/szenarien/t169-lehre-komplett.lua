-- #169: Im Entdeckermodus zeigt ein studiertes Tier (selbst gezähmt) seine Lehre aus den kompletten Daten, nicht nur
-- aus der eigenen Zähmung; im Reiter „Fähigkeiten“ steht es bei jedem Rang, den es nach den Daten lehrt.
-- Riesiger Waldschreiter (2323) lehrt nach den Stammdaten Ducken 2 (Pet-Stufe 15) und lebt im Dämmerwald (1439).
local NPC, MAP, DUCK2 = 2323, 1439, 1753
local FOREIGN, TWINK = 990169, 990170
local duck, rank
for _, a in ipairs(NS.Data.abilities) do
  for _, r in ipairs(a.ranks) do
    if r.id == DUCK2 then duck, rank = a, r end
  end
end
local function has(list, r)
  for _, e in ipairs(list or {}) do if e.r == r then return e end end
  return nil
end
local function teaches(npc)
  for _, t in ipairs(NS.Teachers(duck, rank)) do if t.id == npc then return t end end
  return nil
end

ForeverHunterPetsCharDB = { discover = true, modeChosen = true, seenIn = { [NPC] = tostring(MAP) } }
local via = { a0000001 = "e0000001", a0000002 = "e0000002" }
-- was ein Charakter in seenIn hat, steht immer auch beim Konto (sonst räumt das Laden es weg)
Login({ via = via, myReps = { b0000001 = true }, seenIn = { [NPC] = tostring(MAP) }, ui = { showUncertain = false }, obs = {
  -- Ducken 2 bei einem Tier, das nicht in den Daten steht: nur 2 fremde Melder (unsicher)
  ("%d;20;%d;;1792000001;a0000001"):format(FOREIGN, DUCK2),
  ("%d;20;%d;;1792000002;a0000002"):format(FOREIGN, DUCK2),
  -- ein Twink (eigenes Kürzel, aber nicht dieser Charakter) hat Tier TWINK gezähmt
  ("%d;20;%d;;1792000003;b0000001"):format(TWINK, DUCK2),
} })
ok(duck and rank, "Ducken 2 in den Daten")
ok(NS.Discovering(), "Entdeckermodus")

-- nicht gezähmt: nichts verraten
ok(not NS.Studied(NPC), "nicht gezähmt: nicht studiert")
ok(NS.TeachInfo(NPC, true) == nil, "nicht gezähmt: Lehre unklar")
ok(not teaches(NPC), "nicht gezähmt: nicht unter den Lehrtieren")
local open = NS.Teachers(duck, rank).undiscovered
ok(open >= 1, "nicht gezähmt: zählt als unentdeckt (" .. open .. ")")
ok(NS.BeastStatus(NPC, MAP) == "track", "nur Fährte")

-- eigene Zähmung auf Stufe 14: Ducken 2 (ab Pet-Stufe 15) zeigt das Zauberbuch noch nicht, widerlegt ist er nicht
table.insert(NS.db.obs, ("%d;14;;;1792000010;"):format(NPC))   -- eigene Zähmung (ohne Kürzel)
-- die Zähmung speichert immer eine Zelle in ihrer Zone (Core/Observe.lua), beim Konto und beim Charakter
NS.db.loc = { [NPC] = { [MAP] = "AA" } }
NS.char.loc = { [NPC] = { [MAP] = "AA" } }
NS.ObservationsChanged()
ok(NS.Studied(NPC), "gezähmt: studiert")
ok(NS.BeastStatus(NPC, MAP) == "known", "gezähmt in der Zone: letzte Stufe")
local info = NS.TeachInfo(NPC, true)
ok(info and has(info, rank), "Lehre aus den Stammdaten: Ducken 2, obwohl die eigene Zähmung ihn nicht zeigte")
ok(has(info, rank).conf == NS.CONF_SURE, "belegt")
ok(teaches(NPC), "steht bei Ducken 2 unter den Lehrtieren")
ok(NS.Teachers(duck, rank).undiscovered == open - 1, "einer weniger unentdeckt")
local p = NS.ZoneProgress(MAP)
local found = false
for _, e in ipairs(p.rankList) do if e.r == rank and e.found then found = true end end
ok(found, "Rang-Kachel Ducken 2 im Dämmerwald aufgedeckt")

-- unsichere Angaben folgen der Einstellung, wie im Komplettmodus
table.insert(NS.db.obs, ("%d;10;;;1792000011;"):format(FOREIGN))   -- eigene Zähmung auf Stufe 10
NS.ObservationsChanged()
local _, unsure = NS.TeachInfo(FOREIGN, true)
ok(not has(NS.TeachInfo(FOREIGN, true), rank) and unsure, "2 Melder, Schalter aus: Rang nicht gezeigt, braucht Belege")
NS.db.ui.showUncertain = true
local e = has(NS.TeachInfo(FOREIGN, true), rank)
ok(e and e.conf == NS.CONF_UNSURE, "Schalter an: Rang als unsicher")
ok(NS.TeachText(FOREIGN):find("?", 1, true), "mit „?“ in der Zeile")

-- Zähmung eines anderen Charakters zählt nur mit „Funde anderer Charaktere“
ok(not NS.Studied(TWINK) and NS.TeachInfo(TWINK, true) == nil, "Twink-Zähmung: nicht studiert")
NS.char.shareFinds = true
ok(NS.Studied(TWINK) and has(NS.TeachInfo(TWINK, true), rank), "mit „Funde anderer Charaktere“: studiert, Lehre da")
