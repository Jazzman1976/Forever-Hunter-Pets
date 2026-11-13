-- #193: Im Reiter „Fähigkeiten“ bestimmen in beiden Modi die kompletten Daten, wer in einer Zone lebt (ns.BeastZonesAll).
-- Was man vom Tier sieht, regelt weiter ns.BeastZones: im Entdeckermodus nur eigene Zellen und Zähmungen.
-- Riesiger Waldschreiter (2323) lehrt nach den Stammdaten Ducken 2 und lebt im Dämmerwald (1439).
local NPC, MAP, DUCK2 = 2323, 1439, 1753
local ZONE = { [MAP] = true }
local duck, rank
for _, a in ipairs(NS.Data.abilities) do
  for _, r in ipairs(a.ranks) do
    if r.id == DUCK2 then duck, rank = a, r end
  end
end
local function has(list, value)
  for _, x in ipairs(list) do if x == value then return true end end
  return false
end
local function listed(list, npc)
  for _, t in ipairs(list) do if t.id == npc then return true end end
  return false
end

-- Komplettmodus: das Tier steht im Dämmerwald unter den Lehrtieren
ForeverHunterPetsCharDB = { discover = false, modeChosen = true }
Login({ obs = {} })
ok(duck and rank, "Ducken 2 in den Daten")
ok(has(NS.BeastZones(NPC), MAP), "Komplettmodus: Dämmerwald in den Zonen")
ok(has(NS.BeastZonesAll(NPC), MAP), "Komplettmodus: Dämmerwald in den kompletten Zonen")
local all = NS.Teachers(duck, rank, ZONE)
ok(listed(all, NPC), "Komplettmodus: Lehrtier im Dämmerwald")

-- Entdeckermodus ohne eigene Zelle: gezeigt wird keine Zone, gezählt wird es trotzdem
NS.char.discover = true
ok(NS.Discovering(), "Entdeckermodus")
ok(not has(NS.BeastZones(NPC), MAP), "Entdeckermodus: ohne eigene Zelle keine Zone gezeigt")
ok(has(NS.BeastZonesAll(NPC), MAP), "Entdeckermodus: komplette Zonen unverändert")
local open = NS.Teachers(duck, rank, ZONE)
ok(not listed(open, NPC), "Entdeckermodus: nicht studiert, nicht in der Liste")
ok(open.undiscovered == #all, "im Dämmerwald gleich viele wie im Komplettmodus, als unentdeckt (" .. open.undiscovered .. ")")
ok(open.undiscoveredMin ~= nil, "mit Stufe für „erreichbar“ (#192)")

-- eine andere Zone, in der kein Lehrtier von Ducken 2 lebt, zählt nichts
local other = NS.Teachers(duck, rank, { [999999] = true })
ok(#other == 0 and other.undiscovered == 0, "fremde Zone: nichts")
