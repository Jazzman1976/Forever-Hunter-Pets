-- #103 A4 (Plan aus #54): fremde Zellen und Tiere im Spiel erst ab 3 Meldern je Tier und Karte, über zwei Absender;
-- eigene Zellen sofort. Gespeichert wird alles.
local MAP = 99001
local function reps(n, prefix, oneSender)
  local byRep, via = {}, {}
  for k = 1, n do
    local rep = ("%s%06d"):format(prefix, k)
    byRep[rep] = ("%s%s"):format(string.char(48 + k), "A")   -- je Melder eine andere Zelle
    via[rep] = oneSender and "eeeeeee1" or ("e%07d"):format(k)
  end
  return byRep, via
end
local locIn, via = {}, {}
for n = 1, 3 do
  local byRep, v = reps(n, "a" .. n, false)
  locIn[990200 + n] = { [MAP] = byRep }
  for k, x in pairs(v) do via[k] = x end
end
local byRep9, v9 = reps(3, "b9", true)
locIn[990209] = { [MAP] = byRep9 }
for k, x in pairs(v9) do via[k] = x end
-- ein Tier mit 2 fremden Meldern und einer eigenen Zelle
local byRep8, v8 = reps(2, "c8", false)
locIn[990208] = { [MAP] = byRep8 }
for k, x in pairs(v8) do via[k] = x end

Login({ locIn = locIn, via = via, loc = { [990208] = { [MAP] = "9A" } } })

local inZone = NS.BeastsIn(MAP)
ok(not inZone[990201], "1 Melder: Tier nicht in der Zone")
ok(not inZone[990202], "2 Melder: Tier nicht in der Zone")
ok(inZone[990203], "3 Melder: Tier in der Zone")
ok(not inZone[990209], "3 Melder über einen Absender: Tier nicht in der Zone")
ok(inZone[990208], "eigene Zelle: Tier sofort in der Zone")

ok(#NS.CellPoints(990202, MAP) == 0, "2 Melder: keine fremden Punkte")
ok(#NS.CellPoints(990203, MAP) == 3, "3 Melder: alle drei Zellen als Punkte")
ok(#NS.CellPoints(990208, MAP) == 1, "eigene Zelle zählt, die zwei fremden nicht")
ok(NS.CellMaps(990202)[MAP] == nil, "2 Melder: Karte nicht unter den Zonen des Tiers")
ok(NS.CellMaps(990203)[MAP] == 3, "3 Melder: Karte mit 3 Zellen")
ok(NS.ForeignCellsOk(990203, MAP) and not NS.ForeignCellsOk(990202, MAP), "ns.ForeignCellsOk wie oben")

local zones = {}
for _, m in ipairs(NS.DiscoverZones()) do zones[m] = true end
ok(zones[MAP], "Zone erscheint (Tiere ab der Schwelle und eigene)")

-- nur noch Tiere unter der Schwelle: die Zone fehlt
Login({ locIn = { [990202] = { [MAP + 1] = byRep8 } }, via = via })
zones = {}
for _, m in ipairs(NS.DiscoverZones()) do zones[m] = true end
ok(not zones[MAP + 1], "Zone nur mit 2 fremden Meldern erscheint nicht")
ok(NS.db.locIn[990202][MAP + 1] ~= nil, "gespeichert bleibt sie trotzdem")
