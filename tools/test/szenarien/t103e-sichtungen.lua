-- #103 Punkt 1 (07.11.2026): Familie, Stufe, Einstufung und Name aus fremden Sichtungen erst ab 3 Meldern über zwei
-- Absender; eigene Sichtungen sofort
local sights, via, i = {}, {}, 0
local function sight(npc, level, name, rep, sender)
  i = i + 1
  sights[#sights + 1] = ("%d;%d;0;1;deDE;%s;%d;%s"):format(npc, level, name, 1792000000 + i, rep)
  if rep ~= "" then via[rep] = sender end
end
sight(990501, 10, "Einzelgaenger", "a0000001", "e0000001")
sight(990502, 10, "Dreierwolf", "a0000001", "e0000001")
sight(990502, 12, "Dreierwolf", "a0000002", "e0000002")
sight(990502, 11, "Dreierwolf", "a0000003", "e0000003")
sight(990503, 10, "Zweierwolf", "a0000001", "e0000001")
sight(990503, 10, "Zweierwolf", "a0000002", "e0000002")
sight(990504, 20, "Eigenwolf", "", nil)
sight(990505, 10, "Falsch", "b0000001", "e0000001")   -- drei Melder, aber nur einer nennt diesen Namen
sight(990505, 10, "Richtig", "b0000002", "e0000002")
sight(990505, 10, "Richtig", "b0000003", "e0000003")
sight(990505, 10, "Richtig", "b0000004", "e0000004")
Login({ sights = sights, via = via })

ok(NS.BeastInfo(990501) == nil and NS.BeastFamily(990501) == nil, "1 fremder Melder: keine Familie, keine Stufe")
ok(NS.BeastName(990501):find("990501"), "1 fremder Melder: Unbekanntes Tier (#ID)")
ok(NS.BeastInfo(990503) == nil and NS.BeastName(990503):find("990503"), "2 fremde Melder: noch nichts")
local b = NS.BeastInfo(990502)
ok(b and b.fam == 1 and b.min == 10 and b.max == 12, "3 fremde Melder: Familie 1, Stufe 10–12")
ok(NS.BeastName(990502) == "Dreierwolf", "3 fremde Melder: Name")
local own = NS.BeastInfo(990504)
ok(own and own.min == 20 and NS.BeastName(990504) == "Eigenwolf", "eigene Sichtung: sofort")
ok(NS.BeastName(990505) == "Richtig", "Name nur, den selbst 3 Melder nennen")
