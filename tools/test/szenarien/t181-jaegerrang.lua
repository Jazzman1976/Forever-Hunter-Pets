-- #181: Jägerrang in der Titelzeile, nur im Entdeckermodus. Grundlage sind die gefundenen Tiere über alle Zonen,
-- dieselbe Summe wie die Gesamtzeile im Reiter „Gebiet“ (ns.ZoneTallies, #180). Feste Schwellen 0/20/60/120:
-- Fährtenleser, Pirschjäger, Wildhüter, Meister der Wildnis. Der Tooltip nennt die Zahl und den nächsten Rang.
-- lädt: UI/Widgets.lua UI/Main.lua
local L = NS.L
local de = NS.Locales.deDE

-- ---- Rang je Schwelle, genau an der Grenze ----
local function rankAt(n)
  local r, nx = NS.HunterRank(n)
  return L[r.name], nx and L[nx.name], nx and nx.at
end
local cases = {
  { 0, "Fährtenleser", "Pirschjäger", 20 },
  { 19, "Fährtenleser", "Pirschjäger", 20 },
  { 20, "Pirschjäger", "Wildhüter", 60 },
  { 59, "Pirschjäger", "Wildhüter", 60 },
  { 60, "Wildhüter", "Meister der Wildnis", 120 },
  { 119, "Wildhüter", "Meister der Wildnis", 120 },
  { 120, "Meister der Wildnis", nil, nil },
  { 500, "Meister der Wildnis", nil, nil },
}
for _, c in ipairs(cases) do
  local name, nextName, nextAt = rankAt(c[1])
  ok(name == c[2] and nextName == c[3] and nextAt == c[4],
    ("%d Tiere: %s, nächster %s ab %s"):format(c[1], tostring(name), tostring(nextName), tostring(nextAt)))
end
-- wie viele Tiere bis zum nächsten Rang fehlen
local _, nx = NS.HunterRank(37)
ok(nx.at - 37 == 23, "bei 37 fehlen 23 bis Wildhüter")
ok(NS.HunterRank(nil).name == "Tracker", "ohne Zahl: Fährtenleser")

-- ---- Anzeige in der Titelzeile ----
-- Tooltip zum Mitlesen
local tip = {}
GameTooltip = setmetatable({
  SetOwner = function() tip = {} end,
  SetText = function(_, t) tip[#tip + 1] = t end,
  AddLine = function(_, t) tip[#tip + 1] = t end,
}, { __index = function() return function() end end })
-- die Reiter selbst braucht der Test nicht
local renders = 0
NS.BuildAbilities = function() return { Render = function() end } end
NS.BuildTraining = function() return { Render = function() end } end
NS.BuildArea = function() return { Render = function() renders = renders + 1 end } end

ForeverHunterPetsCharDB = { discover = true, modeChosen = true, loc = {}, seenIn = {} }
Login({ loc = {}, seenIn = {} })
NS.db.ui.view = "abilities"
NS.Toggle()
local f = NS.frame
ok(f ~= nil, "Fenster gebaut")
f.scripts.OnShow()   -- im Spiel ruft Show() das Skript
ok(f.rank.text == "Fährtenleser", "Entdeckermodus, nichts gefunden: Fährtenleser (" .. tostring(f.rank.text) .. ")")
f.rankHover.scripts.OnEnter(f.rankHover)
ok(tip[1] == "Jägerrang: Fährtenleser", "Tooltip: Titel")
ok(tip[2] == "Du hast 0 Tiere gefunden.", "Tooltip: Zahl (" .. tostring(tip[2]) .. ")")
ok(tip[3] == "Nächster Rang: Pirschjäger ab 20 gefundenen Tieren.", "Tooltip: nächster Rang")

-- ein Fund: dieselbe Summe wie die Gesamtzeile
local _, total = NS.ZoneTallies()
local npc, map
for _, m in ipairs(NS.DiscoverZones()) do
  npc = next(NS.BeastsIn(m))
  if npc then map = m break end
end
NS.char.seenIn[npc] = tostring(map)
NS.char.loc[npc] = { [map] = "AA" }
NS.ShowHunterRank()
f.rankHover.scripts.OnEnter(f.rankHover)
_, total = NS.ZoneTallies()
ok(total.found == 1, "Summe der Gesamtzeile: 1")
ok(tip[2] == "Du hast 1 Tier gefunden.", "Tooltip nach dem Fund, Einzahl (" .. tostring(tip[2]) .. ")")

-- die Summe aus dem Reiter „Gebiet“ wird übernommen, ohne neu zu zählen
NS.ShowHunterRank({ found = 120, beasts = 190 })
ok(f.rank.text == "Meister der Wildnis", "Summe aus dem Reiter: Meister der Wildnis")
f.rankHover.scripts.OnEnter(f.rankHover)
ok(tip[2] == "Du hast 120 Tiere gefunden." and tip[3] == "Höchster Rang erreicht.", "höchster Rang im Tooltip")
NS.ShowHunterRank({ found = 20, beasts = 190 })
ok(f.rank.text == "Pirschjäger", "genau 20: Pirschjäger")

-- Komplettmodus bei offenem Fenster: kein Rang, kein Tooltip
NS.char.discover = false
NS.ModeChanged()
ok(f.rank.text == "", "Komplettmodus: kein Rang")
tip = {}
f.rankHover.scripts.OnEnter(f.rankHover)
ok(#tip == 0, "Komplettmodus: kein Tooltip")
-- auch nicht, wenn der Reiter „Gebiet“ seine (leere) Summe hereinreicht
NS.ShowHunterRank(nil)
ok(f.rank.text == "", "Komplettmodus: auch über den Reiter kein Rang")

-- zurück in den Entdeckermodus: Rang wieder da
NS.char.discover = true
NS.ModeChanged()
ok(f.rank.text == "Fährtenleser", "zurück im Entdeckermodus: Rang aus den eigenen Funden (" .. tostring(f.rank.text) .. ")")

-- ist der Reiter „Gebiet“ offen, zählt beim Öffnen nur er
NS.db.ui.view = "area"
f.ShowView("area")
local before = renders
f.rank:SetText("x")
f.scripts.OnShow()
ok(renders == before + 1 and f.rank.text == "x", "Reiter „Gebiet“ offen: OnShow zählt nicht selbst")

-- Texte
ok(de["Master of the Wild"] == "Meister der Wildnis" and de["Warden"] == "Wildhüter" and de["Stalker"] == "Pirschjäger"
  and de["Tracker"] == "Fährtenleser", "deutsch: Ränge")
