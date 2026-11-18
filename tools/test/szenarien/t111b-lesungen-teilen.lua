-- #111 Schritt B: Stücke bestätigter Lesungen der Wildtierausbildung teilen. Je Fähigkeit ein Stück; gesendet und
-- angenommen nur, was die Daten kennen, was die Daten der Familie zuordnen und was den bekannten TP und Pet-Stufen
-- nicht widerspricht; gesendet nur mit Lücke. Je Melder, Familie und Fähigkeit nur das neueste. Antwort auf einen
-- Gruß mit Stücken, nicht denen des Grüßenden.

SENT = {}
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  if kind == "YELL" then return 4 end
  return 0
end
function IsInGuild() return true end
function GetGuildInfo() return "Feierabendhelden" end

local function run() for _ = 1, 300 do RunTimers() end end
local function sentL1(kind, target)
  local out = {}
  for _, s in ipairs(SENT) do
    if s.msg:sub(1, 3) == "L1;" and (not kind or s.kind == kind) and (not target or s.target == target) then out[#out + 1] = s.msg end
  end
  return out
end
local function log() return NS.db.shareLog[#NS.db.shareLog] end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

Login({ ui = { share = true } })
run()
SENT = {}
local T = NOW - 100

-- Sender: eine bestätigte Lesung des Wolfs (Familie 1). Beißen ist vollständig bekannt (keine Lücke), Große Ausdauer
-- R5 hat keine TP und keine Pet-Stufe (Lücke), Klaue lernen Wölfe laut Daten nicht (fremde Familie).
NS.ReadingConfirmed(1, { at = T, rows = {
  [17253] = { status = "used", cost = 0, level = 1 }, [17255] = { status = "available", cost = 3, level = 8 },
  [4187] = { status = "used", cost = 5, level = 1 }, [4188] = { status = "used", cost = 10, level = 12 },
  [4189] = { status = "used", cost = 15, level = 18 }, [4190] = { status = "used", cost = 0, level = 24 },
  [4191] = { status = "unavailable", cost = 9, level = 30 },
  [16827] = { status = "available", cost = 0, level = 1 },
} })
run()
local out = sentL1("GUILD")
ok(#out == 1, "genau ein Stück gesendet: " .. #out)
ok(out[1] and out[1]:find("^L1;1;4187:u:5:1,4188:u:10:12,4189:u:15:18,4190:u:0:24,4191:n:9:30;%d+;%x+$"),
  "Große Ausdauer mit allen Rängen der Lesung, nach Rang: " .. tostring(out[1]))
ok(#NS.db.readings == 1, "eigenes Stück abgelegt")
NS.ReadingConfirmed(1, { at = T, rows = { [4190] = { status = "used", cost = 0, level = 24 },
  [4191] = { status = "unavailable", cost = 9, level = 30 }, [4187] = { status = "used", cost = 5, level = 1 },
  [4188] = { status = "used", cost = 10, level = 12 }, [4189] = { status = "used", cost = 15, level = 18 } } })
run()
ok(#sentL1("GUILD") == 1, "dieselbe Lesung wird nicht noch einmal gesendet")

-- Empfang
local function receive(body, sender)
  FireEvent("CHAT_MSG_ADDON", "FHPets", "L1;" .. body, "WHISPER", sender or "Fremder Spieler")
end
local good = ("5;7371:u:5:1,26177:u:0:12;%d;a1b2c3d4"):format(T)
receive(good)
ok(#NS.db.readings == 2 and log().new.L1 == 1, "gültiges Stück (Sturmangriff, Eber) gespeichert")
receive(good)
ok(#NS.db.readings == 2 and (log().dropped["L1 schon bekannt"] or 0) == 1, "dasselbe noch einmal: schon bekannt")
receive(("2;24604:a:10:10;%d;b1b2c3d4"):format(T))
ok((log().dropped["L1 fremde Familie"] or 0) == 1, "Wutgeheul für Katzen: fremde Familie")
receive(("1;1742:a:0:5,1753:a:2:15;%d;c1b2c3d4"):format(T))
ok((log().dropped["L1 widerspricht den Daten"] or 0) == 1, "Ducken R1 für 0 TP (kostet 8): widerspricht den Daten")
receive(("5;7371:u:5:3;%d;d1b2c3d4"):format(T))
ok((log().dropped["L1 widerspricht den Daten"] or 0) == 2, "Pet-Stufe 3 statt 1: widerspricht den Daten")
receive(("1;17253:u:0:1,1742:a:8:5;%d;e1b2c3d4"):format(T))
ok((log().dropped["L1 mehrere Fähigkeiten"] or 0) == 1, "zwei Fähigkeiten in einem Stück: verworfen")
receive(("5;7371:u:500:1;%d;f1b2c3d4"):format(T))
ok((log().dropped["L1 Werte"] or 0) == 1, "500 TP: unplausibel")
receive(("5;99999:u:5:1;%d;a2b2c3d4"):format(T))
ok((log().dropped["L1 unbekannter Rang"] or 0) == 1, "unbekannter Zauber: verworfen")
receive(("5;7371:u:5:1;%d;" .. NS.MyRep()):format(T))
ok((log().dropped["L1 eigene"] or 0) == 1, "eigenes Stück zurück: eigene")
local n = #NS.db.readings
receive(("5;7371:u:5:1,26177:u:0:12,26178:a:7:24;%d;a1b2c3d4"):format(T + 50))
ok(#NS.db.readings == n, "neueres Stück desselben Melders ersetzt das alte")
receive(("5;7371:u:5:1;%d;a3b2c3d4;neues Feld"):format(T))
ok(#NS.db.readings == n + 1, "ein Feld am Ende, das diese Version nicht kennt, wird übergangen")
ok(NS.db.via and NS.db.via["a1b2c3d4"] ~= nil, "Herkunft des Melders vermerkt")

-- Antwort auf einen Gruß: Stücke per Flüstern, eigene zuerst, nicht die des Grüßenden
SENT = {}
local greeter = "Gruss Jaeger"
local theirs = NS.ReporterHash("Gruss-Jaeger")
receive(("5;7371:u:5:1;%d;%s"):format(T, theirs), "Anderer Bote")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.3.0;5", "WHISPER", greeter)
run()
local reply = sentL1("WHISPER", greeter)
ok(#reply >= 2, "Antwort auf den Gruß enthält Stücke: " .. #reply)
ok(reply[1] and reply[1]:find(NS.MyRep() .. "$"), "eigenes Stück zuerst")
local echoed = false
for _, m in ipairs(reply) do if m:find(theirs .. "$") then echoed = true end end
ok(not echoed, "nichts vom Grüßenden selbst")

-- /fhp teilen
PRINTED = {}
NS.ShareStatus()
ok(printed("Lesungen %d+ · von"), "/fhp teilen zählt fremde Lesungen")
ok(printed("Lesungen %d+ · Grüße") or printed("Lesungen 0"), "/fhp teilen nennt die Art Lesungen")

-- Obergrenze 500: voll, dann fällt das älteste fremde weg, eigene bleiben
local list = NS.db.readings
local own = 0
for _, s in ipairs(list) do if s:find(NS.MyRep() .. "$") then own = own + 1 end end
local i = 0
while #list < 500 do
  i = i + 1
  list[#list + 1] = ("5;7371:u:5:1;%d;%08x"):format(T, 0x10000000 + i)
end
local oldestForeign
for _, s in ipairs(list) do if not s:find(NS.MyRep() .. "$") then oldestForeign = s; break end end
ok(NS.ReceiveReading(("5;7371:u:5:1;%d;9f9f9f9f"):format(T)) == true, "bei vollem Speicher wird ein neues Stück angenommen")
local stillOwn, stillOldest = 0, false
for _, s in ipairs(list) do
  if s:find(NS.MyRep() .. "$") then stillOwn = stillOwn + 1 end
  if s == oldestForeign then stillOldest = true end
end
ok(#list == 500 and stillOwn == own and not stillOldest, "500 bleiben, das älteste fremde fällt weg, eigene bleiben")
