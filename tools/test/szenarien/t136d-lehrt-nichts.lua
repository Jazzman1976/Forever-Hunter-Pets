-- #136: „lehrt nichts“ aus fremden Zähmungen – ab 2 Meldern unsicher („lehrt nichts?“, nur mit dem Schalter), ab 3 belegt
local obs, via, i = {}, {}, 0
local function tame(npc, rep, sender)
  i = i + 1
  obs[#obs + 1] = ("%d;30;;;%d;%s"):format(npc, 1792000000 + i, rep)
  via[rep] = sender
end
tame(990801, "a0000001", "e0000001"); tame(990801, "a0000002", "e0000002")
tame(990802, "a0000001", "e0000001"); tame(990802, "a0000002", "e0000002"); tame(990802, "a0000003", "e0000003")
Login({ obs = obs, via = via, ui = { showUncertain = false } })
local info, unsure = NS.TeachInfo(990801, false)
ok(info == nil and unsure, "2 Melder, Schalter aus: unklar, mit Hinweis")
local three = NS.TeachInfo(990802, false)
ok(three and #three == 0 and three.conf == nil, "3 Melder: lehrt nichts, belegt")
ok(NS.TeachText(990802) == NS.L["teaches nothing"], "Text ohne „?“")
NS.db.ui.showUncertain = true
local two = NS.TeachInfo(990801, false)
ok(two and #two == 0 and two.conf == NS.CONF_UNSURE, "2 Melder, Schalter an: lehrt nichts, unsicher")
ok(NS.TeachText(990801) == NS.L["teaches nothing"] .. "?", "Text „" .. NS.TeachText(990801) .. "“")
