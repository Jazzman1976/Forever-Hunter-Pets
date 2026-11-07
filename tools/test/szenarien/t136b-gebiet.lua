-- #136: Tiere in einer Zone nur durch fremde Zellen – ab 2 Meldern unsicher (mit dem Schalter, „?“), ab 3 belegt
local MAP = 99101
local via = { a0000001 = "e0000001", a0000002 = "e0000002", a0000003 = "e0000003" }
local locIn = {
  [990701] = { [MAP] = { a0000001 = "0A" } },
  [990702] = { [MAP] = { a0000001 = "0A", a0000002 = "1A" } },
  [990703] = { [MAP] = { a0000001 = "0A", a0000002 = "1A", a0000003 = "2A" } },
  [990704] = { [MAP + 1] = { a0000001 = "0A", a0000002 = "1A" } },
}
Login({ locIn = locIn, via = via, ui = { showUncertain = false } })
local inZone = NS.BeastsIn(MAP)
ok(not inZone[990702] and inZone[990703], "Schalter aus: 2 Melder nicht in der Zone, 3 schon")
local zones = {}
for _, m in ipairs(NS.DiscoverZones()) do zones[m] = true end
ok(not zones[MAP + 1], "Schalter aus: Zone nur mit 2 Meldern fehlt")
local before = NS.ZoneProgress(MAP).beasts

NS.db.ui.showUncertain = true
inZone = NS.BeastsIn(MAP)
ok(inZone[990702] == NS.CONF_UNSURE, "Schalter an: 2 Melder als unsicher in der Zone")
ok(inZone[990703] == NS.CONF_SURE, "3 Melder belegt")
ok(not inZone[990701], "1 Melder nie")
ok(#NS.CellPoints(990702, MAP) == 2, "zwei Punkte auf der Karte")
ok(NS.ZoneProgress(MAP).beasts == before + 1, "zählt in „X von Y“ mit (E3)")
zones = {}
for _, m in ipairs(NS.DiscoverZones()) do zones[m] = true end
ok(zones[MAP + 1], "Schalter an: Zone mit 2 Meldern erscheint")

-- selbst in der Zone gesehen: nicht mehr unsicher
NS.db.seenIn = { [990702] = tostring(MAP) }
ok(NS.BeastsIn(MAP)[990702] == true, "eigene Fährte in der Zone hebt das „?“ auf")
