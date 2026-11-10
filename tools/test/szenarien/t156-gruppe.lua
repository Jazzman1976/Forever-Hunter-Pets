-- #156: Beim Beitritt in eine Gruppe oder einen Schlachtzug grüßt das Addon einmal über PARTY bzw. RAID, nicht in
-- Kampf und Instanz. Auf einen Gruß über Gruppe, Schlachtzug oder Flüstern flüstert es einmal je Sitzung den
-- eigenen Gruß zurück (Rückgruß, H1;…;R), über die Gilde nicht; auf einen Rückgruß wird nicht zurückgegrüßt.

SENT = {}
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  return 0
end
local party, raid, instance = false, false, false
function IsInGroup() return party or raid end
function IsInRaid() return raid end
function IsInInstance() return instance end
function IsInGuild() return true end

local function greetings(kind, target)
  local n = 0
  for _, s in ipairs(SENT) do
    if s.msg:sub(1, 3) == "H1;" and s.kind == kind and (target == nil or s.target == target) then n = n + 1 end
  end
  return n
end
local function run() for _ = 1, 60 do RunTimers() end end
local function roster() FireEvent("GROUP_ROSTER_UPDATE"); run() end

Login({ ui = { share = true }, obs = { "154;17;24423;2.0;1792400000;" } })
run()
ok(greetings("GUILD") == 1 and greetings("PARTY") == 0, "beim Einloggen ohne Gruppe nur über die Gilde gegrüßt")

-- Beitritt in eine Gruppe: ein Gruß über PARTY, kein zweiter bei weiteren Änderungen der Gruppe
party = true
roster()
ok(greetings("PARTY") == 1, "Beitritt: Gruß über PARTY")
local partyMsg
for _, s in ipairs(SENT) do if s.kind == "PARTY" then partyMsg = s.msg end end
ok(partyMsg:match("^H1;[^;]+;%d+$"), "Gruppen-Gruß ohne R: " .. partyMsg)
roster()
roster()
ok(greetings("PARTY") == 1, "weitere Änderungen der Gruppe grüßen nicht neu")
ok(greetings("GUILD") == 1, "Beitritt grüßt nicht über die Gilde")

-- Umwandlung in einen Schlachtzug grüßt nicht neu
raid = true
roster()
ok(greetings("RAID") == 0, "Umwandlung in einen Schlachtzug: kein Gruß")

-- Verlassen und Beitritt in einen Schlachtzug: Gruß über RAID
party, raid = false, false
roster()
raid = true
roster()
ok(greetings("RAID") == 1 and greetings("PARTY") == 1, "Beitritt in einen Schlachtzug: Gruß über RAID")

-- In einer Instanz (Schlachtfeld) und im Kampf: kein Gruß
party, raid = false, false
roster()
instance = true
raid = true
roster()
ok(greetings("RAID") == 1, "Beitritt in einer Instanz: kein Gruß")
instance = false
party, raid = false, false
roster()
InCombatLockdown = function() return true end
party = true
roster()
InCombatLockdown = function() return false end
run()
ok(greetings("PARTY") == 1, "Beitritt im Kampf: kein Gruß")

-- Gruß über PARTY von X: Antwort und genau ein Rückgruß an X, mit R
local stats = NS.db.shareStats or {}
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "PARTY", "Erster Jaeger")
run()
stats = NS.db.shareStats
ok(greetings("WHISPER", "Erster Jaeger") == 1, "Gruß über PARTY: ein Rückgruß an den Grüßenden")
local back
for _, s in ipairs(SENT) do if s.kind == "WHISPER" and s.msg:sub(1, 3) == "H1;" then back = s.msg end end
ok(back:match("^H1;[^;]+;%d+;R$"), "Rückgruß trägt R: " .. back)
local answered = 0
for _, s in ipairs(SENT) do if s.kind == "WHISPER" and s.target == "Erster Jaeger" and s.msg:sub(1, 3) == "O1;" then answered = answered + 1 end end
ok(answered == 1, "Gruß über PARTY: Antwort mit der eigenen Zähmung")

-- Zweiter Gruß von X: weder Antwort noch Rückgruß
local replied = stats.replied
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "PARTY", "Erster Jaeger")
run()
ok(stats.replied == replied and greetings("WHISPER", "Erster Jaeger") == 1, "zweiter Gruß von X: weder Antwort noch Rückgruß")

-- Gruß über die Gilde: Antwort, kein Rückgruß
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;3", "GUILD", "Gilden Jaeger")
run()
ok(stats.replied == replied + 1, "Gruß über die Gilde: Antwort")
ok(greetings("WHISPER", "Gilden Jaeger") == 0, "Gruß über die Gilde: kein Rückgruß")

-- Rückgruß von Y (geflüstert, mit R): Antwort, aber kein weiterer Rückgruß – keine Schleife
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;5;R", "WHISPER", "Zweiter Jaeger")
run()
ok(stats.replied == replied + 2, "Rückgruß von Y: Antwort")
ok(greetings("WHISPER", "Zweiter Jaeger") == 0, "Rückgruß von Y: kein Gruß zurück")

-- Geflüsterter Gruß ohne R (etwa aus einer Suche, #154): Antwort und Rückgruß
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.2.0;5", "WHISPER", "Dritter Jaeger")
run()
ok(stats.replied == replied + 3 and greetings("WHISPER", "Dritter Jaeger") == 1, "geflüsterter Gruß ohne R: Antwort und Rückgruß")

-- Gruß über RAID: Rückgruß
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;0", "RAID", "Vierter Jaeger")
run()
ok(greetings("WHISPER", "Vierter Jaeger") == 1, "Gruß über RAID: Rückgruß")

-- Abgeschaltet: kein Gruß beim Beitritt
NS.db.ui.share = false
party = false
roster()
party = true
local before = #SENT
roster()
ok(#SENT == before, "abgeschaltet: kein Gruß beim Beitritt")
