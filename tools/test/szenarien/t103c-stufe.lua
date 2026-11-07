-- #103 A3: Stufe eines Tiers, das nicht in den Daten steht, aus Zähmungen – eigene sofort, fremde erst ab 3 Meldern
local obs, via = {}, {}
local function tame(npc, level, rep, i) obs[#obs + 1] = ("%d;%d;;;%d;%s"):format(npc, level, 1792000000 + i, rep) end
tame(990301, 12, "a0000001", 1); via.a0000001 = "e0000001"
tame(990302, 12, "a0000001", 2)
tame(990302, 14, "a0000002", 3); via.a0000002 = "e0000002"
tame(990302, 13, "a0000003", 4); via.a0000003 = "e0000003"
tame(990303, 20, "", 5)   -- eigene (ohne Kürzel)
Login({ obs = obs, via = via })

ok(NS.BeastInfo(990301) == nil, "eine fremde Zähmung: keine Stufe, kein Tier")
local b = NS.BeastInfo(990302)
ok(b and b.min == 12 and b.max == 14, "3 fremde Melder: Stufe 12–14")
local own = NS.BeastInfo(990303)
ok(own and own.min == 20 and own.max == 20, "eigene Zähmung: Stufe sofort")
