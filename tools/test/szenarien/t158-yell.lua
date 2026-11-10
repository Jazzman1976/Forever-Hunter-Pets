-- #158: Der Gruß beim Einloggen geht einmal je Sitzung zusätzlich per YELL. Nimmt der Client ihn an, sendet
-- broadcast() für die Sitzung auch per YELL; lehnt er ab, kein weiterer Versuch. Grüße per YELL laufen durch die
-- Bremse aus #52. Der Selbsttest tritt FHPetsNet kurz bei, sendet über CHANNEL, merkt sich die Meldungen des Servers
-- ohne Namen, probiert YELL und verlässt den Kanal wieder.

SENT = {}
local yellResult = 4
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  if kind == "YELL" then return yellResult end
  return 0
end
function IsInGuild() return true end
local channel = 0
function GetChannelName(name) if name == "FHPetsNet" then return channel end return 0 end
local left = 0
function LeaveChannelByName(name) if name == "FHPetsNet" then left = left + 1; channel = 0 end end
local joined = 0
function JoinTemporaryChannel(name) if name == "FHPetsNet" then joined = joined + 1; channel = 7 end end

local function sent(prefix, kind)
  local n = 0
  for _, s in ipairs(SENT) do
    if s.msg:sub(1, #prefix) == prefix and s.kind == kind then n = n + 1 end
  end
  return n
end
local function run() for _ = 1, 60 do RunTimers() end end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

-- Client lehnt YELL ab: ein Versuch beim Einloggen, danach nicht mehr
Login({ ui = { share = true } })
run()
ok(sent("H1;", "YELL") == 1, "Gruß beim Einloggen einmal per YELL")
ok(sent("H1;", "GUILD") == 1, "Gruß beim Einloggen über die Gilde")
NS.ShareOwn("154;17;24423;2.0;1792400000;")
run()
ok(sent("O1;", "GUILD") == 1 and sent("O1;", "YELL") == 0, "YELL abgelehnt: Zähmung nur über die Gilde")
PRINTED = {}
NS.ShareStatus()
ok(printed("Rufen: aus %(Ergebnis 4%)"), "/fhp teilen: Rufen aus (Ergebnis 4)")
NS.db.ui.share = false
NS.ShareChanged()
NS.db.ui.share = true
NS.ShareChanged()
run()
ok(sent("H1;", "YELL") == 1, "abgelehnt: kein weiterer Versuch in der Sitzung")

-- Selbsttest: tritt bei, sendet über CHANNEL, merkt sich Meldungen ohne Namen, probiert YELL, verlässt den Kanal
yellResult = 0
NS.ShareTest()
ok(joined == 1 and channel == 7, "Selbsttest tritt FHPetsNet bei")
FireEvent("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "", "", "7. FHPetsNet", "", "", 0, 7, "FHPetsNet")
FireEvent("CHAT_MSG_CHANNEL_NOTICE_USER", "NOT_ALLOWED", "Fremder Jaeger", "", "7. FHPetsNet", "Fremder Jaeger", "", 0, 7, "FHPetsNet")
FireEvent("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "2. Handel", "", "", 0, 2, "Handel")
run()
local channelMsg
for _, s in ipairs(SENT) do if s.kind == "CHANNEL" then channelMsg = s end end
ok(channelMsg and channelMsg.msg:sub(1, 3) == "T1;" and channelMsg.target == 7, "Selbsttest sendet über CHANNEL an den Kanal 7")
ok(sent("T1;", "YELL") == 1, "Selbsttest probiert YELL")
ok(left >= 1 and channel == 0, "Selbsttest verlässt den Kanal wieder")
local probe = table.concat(NS.db.probe, "\n")
ok(probe:find("Meldungen des Servers: YOU_CHANGED nach", 1, true), "Meldung des Servers im Protokoll")
ok(probe:find("NOT_ALLOWED (Spieler)", 1, true), "Meldung zu einem Spieler im Protokoll")
ok(not probe:find("Fremder", 1, true), "kein Name im Protokoll")
ok(not probe:find("Handel", 1, true) and not probe:find("YOU_JOINED", 1, true), "Meldungen anderer Kanäle zählen nicht")
ok(probe:find("Selbsttest Rufen:", 1, true) and probe:find("Selbsttest Kanal:", 1, true), "Selbsttest meldet Rufen und Kanal")

-- Der Selbsttest hat YELL angenommen bekommen: ab jetzt ist YELL offen
NS.ShareOwn("154;18;24423;2.0;1792400001;")
run()
ok(sent("O1;", "YELL") == 1, "YELL angenommen: broadcast() sendet auch per YELL")
PRINTED = {}
NS.ShareStatus()
ok(printed("Rufen: an"), "/fhp teilen: Rufen an")

-- Grüße per YELL laufen durch die Bremse aus #52, ohne Rückgruß
local stats = NS.db.shareStats or {}
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;0", "YELL", "Erster Rufer")
stats = NS.db.shareStats
local replied, skipped = stats.replied, stats.skipped
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;0", "YELL", "Zweiter Rufer")
ok(stats.skipped == skipped + 1 and stats.replied == replied, "zweiter Gruß per YELL kurz danach: keine Antwort (#52)")
run()
local back = 0
for _, s in ipairs(SENT) do
  if s.kind == "WHISPER" and s.msg:sub(1, 3) == "H1;" then back = back + 1 end
end
ok(back == 0, "auf Grüße per YELL kein Rückgruß")
