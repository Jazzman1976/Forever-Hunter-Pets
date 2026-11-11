-- #160: Je Einloggen ein Eintrag in ForeverHunterPetsDB.shareLog, höchstens 30; shareStats entfällt. Gezählt werden
-- Grüße beim Beitritt, Rückgrüße, geflüsterte Grüße ohne R, Suchen und Treffer (Antwort binnen 2 Minuten), Versionen
-- je Absender, verschiedene Absender je Weg, Fehler im Teilen, Höchststand der Warteschlange und Drosselung. Keine Namen.

SENT = {}
local throttle = 0
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  if throttle > 0 then throttle = throttle - 1; return 3 end
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  if kind == "YELL" then return 4 end
  return 0
end
function IsInGuild() return true end
local party = false
function IsInGroup() return party end
function IsInRaid() return false end
LOCALIZED_CLASS_NAMES_MALE = { HUNTER = "Jäger" }
local who = {}
C_FriendList = {
  SendWho = function() end,
  GetNumWhoResults = function() return #who, #who end,
  GetWhoInfo = function(i) return who[i] end,
}
local function run() for _ = 1, 200 do RunTimers() end end

-- Jedes Einloggen ein Eintrag, höchstens 30; ein alter shareStats verschwindet
local db = { ui = { share = true }, shareStats = { sent = {} } }
Login(db)
run()
ok(#db.shareLog == 1 and db.shareStats == nil, "erster Eintrag, shareStats entfernt")
local e = db.shareLog[1]
ok(e.at == NOW and e.v == NS.version and e.rep == NS.MyRep(), "Eintrag mit Zeit, Version und Kürzel")
ok(e.yell == "aus (Ergebnis 4)", "Rufen im Eintrag: " .. tostring(e.yell))
for _ = 1, 35 do Login(db) end
ok(#db.shareLog == 30, "höchstens 30 Einträge: " .. #db.shareLog)
ok(db.shareLog[1] ~= e, "der älteste fällt weg")
ok(db.shareLog[30].yell == "aus (Ergebnis 4)", "Rufen bleibt im neuen Eintrag bekannt")
e = db.shareLog[#db.shareLog]

-- Gruß beim Beitritt, Rückgruß gesendet und empfangen, geflüsterter Gruß ohne R
party = true
FireEvent("GROUP_ROSTER_UPDATE")
run()
ok(e.groupGreets == 1, "Gruß beim Beitritt gezählt")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;3", "PARTY", "Erster Jaeger")
run()
ok(e.backSent == 1, "Rückgruß gesendet gezählt")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;3;R", "WHISPER", "Zweiter Jaeger")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "WHISPER", "Dritter Jaeger")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "GUILD", "Vierter Jaeger")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "GUILD", "Vierter Jaeger")
run()
ok(e.backRecv == 1, "Rückgruß empfangen gezählt")
ok(e.whisperGreets == 1, "geflüsterter Gruß ohne R gezählt")
ok(e.versions["1.2.0"] == 2 and e.versions["1.1.0"] == 2, "Versionen je verschiedenem Absender")
ok(e.senders.WHISPER == 2 and e.senders.GUILD == 1 and e.senders.PARTY == 1, "verschiedene Absender je Weg")

-- Suche und Treffer: Antwort binnen 2 Minuten zählt, eine spätere nicht, jeder Name einmal
who = {
  { fullName = "Fuenfter Jaeger", filename = "HUNTER", fullGuildName = "" },
  { fullName = "Sechster Jaeger", filename = "HUNTER", fullGuildName = "" },
  { fullName = "Siebter Jaeger", filename = "HUNTER", fullGuildName = "" },
}
NS.ShareSearch()
FireEvent("WHO_LIST_UPDATE")
run()
ok(e.searches == 1 and e.whoLists == 1 and e.searchGreeted == 3, "Suche, Liste und Grüße per Suche gezählt")
CLOCK = CLOCK + 60
FireEvent("CHAT_MSG_ADDON", "FHPets", "O1;30;5;17253;;1792400000;abcdef01", "WHISPER", "Fuenfter Jaeger")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;3;R", "WHISPER", "Fuenfter Jaeger")
CLOCK = CLOCK + 120
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "WHISPER", "Sechster Jaeger")
run()
ok(e.hits == 1, "Treffer: nur die Antwort binnen 2 Minuten, je Name einmal: " .. e.hits)

-- Höchststand der Warteschlange und Drosselung
ok(e.queueMax >= 1, "Höchststand der Warteschlange: " .. e.queueMax)
throttle = 2
NS.ShareOwn("154;17;24423;2.0;1792400000;")
run()
ok(e.throttled == 2, "Drosselung gezählt: " .. e.throttled)
ok(e.last == NOW, "letzte Aktivität gesetzt")

-- Fehler im Teilen: Stelle, Anzahl und erster Text; andere Stellen zählen nicht
NS.SafeCall("share", function() error("Testfehler eins") end)
NS.SafeCall("share", function() error("Testfehler zwei") end)
NS.SafeCall("window", function() error("anderer Fehler") end)
ERRORS = {}
ok(e.errors.share and e.errors.share.n == 2 and e.errors.share.first:find("Testfehler eins", 1, true), "Fehler im Teilen gezählt, erster Text")
ok(e.errors.window == nil, "Fehler außerhalb des Teilens zählen nicht")

-- Keine Namen im Verlauf
local function dump(t, out)
  for k, v in pairs(t) do
    out[#out + 1] = tostring(k)
    if type(v) == "table" then dump(v, out) else out[#out + 1] = tostring(v) end
  end
  return out
end
local text = table.concat(dump(db.shareLog, {}), "\n")
ok(not text:find("Jaeger", 1, true) and not text:find("Realm", 1, true), "kein Spielername im Verlauf")

-- /fhp teilen nennt Verlauf, Treffer und Versionen
PRINTED = {}
NS.ShareStatus()
local found
for _, p in ipairs(PRINTED) do if p:find("Verlauf: 30 Sitzungen", 1, true) and p:find("1.2.0", 1, true) then found = true end end
ok(found, "/fhp teilen nennt Verlauf und Versionen")
