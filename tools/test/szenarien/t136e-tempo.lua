-- #136: Angriffstempo wie jede Fähigkeit – ein Tempo ohne Tempo-Fähigkeit entsteht zur Laufzeit: eigenes sofort,
-- fremdes ab 2 unsicher (mit „?“, nur mit dem Schalter), ab 3 belegt
local obs, via, i = {}, {}, 0
local function tame(npc, speed, rep, sender)
  i = i + 1
  obs[#obs + 1] = ("%d;30;;%s;%d;%s"):format(npc, speed, 1792000000 + i, rep)
  if sender then via[rep] = sender end
end
tame(990901, "1.2", "", nil)                                             -- eigen
tame(990902, "1.1", "a0000001", "e0000001")                              -- 1 Melder
tame(990903, "1.0", "a0000001", "e0000001"); tame(990903, "1.0", "a0000002", "e0000002")   -- 2
tame(990904, "0.9", "a0000001", "e0000001"); tame(990904, "0.9", "a0000002", "e0000002"); tame(990904, "0.9", "a0000003", "e0000003")
Login({ obs = obs, via = via, ui = { showUncertain = false } })
RunTimers()
local function trait(speed)
  for _, a in ipairs(NS.Data.abilities) do
    if a.kind == "trait" and math.abs(a.speed - speed) < 0.05 then return a end
  end
end
local own = trait(1.2)
ok(own and own.ranks[1].id == -120 and own.ranks[1].conf == nil, "eigenes Tempo 1,2 s: Fähigkeit, belegt, Ersatz-ID -120")
ok(trait(1.1) == nil, "1 Melder: keine Fähigkeit")
local two = trait(1.0)
ok(two and two.ranks[1].conf == NS.CONF_UNSURE and not NS.RankShown(two.ranks[1]), "2 Melder: unsicher, ohne Schalter verborgen")
ok(NS.RankLabel(two, two.ranks[1]):sub(-1) == "?", "mit „?“: " .. NS.RankLabel(two, two.ranks[1]))
local three = trait(0.9)
ok(three and three.ranks[1].conf == nil and NS.RankShown(three.ranks[1]), "3 Melder: belegt")
local found = false
for _, t in ipairs(NS.Teachers(three, three.ranks[1])) do if t.id == 990904 then found = true end end
ok(found, "Lehrtier des Tempos 0,9 s ist Tier 990904")
NS.db.ui.showUncertain = true
ok(NS.RankShown(two.ranks[1]), "mit dem Schalter gezeigt")
