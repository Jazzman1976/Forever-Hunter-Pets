-- #114: fremde Zähmungen mit unbekannten Zaubern werden angenommen, gespeichert und weitergereicht; sie widerlegen
-- nichts und zählen nicht als „lehrt nichts“. Unplausible Zauber-IDs werden verworfen.
SENT = {}
C_ChatInfo.SendAddonMessage = function(_, msg) SENT[#SENT + 1] = msg; return true end
Login({ ui = { share = true } })

-- ein Rang, den man von Tieren lernt, mit der kleinsten Stufe
local a, r
for _, x in ipairs(NS.Data.abilities) do
  if x.source == "tame" and NS.Learnable(x) and not a then a, r = x, x.ranks[1] end
end
ok(a ~= nil, "Fähigkeit zum Prüfen gefunden: " .. NS.AbilityName(a))

local UNKNOWN = 7777777
local function tame(npc, spells, rep, i)
  return ("O1;%d;60;%s;;%d;%s"):format(npc, spells, 1792000000 + i, rep)
end
local function send(msg, sender) FireEvent("CHAT_MSG_ADDON", "FHPets", msg, "WHISPER", sender) end

-- drei Melder über drei Absender: Tier 990001 mit unbekanntem Zauber, Tier 990002 ganz ohne Zauber (Gegenprobe)
local senders = { "Anna Eins", "Bert Zwei", "Cora Drei" }
for i, s in ipairs(senders) do
  local rep = ("aaaaaa%02d"):format(i)
  send(tame(990001, tostring(UNKNOWN), rep, i), s)
  send(tame(990002, "", rep, 10 + i), s)
end
ok(NS.ObservationCount() == 6, "alle sechs Zähmungen gespeichert, auch mit unbekanntem Zauber")
ok(NS.HasUnknownSpell(NS.ObservationsOf(990001)[1]), "Zauber " .. UNKNOWN .. " gilt als unbekannt")
ok(not NS.HasUnknownSpell(NS.ObservationsOf(990002)[1]), "Zähmung ohne Zauber hat keinen unbekannten")
ok(not NS.HasUnknownSpell(NS.ParseObservation("1;60;" .. r.id .. ";;1792000000;aaaaaaa1")), "bekannter Rang gilt nicht als unbekannt")

-- widerlegen
ok(NS.Observed(990002, a, r) == "refuted", "Gegenprobe: ohne Zauber ist der Rang ab 3 Meldern widerlegt")
ok(NS.Observed(990001, a, r) == nil, "mit unbekanntem Zauber ist der Rang nicht widerlegt")
ok(NS.EffectiveConf(990001, a, r, NS.CONF_SURE) == NS.CONF_SURE, "Belegung bleibt, wie die Daten sagen")

-- lehrt nichts
local info2 = NS.TeachInfo(990002, false)
ok(info2 ~= nil and #info2 == 0, "Gegenprobe: ohne Zauber „lehrt nichts“")
ok(NS.TeachInfo(990001, false) == nil, "mit unbekanntem Zauber nicht „lehrt nichts“, sondern unklar")

-- ein bekannter Rang neben dem unbekannten wird weiter gesehen
for i, s in ipairs(senders) do send(tame(990003, r.id .. "," .. UNKNOWN, ("aaaaaa%02d"):format(i), 20 + i), s) end
ok(NS.Observed(990003, a, r) == "seen", "bekannter Rang neben unbekanntem Zauber gilt als gesehen")

-- unplausibel
local before = NS.ObservationCount()
send(tame(990004, "0", "bbbbbb01", 31), "Dora Vier")
send(tame(990004, "10000000", "bbbbbb02", 32), "Dora Vier")
local many = {}
for i = 1, 21 do many[i] = tostring(100 + i) end
send(tame(990004, table.concat(many, ","), "bbbbbb03", 33), "Dora Vier")
local twenty = {}
for i = 1, 20 do twenty[i] = tostring(100 + i) end
send(tame(990004, table.concat(twenty, ","), "bbbbbb04", 34), "Dora Vier")
ok(NS.ObservationCount() == before + 1, "ID 0, ID über 9.999.999 und 21 IDs verworfen, 20 IDs angenommen")
local reasons = 0
for _, e in ipairs(NS.db.shareRejects or {}) do if e.why == "Zauber unplausibel" then reasons = reasons + 1 end end
ok(reasons == 3, "Grund „Zauber unplausibel“, dreimal")

-- weitergereicht: Antwort auf einen Gruß enthält die Zähmung mit dem unbekannten Zauber
SENT = {}
send("H1;0.13.0-beta;0", "Emil Fuenf")
for _ = 1, 30 do RunTimers() end
local relayed = false
for _, m in ipairs(SENT) do if m:find("^O1;990001;60;" .. UNKNOWN .. ";") then relayed = true end end
ok(relayed, "in der Antwort auf einen Gruß weitergereicht")

-- /fhp teilen
PRINTED = {}
NS.ShareStatus()
local line
for _, m in ipairs(PRINTED) do if m:find("Fremd gespeichert") then line = m end end
print("  " .. tostring(line))
ok(line and line:find("Zähmungen 10 (davon mit unbekannten Zaubern 7)", 1, true), "/fhp teilen zählt sie gesondert")
