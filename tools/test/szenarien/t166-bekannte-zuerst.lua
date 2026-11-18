-- #166: Bekannte Addon-Nutzer in der Wer-Liste zuerst grüßen. Bekannt ist, wessen Kürzel das Addon schon kennt:
-- Melder (Schlüssel von via und viaLegacy) und Absender (Werte von via), ohne die eigenen. Bekannte werden vor allen
-- anderen gegrüßt und zählen nicht gegen 20 je Liste und 100 je Sitzung; mehr als einen Gruß je Sitzung bekommen
-- auch sie nicht.

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

-- Kürzel wie im Addon: „Vorname Nachname“ → „Vorname-Nachname“
local function rep(name) return NS.ReporterHash((name:gsub(" ", "-"))) end

local function greetings()
  local out, order = {}, {}
  for _, s in ipairs(SENT) do
    if s.kind == "WHISPER" and s.msg:sub(1, 3) == "H1;" then
      out[s.target] = (out[s.target] or 0) + 1
      order[#order + 1] = s.target
    end
  end
  return out, order
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function run() for _ = 1, 400 do RunTimers() end end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

-- Melder (Schlüssel von via), Absender (Wert von via), alter Melder (viaLegacy), eigener Twink in via
local MELDER, ABSENDER, ALT, TWINK = "Bekannte Melderin", "Bekannter Absender", "Alter Melder", "Eigener Twink"
local via = {}
via[rep(MELDER)] = rep("Irgend Wer") .. rep(ABSENDER)
via[rep(TWINK)] = rep("Noch Wer")
Login({ ui = { share = true }, via = via, viaLegacy = { [rep(ALT)] = true }, myReps = { [rep(TWINK)] = true } })
run()

-- Eine Liste mit 40 Jägern; die Bekannten stehen weit hinten, einer in der eigenen Gilde
who = {}
for i = 1, 40 do who[i] = hunter("Fremder Jaeger" .. i) end
who[30] = hunter(MELDER)
who[35] = hunter(ABSENDER)
who[38] = hunter(ALT)
who[39] = hunter(TWINK)
who[40] = hunter("Gilden Bekannter", "Feierabendhelden")
NS.db.via[rep("Gilden Bekannter")] = rep("Irgend Wer")
FireEvent("WHO_LIST_UPDATE")
run()
local g, order = greetings()
ok(g[MELDER] == 1, "Melder aus via wird gegrüßt, obwohl er an Stelle 30 steht")
ok(g[ABSENDER] == 1, "Absender aus via wird gegrüßt")
ok(g[ALT] == 1, "Melder aus viaLegacy wird gegrüßt")
ok(g[TWINK] == nil, "eigener Twink zählt nicht als Bekannter (und steht hinter den 20)")
ok(g["Gilden Bekannter"] == nil, "die eigene Gilde nicht, auch kein Bekannter darin")
local firstThree = {}
for i = 1, 3 do firstThree[order[i]] = true end
ok(firstThree[MELDER] and firstThree[ABSENDER] and firstThree[ALT], "Bekannte werden zuerst gegrüßt")
local strangers = 0
for name in pairs(g) do if name:find("^Fremder Jaeger") then strangers = strangers + 1 end end
ok(strangers == 20, "dazu wie bisher 20 Unbekannte: " .. strangers)
local log = NS.db.shareLog[#NS.db.shareLog]
ok(log.knownGreeted == 3 and log.searchGreeted == 20, "Zähler: 3 Bekannte, 20 Unbekannte (" .. tostring(log.knownGreeted) .. ", " .. tostring(log.searchGreeted) .. ")")

-- Dieselbe Liste noch einmal: keiner zweimal, auch kein Bekannter
FireEvent("WHO_LIST_UPDATE")
run()
g = greetings()
ok(g[MELDER] == 1 and g[ABSENDER] == 1 and g[ALT] == 1, "Bekannte nur einmal je Sitzung")

-- 100 Unbekannte voll machen (20 bisher + 20 aus der zweiten Runde oben)
for round = 1, 6 do
  who = {}
  for i = 1, 50 do who[i] = hunter(("Runde%d Jaeger%d"):format(round, i)) end
  FireEvent("WHO_LIST_UPDATE")
  run()
end
ok(NS.db.shareLog[#NS.db.shareLog].searchGreeted == 100, "100 Unbekannte gegrüßt")

-- Nach 100: /fhp suchen sucht trotzdem und meldet es; ein neuer Bekannter wird gegrüßt, ein Unbekannter nicht
local before = #searched
PRINTED = {}
SlashCmdList.FOREVERHUNTERPETS("suchen")
ok(#searched == before + 1, "/fhp suchen sucht auch nach 100 Grüßen")
ok(printed("nur noch bekannte Addon%-Nutzer"), "und meldet, dass nur noch Bekannte gegrüßt werden")
NS.db.via[rep("Spaeter Bekannt")] = rep("Irgend Wer")
who = { hunter("Noch Ein Fremder"), hunter("Spaeter Bekannt") }
FireEvent("WHO_LIST_UPDATE")
run()
g = greetings()
ok(g["Spaeter Bekannt"] == 1, "nach 100 Grüßen wird ein Bekannter noch gegrüßt")
ok(g["Noch Ein Fremder"] == nil, "ein Unbekannter nicht mehr")
ok(NS.db.shareLog[#NS.db.shareLog].searchGreeted == 100, "Bekannte zählen nicht gegen die 100")

-- /fhp teilen nennt beide Zahlen
PRINTED = {}
NS.ShareStatus()
ok(printed("gegrüßt per Suche: 100 Unbekannte, 4 Bekannte"), "/fhp teilen: Unbekannte und Bekannte getrennt")
