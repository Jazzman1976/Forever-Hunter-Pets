-- #192: Im Entdeckermodus zählt „fehlt dir, erreichbar“ auch die noch nicht studierten Lehrtiere, wie im Komplettmodus.
-- ns.Teachers merkt sich dafür die niedrigste Stufe unter ihnen (undiscoveredMin), ohne sie in die Liste zu legen.
-- Riesiger Waldschreiter (2323) lehrt nach den Stammdaten Ducken 2 und lebt im Dämmerwald (1439).
local NPC, MAP, DUCK2 = 2323, 1439, 1753
local duck, rank
for _, a in ipairs(NS.Data.abilities) do
  for _, r in ipairs(a.ranks) do
    if r.id == DUCK2 then duck, rank = a, r end
  end
end
-- niedrigste Stufe unter den Lehrtieren einer Liste, ohne skip
local function lowest(list, skip)
  local min
  for _, t in ipairs(list) do
    if t.id ~= skip then
      local m = t.beast.min or 0
      if not min or m < min then min = m end
    end
  end
  return min
end

-- Komplettmodus: alle Lehrtiere stehen in der Liste, nichts ist unentdeckt
ForeverHunterPetsCharDB = { discover = false, modeChosen = true }
Login({ obs = {} })
ok(duck and rank, "Ducken 2 in den Daten")
ok(not NS.Discovering(), "Komplettmodus")
local all = NS.Teachers(duck, rank)
ok(#all >= 1, "Komplettmodus: Lehrtiere da (" .. #all .. ")")
ok(all.undiscovered == 0 and all.undiscoveredMin == nil, "Komplettmodus: nichts unentdeckt, keine Stufe")
local allMin = lowest(all)

-- Entdeckermodus, nichts studiert: keine Lehrtiere in der Liste, aber dieselbe niedrigste Stufe
NS.char.discover = true
ok(NS.Discovering(), "Entdeckermodus")
local open = NS.Teachers(duck, rank)
ok(#open == 0, "nichts studiert: keine Lehrtiere in der Liste")
ok(open.undiscovered == #all, "alle unentdeckt (" .. open.undiscovered .. ")")
ok(open.undiscoveredMin == allMin, "niedrigste Stufe wie im Komplettmodus (" .. tostring(open.undiscoveredMin) .. ")")

-- eigene Zähmung auf Stufe 14 (unter Pet-Stufe 15, widerlegt also nichts): das Tier steht in der Liste, die Stufe
-- zählt nur noch die übrigen
table.insert(NS.db.obs, ("%d;14;;;1792000010;"):format(NPC))
NS.db.loc = { [NPC] = { [MAP] = "AA" } }
NS.char.loc = { [NPC] = { [MAP] = "AA" } }
NS.ObservationsChanged()
ok(NS.Studied(NPC), "gezähmt: studiert")
local after = NS.Teachers(duck, rank)
ok(#after == 1 and after[1].id == NPC, "gezähmt: steht in der Liste")
ok(after.undiscovered == #all - 1, "einer weniger unentdeckt")
ok(after.undiscoveredMin == lowest(all, NPC), "Stufe nur noch aus den übrigen (" .. tostring(after.undiscoveredMin) .. ")")
