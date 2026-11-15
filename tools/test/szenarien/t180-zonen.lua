-- #180: „Wo lohnt sich die Jagd?“ Im Entdeckermodus zählt ns.ZoneTallies je Zone die gefundenen Tiere (gefunden und
-- studiert, wie der Zähler „Tiere“, #176) und alle Tiere, dazu die Summe. Die Fährte zählt nicht. Ein Tier in zwei
-- Zonen zählt in beiden, in der Summe einmal. Die Zonenauswahl im Reiter „Gebiet“ trägt den Stand je Zone und oben
-- eine Gesamtzeile ohne Wahl, bleibt alphabetisch und zeigt im Komplettmodus keinen Stand.
-- lädt: UI/Widgets.lua UI/Area.lua
local de = NS.Locales.deDE
local D = NS.Data

-- ein Tier, das nach den Stammdaten in zwei Zonen lebt (kleinste NPC-ID, damit der Test immer dasselbe nimmt)
local NPC, M1, M2
for npc, zones in pairs(D.coords) do
  local maps = {}
  for m in pairs(zones) do maps[#maps + 1] = m end
  if #maps >= 2 and (not NPC or npc < NPC) then
    table.sort(maps)
    NPC, M1, M2 = npc, maps[1], maps[2]
  end
end
ok(NPC ~= nil, "Tier in zwei Zonen in den Stammdaten (" .. tostring(NPC) .. ": " .. tostring(M1) .. ", " .. tostring(M2) .. ")")

ForeverHunterPetsCharDB = { discover = true, modeChosen = true, loc = {}, seenIn = {} }
Login({ loc = {}, seenIn = {} })
ok(NS.Discovering(), "Entdeckermodus")

-- Summe über alle Tiere unabhängig nachzählen
local zones = NS.DiscoverZones()
local union, sumZones = {}, 0
for _, map in ipairs(zones) do
  for npc in pairs(NS.BeastsIn(map)) do
    union[npc] = true
    sumZones = sumZones + 1
  end
end
local nUnion = 0
for _ in pairs(union) do nUnion = nUnion + 1 end

local t, total = NS.ZoneTallies(zones)
ok(total.beasts == nUnion, "Summe: jedes Tier einmal (" .. total.beasts .. " von " .. sumZones .. " Einträgen je Zone)")
ok(total.beasts < sumZones, "Tiere in mehreren Zonen zählen in der Summe nur einmal")
ok(total.found == 0, "nichts gefunden: Summe 0")
ok(t[M1].found == 0 and t[M1].beasts > 0, "Zone 1: 0 von " .. t[M1].beasts)
-- ohne Liste nimmt ns.ZoneTallies ns.DiscoverZones
local t2, total2 = NS.ZoneTallies()
ok(total2.beasts == total.beasts and t2[M2].beasts == t[M2].beasts, "ohne Liste: alle Zonen")

-- je Zone dieselben Zahlen wie der Zähler „Tiere“ (ns.ZoneProgress)
local p = NS.ZoneProgress(M1)
ok(p.beasts == t[M1].beasts and p.beastsKnown == t[M1].found, "Zone 1 wie der Zähler „Tiere“")

-- Fährte in Zone 1: zählt nicht
NS.db.seenIn[NPC] = tostring(M1)
NS.char.seenIn[NPC] = tostring(M1)
ok(NS.BeastStatus(NPC, M1) == "track", "Fährte in Zone 1")
t, total = NS.ZoneTallies(zones)
ok(t[M1].found == 0 and total.found == 0, "Fährte zählt nicht")

-- Fund in Zone 1: zählt dort und in der Summe, nicht in Zone 2
NS.db.loc[NPC] = { [M1] = "AA" }
NS.char.loc[NPC] = { [M1] = "AA" }
ok(NS.BeastStatus(NPC, M1) == "found", "gefunden in Zone 1")
t, total = NS.ZoneTallies(zones)
ok(t[M1].found == 1, "Fund zählt in Zone 1")
ok(t[M2].found == 0, "in Zone 2 noch nicht gefunden")
ok(total.found == 1, "Summe 1")
p = NS.ZoneProgress(M1)
ok(p.beastsKnown == t[M1].found, "weiter wie der Zähler „Tiere“")

-- Fund auch in Zone 2: zählt in beiden Zonen, in der Summe weiter einmal
NS.db.seenIn[NPC] = M1 .. "," .. M2
NS.char.seenIn[NPC] = M1 .. "," .. M2
NS.db.loc[NPC][M2] = "BB"
NS.char.loc[NPC][M2] = "BB"
t, total = NS.ZoneTallies(zones)
ok(t[M1].found == 1 and t[M2].found == 1, "in beiden Zonen gefunden")
ok(total.found == 1, "in der Summe einmal")

-- studiert zählt wie gefunden, nicht doppelt
NS.db.obs = NS.db.obs or {}
table.insert(NS.db.obs, ("%d;20;;;1792000100;"):format(NPC))
NS.ObservationsChanged()
ok(NS.BeastStatus(NPC, M1) == "known", "studiert")
t, total = NS.ZoneTallies(zones)
ok(t[M1].found == 1 and total.found == 1, "studiert zählt einmal")

-- Sortierung bleibt alphabetisch
for i = 2, #zones do
  ok(NS.ZoneName(zones[i - 1]) <= NS.ZoneName(zones[i]), "alphabetisch: " .. NS.ZoneName(zones[i - 1]) .. " vor " .. NS.ZoneName(zones[i]))
end

-- ---- Zonenauswahl im Reiter „Gebiet“ ----
local options
local plainDropdown = NS.W.Dropdown
NS.W.Dropdown = function(...)
  local dd = plainDropdown(...)
  local set = dd.SetOptions
  function dd:SetOptions(list)
    options = list
    return set(self, list)
  end
  return dd
end
NS.CONTENT_W, NS.CONTENT_H = 876, 576
NS.CreateMapCanvas = function() return CreateFrame() end   -- die Karte selbst braucht der Test nicht
local pane = CreateFrame()
local window = CreateFrame()
pane.GetParent = function() return window end   -- die nachgebildete API kennt keine Eltern
local area = NS.BuildArea(pane)
area:Render()
ok(options ~= nil, "Zonenauswahl gefüllt")
ok(options[1].header == ("Alle Gebiete: %d von %d Tieren gefunden"):format(total.found, total.beasts),
  "Gesamtzeile ganz oben: " .. tostring(options[1].header))
ok(options[1].value == nil, "Gesamtzeile ohne Wahl")
ok(options[2].value == "current", "danach „Aktuelles Gebiet“")
local function optionOf(map)
  for _, o in ipairs(options) do if o.value == map then return o end end
end
local o1 = optionOf(M1)
ok(o1 and o1.label:find(NS.ZoneName(M1) .. " 1/" .. t[M1].beasts, 1, true), "Stand je Zone: " .. tostring(o1 and o1.label))
-- Reihenfolge der Zonen wie ns.DiscoverZones
for i, map in ipairs(zones) do
  ok(options[i + 2].value == map, "Zone " .. i .. " an ihrem Platz")
end
-- Haken nur bei einer Zone, in der alles gefunden ist
local done, open = 0, 0
for _, o in ipairs(options) do
  if type(o.value) == "number" then
    local tt = t[o.value]
    local hasTick = o.label:find("ReadyCheck-Ready", 1, true) ~= nil
    ok(hasTick == (tt.found >= tt.beasts), "Haken nur bei fertiger Zone: " .. NS.ZoneName(o.value))
    if hasTick then done = done + 1 else open = open + 1 end
  end
end
ok(open > 0, "offene Zonen ohne Haken (" .. open .. ")")

-- eine Zone ganz gefunden: Haken
local single
for _, map in ipairs(zones) do
  local n = 0
  for _ in pairs(NS.BeastsIn(map)) do n = n + 1 end
  if n == 1 then single = map break end
end
if single then
  local only = next(NS.BeastsIn(single))
  NS.char.seenIn[only] = ((NS.char.seenIn[only] and NS.char.seenIn[only] .. ",") or "") .. single
  NS.char.loc[only] = NS.char.loc[only] or {}
  NS.char.loc[only][single] = "CC"
  area:Render()
  local os = optionOf(single)
  ok(os.label:find("ReadyCheck-Ready", 1, true) and os.label:find(" 1/1", 1, true), "fertige Zone mit Haken: " .. os.label)
else
  ok(true, "keine Zone mit nur einem Tier, Haken oben mitgeprüft")
end

-- Komplettmodus: kein Stand, keine Gesamtzeile
NS.char.discover = false
area:Render()
ok(options[1].value == "current", "Komplettmodus: keine Gesamtzeile")
o1 = optionOf(M1)
ok(o1.label == NS.ZoneName(M1), "Komplettmodus: Zone ohne Stand (" .. o1.label .. ")")
NS.char.discover = true

-- Text
ok(de["All zones: %d of %d beasts found"] == "Alle Gebiete: %d von %d Tieren gefunden", "deutsch: Gesamtzeile")
