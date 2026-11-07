-- #136: Name, Familie und Stufe aus fremden Sichtungen – ab 2 Meldern unsicher (nur mit dem Schalter, mit „?“),
-- ab 3 belegt; eigene sofort
local sights, via, i = {}, {}, 0
local function sight(npc, level, name, rep, sender)
  i = i + 1
  sights[#sights + 1] = ("%d;%d;0;1;deDE;%s;%d;%s"):format(npc, level, name, 1792000000 + i, rep)
  if rep ~= "" then via[rep] = sender end
end
sight(990601, 10, "Einzelwolf", "a0000001", "e0000001")
sight(990602, 10, "Zweierwolf", "a0000001", "e0000001")
sight(990602, 12, "Zweierwolf", "a0000002", "e0000002")
sight(990603, 10, "Dreierwolf", "a0000001", "e0000001")
sight(990603, 11, "Dreierwolf", "a0000002", "e0000002")
sight(990603, 12, "Dreierwolf", "a0000003", "e0000003")
sight(990604, 20, "Eigenwolf", "", nil)
sight(990604, 21, "Fremdwolf", "a0000001", "e0000001")
sight(990604, 22, "Fremdwolf", "a0000002", "e0000002")
Login({ sights = sights, via = via, ui = { showUncertain = false } })
local WOLF = NS.FamilyName(1)

ok(NS.BeastInfo(990602) == nil and NS.BeastName(990602):find("990602"), "2 Melder, Schalter aus: nichts")
ok(NS.BeastInfo(990603).conf == NS.CONF_SURE and NS.BeastName(990603) == "Dreierwolf", "3 Melder: belegt, ohne „?“")
ok(NS.LevelText(NS.BeastInfo(990603)) == "10-12" and NS.BeastFamilyText(990603) == WOLF, "3 Melder: Stufe und Familie ohne „?“")

NS.db.ui.showUncertain = true
local b = NS.BeastInfo(990602)
ok(b and b.conf == NS.CONF_UNSURE, "2 Melder, Schalter an: unsicher")
ok(NS.BeastName(990602) == "Zweierwolf?", "Name mit „?“: " .. NS.BeastName(990602))
ok(NS.LevelText(b) == "10-12?", "Stufe mit „?“: " .. NS.LevelText(b))
ok(NS.BeastFamilyText(990602) == WOLF .. "?", "Familie mit „?“: " .. NS.BeastFamilyText(990602))
ok(NS.BeastInfo(990601) == nil, "1 Melder bleibt auch mit Schalter unsichtbar")
local own = NS.BeastInfo(990604)
ok(NS.BeastName(990604) == "Eigenwolf" and own.min == 20 and own.max == 20 and NS.LevelText(own) == "20",
  "eigene Sichtung geht vor, ohne „?“")
