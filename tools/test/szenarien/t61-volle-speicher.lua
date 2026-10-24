-- #61: volle Speicher (Zähmungen, Sichtungen, Zellen) verdrängen die ältesten fremden Einträge
local function rep(i) return string.format("%08x", 0x10000000 + i) end
local obs, sights = {}, {}
obs[1] = "30;5;17253;;1792000000;"            -- eigene (ohne Kürzel, bekommt das eigene)
for i = 2, 5000 do obs[i] = "30;5;17253;;" .. (1792000000 + i) .. ";" .. rep(i) end
sights[1] = "30;5;0;3;deDE;Waldspinne;1792000000;"
for i = 2, 10000 do sights[i] = "30;" .. (i % 60 + 1) .. ";0;3;deDE;Waldspinne;" .. (1792000000 + i) .. ";" .. rep(i) end
-- 20000 fremde Zellen: 200 Melder × 100 Zellen auf Tier 30, Karte 1429
local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"
local function cells100(off)
  local t = {}
  for k = 0, 99 do local c = (k + off) % 2500; local x, y = c % 50, math.floor(c / 50); t[#t + 1] = ALPHA:sub(x + 1, x + 1) .. ALPHA:sub(y + 1, y + 1) end
  return table.concat(t)
end
local byRep = {}
for i = 1, 200 do byRep[rep(100000 + i)] = cells100(i * 100) end
ForeverHunterPetsDB = { obs = obs, sights = sights, locIn = { [30] = { [1429] = byRep } }, ui = { share = true } }
FireEvent("ADDON_LOADED", "Forever-Hunter-Pets")
FireEvent("PLAYER_LOGIN")
for _, m in ipairs(PRINTED) do if m:find("Error") or m:find("Fehler") then print(m) end end
-- Zähmungen
ok(NS.ObservationCount() == 5000, "5000 Zähmungen voll")
local d = NS.DropOldObservations(250)
ok(d == 250 and NS.ObservationCount() == 4750, "250 älteste fremde verdrängt")
ok(NS.db.obs[1]:sub(1, 20) == "30;5;17253;;17920000", "eigene bleibt vorn")
ok(NS.db.obs[2]:find(rep(252), 1, true), "die ältesten fremden sind weg, nächster ist Nr. 252")
-- Sichtungen
ok(NS.SightingCount() == 10000, "10000 Sichtungen voll")
local new = "30;7;0;3;deDE;Waldspinne;1792100000;" .. rep(99999)
ok(NS.AddSighting(new) == true, "neue fremde Sichtung trotz vollem Speicher angenommen")
ok(NS.SightingCount() == 9501, "500 verdrängt, eine neu")
ok(NS.db.sights[1]:find("Waldspinne;1792000000;", 1, true), "eigene Sichtung bleibt")
ok(NS.db.sights[9501] == new, "neue steht hinten")
ok(NS.SeenBeast(30) ~= nil, "Index neu gebaut")
-- Zellen
ok(NS.ForeignCellCount() == 20000, "20000 fremde Zellen voll")
local n = NS.AddCells(30, 1430, "mn", rep(777777))
ok(n == 1, "neue fremde Zelle trotz vollem Speicher angenommen")
ok(NS.ForeignCellCount() == 19001, "1000 Zellen (10 Melder) verdrängt, eine neu: " .. NS.ForeignCellCount())
local order = NS.db.locInOrder
ok(order[#order] == "30:1430:" .. rep(777777), "neuer Eintrag hinten in locInOrder")
ok(#order == 191, "Reihenfolge hat 190 alte + 1 neu: " .. #order)
local cnt = 0; for _ in pairs(NS.db.locIn[30][1429]) do cnt = cnt + 1 end
ok(cnt == 190 and NS.db.locIn[30][1430][rep(777777)] == "mn", "190 alte Melder plus neuer auf anderer Karte")
