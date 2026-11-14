-- #175: Hinweise, was als Nächstes zu tun ist – im Tooltip der Zeile (ns.StatusHint) und auf der Karte (ns.MapHint),
-- nur im Entdeckermodus. Die Namen der Jägerzauber kommen vom Client; bei der Fährte nennt die Karte den Namen, bei
-- „Noch nie gesehen“ nicht. Die Hinweisfläche der Karte (UI/MapCanvas.lua) prüft nur das Spiel.
local L = NS.L
local de = NS.Locales.deDE
local MAP = 1439
local FOUND, TRACK, NEVER = 2323, 990751, 990752

ForeverHunterPetsCharDB = { discover = true, modeChosen = true, loc = { [FOUND] = { [MAP] = "AA" } },
  seenIn = { [TRACK] = tostring(MAP) } }
Login({ loc = { [FOUND] = { [MAP] = "AA" } }, seenIn = { [TRACK] = tostring(MAP) },
  trackNames = { [TRACK] = "1;Grauwolf", [NEVER] = "1;Geheimer Wolf" } })
ok(NS.Discovering(), "Entdeckermodus")
ok(NS.BeastStatus(FOUND, MAP) == "found", "gefunden")
ok(NS.BeastStatus(TRACK, MAP) == "track", "Fährte")
ok(NS.BeastStatus(NEVER, MAP) == "unknown", "noch nie gesehen")

-- Tooltip der Zeile
local never = NS.StatusHint("unknown")
ok(never and never:find("Zauber 1494", 1, true) and never:find("Zauber 6197", 1, true)
  and never:find("Zauber 1002", 1, true), "noch nie gesehen: drei Jägerzauber vom Client: " .. tostring(never))
ok(never:find("Fährte", 1, true) ~= nil, "deutsch: " .. never)
ok(NS.StatusHint("track") == L["You need to get closer to find it. Then you can tell whether it might teach you something."],
  "Fährte: näher ran")
ok(NS.StatusHint("found") == L["Tame it to find out its abilities."], "gefunden: zähmen")
ok(NS.StatusHint("known") == nil, "studiert: kein Hinweis")

-- Karte
local m = NS.MapHint("track", TRACK)
ok(m and m:find("Grauwolf", 1, true), "Fährte: Karte nennt den Namen: " .. tostring(m))
m = NS.MapHint("unknown", NEVER)
ok(m and not m:find("Geheimer", 1, true) and not m:find("%d"), "noch nie gesehen: kein Name, keine ID: " .. tostring(m))
ok(NS.MapHint("found", FOUND) == nil and NS.MapHint("known", FOUND) == nil, "ab gefunden: keine Karte-Hinweis")

-- Client liefert keinen Namen: übersetzter Rückfall
local get = C_Spell.GetSpellName
C_Spell.GetSpellName = function() return nil end
never = NS.StatusHint("unknown")
ok(never:find("Wildtiere aufspüren", 1, true) and never:find("Adlerauge", 1, true)
  and never:find("Augen des Wildtiers", 1, true), "Rückfall auf deutsche Namen: " .. never)
C_Spell.GetSpellName = get

-- Komplettmodus: nie
NS.char.discover = false
ok(NS.StatusHint("unknown") == nil and NS.StatusHint("track") == nil and NS.StatusHint("found") == nil,
  "Komplettmodus: kein Hinweis in der Zeile")
ok(NS.MapHint("unknown", NEVER) == nil and NS.MapHint("track", TRACK) == nil, "Komplettmodus: kein Hinweis auf der Karte")
NS.char.discover = true

-- deutsch, Anführungszeichen wie im Deutschen
ok(de["Tame it to find out its abilities."] == "Durch Zähmen findest du seine Fähigkeiten heraus.", "deutsch: zähmen")
ok(never:find("„", 1, true) ~= nil, "deutsche Anführungszeichen")
