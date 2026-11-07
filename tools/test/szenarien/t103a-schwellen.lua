-- #103 A2: Lehrtier-Paare aus fremden Zähmungen – 1 Melder nichts, 2 unsicher, 3 belegt; 3 über einen Absender nichts
local a, r
for _, x in ipairs(NS.Data.abilities) do
  if x.source == "tame" and NS.Learnable(x) and not a then a, r = x, x.ranks[1] end
end
ok(a ~= nil, "Fähigkeit zum Prüfen gefunden: " .. NS.AbilityName(a))
ok(NS.FOREIGN_SURE == 3 and NS.FOREIGN_UNSURE == 2, "Schwellen an einer Stelle: belegt ab 3, unsicher ab 2")

-- Tier 990100 + n: von n Meldern über verschiedene Absender gesehen; 990109: 3 Melder über einen Absender
local obs, via = {}, {}
local function tame(npc, rep, i) obs[#obs + 1] = ("%d;60;%d;;%d;%s"):format(npc, r.id, 1792000000 + i, rep) end
local i = 0
for n = 1, 3 do
  for k = 1, n do
    i = i + 1
    local rep = ("a%d%06d"):format(n, k)
    tame(990100 + n, rep, i)
    via[rep] = ("e%07d"):format(k)
  end
end
for k = 1, 3 do
  i = i + 1
  local rep = ("b9%06d"):format(k)
  tame(990109, rep, i)
  via[rep] = "eeeeeee1"
end
Login({ obs = obs, via = via, ui = { showUncertain = false } })

ok(NS.Observed(990101, a, r) == nil, "1 Melder: nichts")
ok(NS.Observed(990102, a, r) == "unsure", "2 Melder: unsicher")
ok(NS.Observed(990103, a, r) == "seen", "3 Melder: belegt")
ok(NS.Observed(990109, a, r) == nil, "3 Melder über einen Absender: nichts")

local function conf(npc)
  for _, x in ipairs(NS.AllBeastTeaches(npc) or {}) do if x.r == r then return x.conf end end
end
ok(conf(990101) == nil, "1 Melder: kein Eintrag beim Tier")
ok(conf(990102) == NS.CONF_UNSURE, "2 Melder: Eintrag als unsicher")
ok(conf(990103) == NS.CONF_SURE, "3 Melder: Eintrag als belegt")

local function teaches(npc)
  for _, x in ipairs(NS.BeastTeaches(npc) or {}) do if x.r == r then return true end end
  return false
end
local function teacher(npc)
  for _, t in ipairs(NS.Teachers(a, r)) do if t.id == npc then return t end end
end
ok(not teaches(990102) and teacher(990102) == nil, "unsicher ist ohne Einstellung ausgeblendet")
ok(teaches(990103) and teacher(990103) ~= nil, "belegt wird gezeigt")
NS.db.ui.showUncertain = true
ok(teaches(990102), "mit „Unsichere Angaben zeigen“ beim Tier gezeigt")
local t = teacher(990102)
ok(t ~= nil and t.conf == NS.CONF_UNSURE and NS.ConfMark(t.conf) == "?", "und als Lehrtier mit „?“")
ok(teacher(990101) == nil, "1 Melder bleibt auch mit Einstellung unsichtbar")

-- ein fremder Widerspruch nimmt das Unsichere zurück
NS.db.obs[#NS.db.obs + 1] = ("%d;60;;;%d;%s"):format(990102, 1792000100, "c0000001")
NS.db.via.c0000001 = "eeeeeee9"
NS.ObservationsChanged()
ok(NS.Observed(990102, a, r) == nil, "2 sahen ihn, 1 widerspricht: nicht mehr unsicher")
