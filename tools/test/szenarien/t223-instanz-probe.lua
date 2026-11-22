-- #223: /fhp api instanz misst in einer Instanz, was lesbar, geheim oder gar nicht da ist, ohne an geheimen Werten
-- zu scheitern. Jeder Lauf hängt an ForeverHunterPetsDB.probeInst (höchstens 30, „neu“ leert, beim Laden nach
-- 14 Tagen weg), im Chat steht nur die Zusammenfassung, und kein Spielername landet im Protokoll.

local slash = SlashCmdList.FOREVERHUNTERPETS
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

-- ---- Eine Instanz mit geheimen Werten ----
-- geheim: Name und Familie des Ziels, die Position, der Besitz eines Tiers an Namensplakette 2
SECRETS = { GEHEIM_NAME = true, GEHEIM_FAM = true, GEHEIM_POS = true, GEHEIM_BESITZ = true }
function IsInInstance() return true, "party" end
function GetInstanceInfo() return "Burg Probe", "party", 1, "Normal", 5, 0, false, 33 end
function GetRealZoneText() return "Burg Probe" end
function GetZoneText() error("Testfehler") end   -- ein Fehler gilt als „fehlt“
function GetSubZoneText() return "Hof" end
C_Map = {
  GetBestMapForUnit = function() return 310 end,
  GetMapInfo = function(id) return { mapID = id, name = "Burg Probe", mapType = 4, parentMapID = 1 } end,
  GetPlayerMapPosition = function() return "GEHEIM_POS" end,
  -- GetMapGroupID gibt es in diesem Client nicht
}
local units = {
  target = { name = "GEHEIM_NAME", fam = "GEHEIM_FAM", guid = "Creature-0-1-2-3-1234-0001", player = false, controlled = false },
  -- Tier eines Spielers: wird übersprungen, sein Tooltip nennt den Besitzer
  nameplate1 = { name = "Pfote", fam = "Wolf", guid = "Pet-0-1-2-3-99-0002", player = false, controlled = true,
    owner = "Begleiter von Fremder Spieler" },
  -- Besitz geheim: gemessen, aber ohne Namen und Tooltip-Texte
  nameplate2 = { name = "Wolfsname", fam = "Wolf", guid = "Creature-0-1-2-3-555-0003", player = false, controlled = "GEHEIM_BESITZ",
    owner = "Begleiter von Fremder Zweiter" },
  -- keine Familie: keine Messung
  nameplate3 = { name = "Ritter", guid = "Creature-0-1-2-3-777-0004", player = false, controlled = false },
}
function UnitExists(u) return units[u] ~= nil end
function UnitName(u) return units[u] and units[u].name end
function UnitGUID(u) return units[u] and units[u].guid end
function UnitCreatureFamily(u) return units[u] and units[u].fam end
function UnitIsPlayer(u) return units[u] and units[u].player end
function UnitPlayerControlled(u) return units[u] and units[u].controlled end
function UnitLevel() return 20 end
C_TooltipInfo = { GetUnit = function(u)
  local x = units[u]
  return { lines = { { type = 2, leftText = x.name }, x.owner and { type = 16, leftText = x.owner } or nil } }
end }
function IsInGroup(cat) return cat == 2 end   -- nur eine Instanzgruppe
function IsInRaid() return false end
SENT = {}
C_ChatInfo.SendAddonMessage = function(prefix, msg, kind, target)
  SENT[#SENT + 1] = { prefix = prefix, msg = msg, kind = kind, target = target }
  -- Flüstern an sich selbst kommt an, die Instanzgruppe nicht
  if kind == "WHISPER" then FireEvent("CHAT_MSG_ADDON", prefix, msg, kind, "Test Realm") end
  return 0
end

Login({ ui = { share = true } })
PRINTED = {}
ERRORS = {}
slash("api instanz")
ok(#ERRORS == 0, "Probe läuft in der Instanz ohne Fehler" .. (ERRORS[1] and (": " .. ERRORS[1]) or ""))
local runs = NS.db.probeInst
ok(type(runs) == "table" and #runs == 1, "ein Lauf in probeInst")
local run = runs[1]
ok(run.at == NOW and run.version == NS.version, "Lauf mit Zeitpunkt und Version")
ok(run.where == "Burg Probe (party)", "Kopfzeile mit dem Ort: " .. tostring(run.where))
local all = table.concat(run.lines, "\n")
ok(all:find("UnitName = geheim", 1, true), "geheimer Name als „geheim“")
ok(all:find("UnitCreatureFamily = geheim", 1, true), "geheime Familie als „geheim“")
ok(all:find("C_Map.GetPlayerMapPosition(310) = geheim", 1, true), "geheime Position als „geheim“")
ok(all:find("C_Map.GetMapGroupID(310) = fehlt (gibt es nicht)", 1, true), "fehlende Funktion als „fehlt“")
ok(all:find("GetZoneText() = fehlt (FEHLER", 1, true), "Fehler einer Funktion als „fehlt“")
ok(all:find("UnitPosition(player) = fehlt", 1, true), "UnitPosition fehlt im Test")
ok(all:find("GetSubZoneText() = lesbar: Hof", 1, true), "lesbarer Wert mit Wert")
ok(all:find("nameplate1 (Namensplakette): Spieler oder Tier eines Spielers, übersprungen", 1, true), "Tier eines Spielers übersprungen")
ok(all:find("nameplate2 (Namensplakette), Besitz unklar", 1, true), "Tier mit geheimem Besitz gemessen")
ok(not all:find("nameplate3", 1, true), "Namensplakette ohne Familie nicht gemessen")
ok(all:find("Tooltip target = geheim", 1, true), "Tooltip mit geheimem Namen ist „geheim“")
ok(all:find("Tooltip nameplate2 = lesbar", 1, true), "Tooltip mit lesbaren Zeilen ist „lesbar“")
ok(all:find("boss1 bis boss5: keiner da", 1, true), "keine Bosse")
-- Chat: nur die Zusammenfassung
ok(printed("Instanz%-Probe Lauf 1 von höchstens 30 · Burg Probe %(party%)"), "Chat: Lauf und Ort")
ok(printed("Karte: %d+ lesbar, 1 geheim, %d+ fehlt"), "Chat: Zusammenfassung je Bereich")
ok(not printed("UnitName"), "Chat: keine Einzelwerte")
-- Teilen: Flüstern an sich selbst kommt an, die Instanzgruppe nicht
ok(#SENT == 2 and SENT[1].prefix == "FHPetsProbe" and SENT[1].kind == "WHISPER" and SENT[2].kind == "INSTANCE_CHAT",
  "gesendet über WHISPER und INSTANCE_CHAT mit eigenem Präfix")
RunTimers()
local last = run.lines[#run.lines]
ok(last:find("WHISPER angekommen nach", 1, true) and last:find("INSTANCE_CHAT nicht angekommen", 1, true),
  "Ergebnis des Teilens als eigene Zeile: " .. last)
ok(printed("Instanz%-Probe · Teilen nach 5 s"), "Ergebnis des Teilens im Chat")
-- keine Spielernamen
all = table.concat(run.lines, "\n")
ok(not all:find("Fremder", 1, true), "kein fremder Spielername im Protokoll")
ok(not all:find("Wolfsname", 1, true), "Name bei unklarem Besitz nicht geschrieben")
ok(not all:find("Realm", 1, true), "eigener Name nicht im Protokoll")

-- ---- Mehrere Läufe, „neu“, höchstens 30 ----
slash("api instanz")
ok(#NS.db.probeInst == 2, "zweiter Lauf hängt an")
slash("api instance")
ok(#NS.db.probeInst == 3, "englisch: /fhp api instance")
slash("api instanz neu")
ok(#NS.db.probeInst == 1, "„neu“ leert die Liste vor dem Lauf")
for i = 1, 35 do NOW = NOW + 1; slash("api instanz") end
ok(#NS.db.probeInst == 30, "höchstens 30 Läufe")
ok(NS.db.probeInst[30].at == NOW and NS.db.probeInst[1].at == NOW - 29, "die letzten 30 bleiben")
RunTimers()
ok(#ERRORS == 0, "alle Läufe ohne Fehler")

-- ---- offene Welt ohne Karte ----
function IsInInstance() return false, "none" end
function GetInstanceInfo() return "Kalimdor", "none" end
C_Map = {}
units = {}
slash("api instanz neu")
run = NS.db.probeInst[1]
ok(run.where == "offene Welt (Kalimdor)", "offene Welt: " .. tostring(run.where))
ok(table.concat(run.lines, "\n"):find("keine Tiere gemessen", 1, true), "ohne Tiere ein Hinweis")
RunTimers()
ok(#ERRORS == 0, "offene Welt ohne Fehler")

-- ---- /fhp api bleibt die alte Probe ----
local calls = {}
local rawApi, rawInst = NS.ProbeApi, NS.ProbeInstance
NS.ProbeApi = function() calls[#calls + 1] = "api" end
NS.ProbeInstance = function(fresh) calls[#calls + 1] = "instanz " .. tostring(fresh) end
slash("api")
slash("API Instanz NEU")
ok(calls[1] == "api" and calls[2] == "instanz true", "/fhp api unverändert, Instanz-Probe mit „neu“")
NS.ProbeApi, NS.ProbeInstance = rawApi, rawInst

-- ---- Beim Laden: älter als 14 Tage weg ----
Login({ probeInst = { { at = NOW - 15 * 86400, lines = {} }, { at = NOW - 3600, lines = { "frisch" } }, "kaputt" } })
ok(#NS.db.probeInst == 1 and NS.db.probeInst[1].lines[1] == "frisch", "Lauf von vor 15 Tagen und Kaputtes beim Laden gelöscht")
Login({ probeInst = { { at = NOW - 20 * 86400 } } })
ok(NS.db.probeInst == nil, "nur alte Läufe: Liste ganz weg")
Login({ probeInst = "kaputt" })
ok(NS.db.probeInst == nil, "kein Liste: weg")
