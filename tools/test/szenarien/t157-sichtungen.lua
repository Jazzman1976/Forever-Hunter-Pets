-- #157: Die Antwort auf einen Gruß enthält bis zu 10 eigene Sichtungen (aller eigenen Charaktere), die die
-- mitgelieferten Daten nicht kennen: die neuesten zuerst, höchstens eine je Tier. Fremde und bekannte nicht.

SENT = {}
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  return 0
end
function IsInGuild() return true end

-- ein Tier, das die Daten mit deutschem Namen und Stufe kennen
local knownNpc, knownLevel
for npc, b in pairs(NS.Data.beasts) do
  if b.de and b.min then knownNpc, knownLevel = npc, b.min; break end
end
ok(knownNpc ~= nil, "die Daten kennen ein Tier mit Namen und Stufe: " .. tostring(knownNpc))

local TWINK = "7e570002"
local t = 1792000000
local function sight(npc, level, name, rep)
  t = t + 1
  return ("%d;%d;0;1;deDE;%s;%d;%s"):format(npc, level, name, t, rep)
end
local sights = {
  sight(990601, 10, "Twinkwolf", TWINK),
  sight(990603, 10, "Fremdwolf", "b0000001"),
  sight(knownNpc, knownLevel, "Bekannt", TWINK),
  sight(990604, 10, "Doppelwolf", TWINK),
  sight(990604, 14, "Doppelwolf", TWINK),
}
Login({ ui = { share = true }, sights = sights, myReps = { [TWINK] = true } })
NS.AddSighting(sight(990602, 12, "Eigenwolf", NS.MyRep()))

local function sightsTo(target)
  local out = {}
  for _, s in ipairs(SENT) do
    if s.kind == "WHISPER" and s.target == target and s.msg:sub(1, 3) == "S1;" then out[#out + 1] = s.msg end
  end
  return out
end
local function has(list, pattern)
  for _, m in ipairs(list) do if m:find(pattern) then return true end end
  return false
end
local function run() for _ = 1, 100 do RunTimers() end end
run()

FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;0", "GUILD", "Gilden Jaeger")
run()
local got = sightsTo("Gilden Jaeger")
ok(has(got, "^S1;990601;10;"), "Sichtung eines Twinks ist dabei")
ok(has(got, "^S1;990602;12;"), "Sichtung des eingeloggten Charakters ist dabei")
ok(not has(got, "^S1;990603;"), "fremde Sichtung ist nicht dabei")
ok(not has(got, "^S1;" .. knownNpc .. ";"), "Sichtung, die die Daten kennen, ist nicht dabei")
ok(has(got, "^S1;990604;14;") and not has(got, "^S1;990604;10;"), "je Tier nur eine, die neueste")
ok(#got == 3, "drei Sichtungen in der Antwort: " .. #got)
for _, m in ipairs(got) do ok(m:match(";%x%x%x%x%x%x%x%x$"), "Sichtung trägt ein Kürzel: " .. m) end

-- Höchstens 10
for i = 1, 12 do NS.AddSighting(sight(990700 + i, 10, "Viel" .. i, NS.MyRep())) end
FireEvent("CHAT_MSG_ADDON", "FHPets", "H1;1.1.0;0", "GUILD", "Zweiter Jaeger")
run()
got = sightsTo("Zweiter Jaeger")
ok(#got == 10, "höchstens 10 Sichtungen: " .. #got)
ok(has(got, "^S1;990712;") and not has(got, "^S1;990601;"), "die neuesten zuerst")

-- Die Antwort hat höchstens 40 Nachrichten
local n = 0
for _, s in ipairs(SENT) do if s.target == "Zweiter Jaeger" then n = n + 1 end end
ok(n <= 40, "Antwort mit höchstens 40 Nachrichten: " .. n)
