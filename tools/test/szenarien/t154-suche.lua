-- #154: Kommt eine Wer-Liste (WHO_LIST_UPDATE), flüstert das Addon jedem Jäger darin einmal je Sitzung den Gruß:
-- nur Jäger (filename HUNTER), nicht sich selbst, nicht die eigene Gilde, keinen zweimal; höchstens 20 je Liste und
-- 100 je Sitzung. /fhp suchen startet die Suche mit dem Klassennamen in der Sprache des Clients.

SENT = {}
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  if kind == "YELL" then return 4 end
  return 0
end
function IsInGuild() return true end
function GetGuildInfo() return "Feierabendhelden" end
LOCALIZED_CLASS_NAMES_MALE = { HUNTER = "Jäger" }
local who, searched = {}, {}
C_FriendList = {
  SendWho = function(filter) searched[#searched + 1] = filter end,
  GetNumWhoResults = function() return #who, #who end,
  GetWhoInfo = function(i) return who[i] end,
}
local function hunter(name, guild) return { fullName = name, filename = "HUNTER", fullGuildName = guild or "" } end
local function other(name) return { fullName = name, filename = "WARRIOR", fullGuildName = "" } end

local function greeted()
  local out = {}
  for _, s in ipairs(SENT) do
    if s.kind == "WHISPER" and s.msg:sub(1, 3) == "H1;" then out[s.target] = (out[s.target] or 0) + 1 end
  end
  return out
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function run() for _ = 1, 200 do RunTimers() end end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

Login({ ui = { share = true } })
run()

-- /fhp suchen: eine Suche mit dem Klassennamen in der Sprache des Clients
PRINTED = {}
SlashCmdList.FOREVERHUNTERPETS("suchen")
ok(#searched == 1 and searched[1] == 'c-"Jäger"', "/fhp suchen ruft SendWho mit c-\"Jäger\" auf")
ok(printed("Suche Jäger"), "/fhp suchen meldet die Suche")
SlashCmdList.FOREVERHUNTERPETS("search")
ok(#searched == 2, "/fhp search tut dasselbe")
ok(count(greeted()) == 0, "vor WHO_LIST_UPDATE wird niemand gegrüßt")

-- Eine Liste mit Jägern und anderen Klassen, mit einem selbst und einem Gildenmitglied
who = { hunter("Test Realm"), hunter("Erste Jaegerin"), other("Ein Krieger"), hunter("Gilden Jaeger", "Feierabendhelden"),
  hunter("Zweiter Jäger", "Andere Gilde") }
FireEvent("WHO_LIST_UPDATE")
run()
local g = greeted()
ok(g["Erste Jaegerin"] == 1 and g["Zweiter Jäger"] == 1, "Jäger werden gegrüßt, auch mit Umlaut")
ok(g["Ein Krieger"] == nil, "andere Klassen nicht")
ok(g["Test Realm"] == nil, "sich selbst nicht")
ok(g["Gilden Jaeger"] == nil, "die eigene Gilde nicht")
local msg
for _, s in ipairs(SENT) do if s.target == "Erste Jaegerin" then msg = s.msg end end
ok(msg:match("^H1;[^;]+;%d+$"), "Gruß ohne R, damit der andere zurückgrüßt: " .. msg)

-- Dieselbe Liste noch einmal: keiner zweimal
FireEvent("WHO_LIST_UPDATE")
run()
g = greeted()
ok(g["Erste Jaegerin"] == 1 and g["Zweiter Jäger"] == 1, "keiner zweimal")

-- Wer gegrüßt wurde, bekommt auf seinen Rückgruß Antwort, aber keinen weiteren Gruß
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;4;R", "WHISPER", "Erste Jaegerin")
run()
ok(greeted()["Erste Jaegerin"] == 1, "auf den Rückgruß kein zweiter Gruß")
ok(NS.db.shareLog[#NS.db.shareLog].replied >= 1, "auf den Rückgruß eine Antwort")

-- Höchstens 20 je Liste
who = {}
for i = 1, 50 do who[i] = hunter("Jaeger Nummer" .. i) end
FireEvent("WHO_LIST_UPDATE")
run()
g = greeted()
local n = 0
for name in pairs(g) do if name:find("^Jaeger Nummer") then n = n + 1 end end
ok(n == 20, "höchstens 20 je Liste: " .. n)

-- Höchstens 100 je Sitzung (2 + 20 bisher)
for round = 1, 6 do
  who = {}
  for i = 1, 50 do who[i] = hunter(("Runde%d Jaeger%d"):format(round, i)) end
  FireEvent("WHO_LIST_UPDATE")
  run()
end
ok(count(greeted()) == 100, "höchstens 100 je Sitzung: " .. count(greeted()))
PRINTED = {}
SlashCmdList.FOREVERHUNTERPETS("suchen")
ok(#searched == 2 and printed("schon 100 Jäger"), "/fhp suchen nach 100 Grüßen: keine Suche mehr")
PRINTED = {}
NS.ShareStatus()
ok(printed("gegrüßt per Suche: 100"), "/fhp teilen zählt die Grüße per Suche")

-- In Kampf und Instanz: keine Suche, kein Gruß
InCombatLockdown = function() return true end
PRINTED = {}
NS.ShareSearch()
ok(printed("Nicht im Kampf"), "im Kampf keine Suche")
InCombatLockdown = function() return false end

-- Abgeschaltet: keine Suche
NS.db.ui.share = false
PRINTED = {}
NS.ShareSearch()
ok(#searched == 2 and printed("Teilen ist ausgeschaltet"), "abgeschaltet keine Suche")
