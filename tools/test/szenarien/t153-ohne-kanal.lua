-- #153: Der Server sperrt Addon-Nachrichten im Kanal FHPetsNet, YELL lehnt der Client ab. Gesendet wird über Gilde
-- und Gruppe, nie über CHANNEL; der alte Kanal wird beim Einloggen verlassen und keiner betreten. YELL nur als Probe
-- einmal je Sitzung, und Kanal und Rufen im Selbsttest (#158, Szenario t158-yell).
-- Versand und Empfang werden je Weg gezählt (ohne Selbsttest-Nachrichten); was der Client ablehnt, zählt als
-- verworfen.

SENT = {}
local refuse = {}   -- Weg → Ergebnis, das der Client einmal liefert
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  if kind == "YELL" then return 4 end   -- wie live seit dem Start von Forever
  local r = refuse[kind]
  refuse[kind] = nil
  return r or 0
end
local channel = 6
function GetChannelName(name) if name == "FHPetsNet" then return channel end return 0 end
local left, joined = {}, false
function LeaveChannelByName(name) left[#left + 1] = name; if name == "FHPetsNet" then channel = 0 end end
function JoinTemporaryChannel() joined = true end
function IsInGuild() return true end

local function sentVia(prefix)
  local ways = {}
  for _, s in ipairs(SENT) do
    if s.msg:sub(1, #prefix) == prefix then ways[s.kind] = (ways[s.kind] or 0) + 1 end
  end
  return ways
end

local function printed(pattern)
  for _, p in ipairs(PRINTED) do
    if p:find(pattern) then return p end
  end
end

-- Einloggen: alten Kanal verlassen, keinem beitreten, Gruß nur über die Gilde
Login({ ui = { share = true } })
for _ = 1, 10 do RunTimers() end
ok(left[1] == "FHPetsNet", "alter Kanal FHPetsNet beim Einloggen verlassen")
ok(#left == 1, "nur einmal verlassen, der zweite Versuch findet ihn nicht mehr")
ok(not joined, "keinem Kanal beigetreten")
local h = sentVia("H1;")
ok(h.GUILD == 1, "Gruß über die Gilde")
ok(h.CHANNEL == nil, "nichts über CHANNEL")
ok(h.YELL == 1, "YELL nur einmal als Probe (#158)")

-- Ohne Kanal in der Liste wird auch nichts verlassen
channel = 0
Login({ ui = { share = true } })
for _ = 1, 10 do RunTimers() end
ok(#left == 1, "ohne alten Kanal kein LeaveChannelByName")

-- Abgeschaltet: verlassen ja, senden nein
channel = 6
local before = #SENT
Login({ ui = { share = false } })
for _ = 1, 10 do RunTimers() end
ok(#left == 2, "auch bei abgeschaltetem Teilen wird der alte Kanal verlassen")
ok(#SENT == before, "abgeschaltet wird nichts gesendet")

-- Empfang je Weg; Bremse aus #52 für Grüße aus dem Kanal (ältere Versionen), nicht für die Gilde
Login({ ui = { share = true } })
for _ = 1, 10 do RunTimers() end
local db = NS.db
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.0.0;0", "CHANNEL", "Erster Jaeger")
local stats = db.shareStats
ok(stats and stats.recvWay.CHANNEL == 1, "Gruß aus dem Kanal als Weg CHANNEL gezählt")
local replied, skipped = stats.replied, stats.skipped
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.0.0;0", "CHANNEL", "Zweiter Jaeger")
ok(stats.skipped == skipped + 1 and stats.replied == replied, "zweiter Gruß aus dem Kanal kurz danach: keine Antwort (#52)")
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;0", "GUILD", "Gilden Jaeger")
ok(stats.replied == replied + 1, "Gruß über die Gilde: immer eine Antwort")
FireEvent("CHAT_MSG_ADDON", "FHPets", "O1;30;5;17253;;1792400000;abcdef01", "WHISPER", "Erster Jaeger")
ok(stats.recvWay.CHANNEL == 2 and stats.recvWay.GUILD == 1 and stats.recvWay.WHISPER == 1,
  "Empfang je Weg: Kanal 2, Gilde 1, Flüstern 1")
FireEvent("CHAT_MSG_ADDON", "FHPets", "X9;unbekannt", "GUILD", "Gilden Jaeger")
ok(stats.recvWay.GUILD == 1, "unbekannte Nachrichten zählen nicht")

-- Selbsttest: Gilde und Flüstern, weder Kanal noch YELL; T1 zählt bei keinem Weg
for _ = 1, 30 do RunTimers() end
local sentWayBefore = {}
for k, v in pairs(stats.sentWay) do sentWayBefore[k] = v end
local recvBefore = stats.recvWay.GUILD
NS.ShareTest()
for _ = 1, 10 do RunTimers() end
local t = sentVia("T1;")
ok(t.GUILD == 1 and t.WHISPER == 1, "Selbsttest über Gilde und Flüstern")
ok(t.CHANNEL == nil, "Selbsttest ohne Beitritt nicht über CHANNEL")
local echo
for _, s in ipairs(SENT) do
  if s.kind == "GUILD" and s.msg:sub(1, 3) == "T1;" then echo = s.msg end
end
FireEvent("CHAT_MSG_ADDON", "FHPets", echo, "GUILD", "Test Realm")
ok(stats.recvWay.GUILD == recvBefore, "Echo des Selbsttests zählt nicht beim Empfang")
for k, v in pairs(stats.sentWay) do ok(sentWayBefore[k] == v, "Selbsttest zählt nicht beim Versand über " .. k) end
-- (die nachgebildeten Timer kennen keine Wartezeit: der Abschluss läuft vor dem Echo, deshalb nur die Wege)
local probe = table.concat(db.probe, "\n")
ok(probe:find("Selbsttest Gilde:", 1, true) and probe:find("Selbsttest Flüstern:", 1, true), "Selbsttest meldet Gilde und Flüstern")
ok(probe:find("Selbsttest Kanal: nicht beigetreten", 1, true), "Selbsttest meldet den Kanal als nicht beigetreten")

-- Lehnt der Client ab, zählt das nicht als gesendet, sondern als verworfen
refuse.GUILD = 4
local guildBefore = stats.sentWay.GUILD or 0
NS.ShareOwn("154;17;24423;2.0;1792400000;")
for _ = 1, 10 do RunTimers() end
ok((stats.sentWay.GUILD or 0) == guildBefore, "abgelehnte Nachricht nicht als gesendet gezählt")
ok(stats.dropped["GUILD vom Client abgelehnt (Ergebnis 4)"] == 1, "abgelehnte Nachricht als verworfen gezählt")

-- /fhp teilen: zwei Zeilen je Weg, Kanal nur, wenn etwas kam; keine Kanalnummer mehr im Kopf
PRINTED = {}
NS.ShareStatus()
local recvLine = printed("^.-Empfangen je Weg: ")
ok(recvLine and recvLine:find("Gilde 1 · Gruppe 0 · Schlachtzug 0 · Flüstern 1 · Kanal 2", 1, true),
  "Zeile „Empfangen je Weg“ mit allen Wegen")
local sentLine = printed("^.-Gesendet je Weg: ")
ok(sentLine and not sentLine:find("Kanal", 1, true) and not sentLine:find("Rufen", 1, true), "Zeile „Gesendet je Weg“ ohne Kanal und Rufen")
ok(printed("Rufen: aus %(Ergebnis 4%)"), "Kopf: Rufen aus (Ergebnis 4)")
ok(not printed("Kanal Nr%.") and not printed("nicht beigetreten"), "keine Kanalnummer mehr im Kopf")
