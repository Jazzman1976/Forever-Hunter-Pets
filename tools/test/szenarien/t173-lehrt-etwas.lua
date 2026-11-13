-- #173: Entdeckermodus – bei „Tier gefunden“ steht schon, *ob* ein Tier etwas lehrt („lehrt etwas“, „lehrt nichts“,
-- sonst „Keine Daten“), bei der Fährte nichts; ein studiertes Tier zeigt seine Lehre in jedem Status.
-- Riesiger Waldschreiter (2323) lehrt nach den Stammdaten Ducken 2 (1753) und lebt im Dämmerwald (1439).
local L = NS.L
local MAP, OTHER, DUCK2 = 1439, 1440, 1753
local TEACHES, NOTHING, TWO, TWO_RANK, NODATA, TRACK = 2323, 990731, 990732, 990733, 990734, 990735

local obs, via, i = {}, {}, 0
local function foreign(npc, rep, spell)
  i = i + 1
  obs[#obs + 1] = ("%d;30;%s;;%d;%s"):format(npc, spell or "", 1792000000 + i, rep)
  via[rep] = "e" .. rep:sub(2)
end
foreign(NOTHING, "a0000001"); foreign(NOTHING, "a0000002"); foreign(NOTHING, "a0000003")
foreign(TWO, "a0000001"); foreign(TWO, "a0000002")
foreign(TWO_RANK, "a0000001", DUCK2); foreign(TWO_RANK, "a0000002", DUCK2)

-- eigene Zellen im Dämmerwald: „Tier gefunden“; TRACK nur gesehen: „Fährte aufgenommen“
local loc, seen = {}, {}
for _, npc in ipairs({ TEACHES, NOTHING, TWO, TWO_RANK, NODATA }) do loc[npc] = { [MAP] = "AA" } end
seen[TRACK] = tostring(MAP)
local function copy(t)
  local c = {}
  for k, v in pairs(t) do c[k] = type(v) == "table" and copy(v) or v end
  return c
end
ForeverHunterPetsCharDB = { discover = true, modeChosen = true, loc = copy(loc), seenIn = copy(seen) }
Login({ obs = obs, via = via, loc = copy(loc), seenIn = copy(seen), ui = { showUncertain = false } })
ok(NS.Discovering(), "Entdeckermodus")
for _, npc in ipairs({ TEACHES, NOTHING, TWO, TWO_RANK, NODATA }) do
  ok(NS.BeastStatus(npc, MAP) == "found", npc .. ": Tier gefunden (" .. NS.BeastStatus(npc, MAP) .. ")")
end
ok(NS.BeastStatus(TRACK, MAP) == "track", "Fährte")

local function text(npc) return NS.TeachText(npc, NS.BeastStatus(npc, MAP)) end
local SHORT = NS.NoData()
ok(text(TEACHES) == L["teaches something"], "gefunden, Daten nennen einen Rang: " .. tostring(text(TEACHES)))
ok(select(2, NS.TeachSummary(TEACHES)) == "something", "Art: something")
ok(text(NOTHING) == L["teaches nothing"], "gefunden, 3 fremde Zähmungen ohne Rang: " .. tostring(text(NOTHING)))
ok(select(2, NS.TeachSummary(NOTHING)) == "nothing", "Art: nothing")
ok(text(TWO) == SHORT, "gefunden, 2 fremde Melder ohne Rang, Schalter aus: Keine Daten")
ok(text(TWO_RANK) == SHORT, "gefunden, 2 fremde Melder mit Rang, Schalter aus: Keine Daten")
ok(text(NODATA) == SHORT, "gefunden, nichts bekannt: Keine Daten")
ok(select(2, NS.TeachSummary(NODATA)) == "none", "Art: none")
ok(text(TRACK) == nil, "Fährte: kein Text")
ok(NS.TeachText(TEACHES, "unknown") == nil, "noch nie gesehen: kein Text")

NS.db.ui.showUncertain = true
ok(text(TWO) == L["teaches nothing"] .. "?", "2 Melder ohne Rang, Schalter an: " .. tostring(text(TWO)))
ok(text(TWO_RANK) == L["teaches something"] .. "?", "2 Melder mit Rang, Schalter an: " .. tostring(text(TWO_RANK)))
ok(text(TEACHES) == L["teaches something"], "belegter Rang: ohne „?“")
NS.db.ui.showUncertain = false

-- Fährte hier, aber anderswo selbst gezähmt (eigene Zelle nur dort): Lehre mit Icons
table.insert(NS.db.obs, ("%d;20;%d;;1792000100;"):format(TEACHES, DUCK2))   -- eigene Zähmung (ohne Kürzel), zeigt Ducken 2
NS.db.loc[TEACHES] = { [OTHER] = "AA" }
NS.char.loc[TEACHES] = { [OTHER] = "AA" }
NS.db.seenIn[TEACHES] = tostring(MAP)
NS.char.seenIn[TEACHES] = tostring(MAP)
NS.ObservationsChanged()
ok(NS.Studied(TEACHES), "anderswo gezähmt: studiert")
ok(NS.BeastStatus(TEACHES, MAP) == "track", "hier nur Fährte: " .. NS.BeastStatus(TEACHES, MAP))
local t = text(TEACHES)
ok(t and t:find("|T", 1, true) and t:find((L["teaches %s"]):gsub("%%s.*", ""), 1, true), "Fährte, studiert: lehrt mit Icons: " .. tostring(t))

-- Komplettmodus unverändert
NS.char.discover = false
ok(NS.TeachText(TEACHES):find("|T", 1, true) ~= nil, "Komplettmodus: lehrt mit Icons")
ok(NS.TeachText(NODATA) == SHORT, "Komplettmodus: Keine Daten")
ok(NS.TeachText(NOTHING) == L["teaches nothing"], "Komplettmodus: lehrt nichts")

ok(NS.Locales.deDE["teaches something"] == "lehrt etwas", "deutsch: lehrt etwas")
