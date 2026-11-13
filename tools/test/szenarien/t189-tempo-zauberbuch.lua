-- #189: Das Angriffstempo zählt nur nach dem Zauberbuch einer Zähmung, nie nach dem gemessenen Tempo (Buffs des
-- Jägers verfälschen es). Ein Tempo-Zauber, den die Daten nicht kennen, wird nur aus einer eigenen Zähmung sofort
-- zur Fähigkeit; sein Tempo kommt aus der Beschreibung des Zaubers. Ersetzt t136e (Tempo aus Messwerten, #136).
local FASTER_I = 1263099   -- Schnellerer Angriff I (1,7 s) aus den Daten
local function traitOf(id)
  for _, a in ipairs(NS.Data.abilities) do
    if a.kind == "trait" and a.ranks[1].id == id then return a end
  end
end
local a1 = traitOf(FASTER_I)
ok(a1 ~= nil and math.abs(a1.speed - 1.7) < 0.05, "Schnellerer Angriff I (1,7 s) in den Daten")
local a2data = traitOf(1263100)
ok(a2data ~= nil and math.abs(a2data.speed - 1.6) < 0.05, "Schnellerer Angriff II (1,6 s) in den Daten (von Hand)")

-- Neue Zauber, die der Client kennt (passiv, ohne Rang); 7800004 lädt er erst nach
LOADED = { [7800001] = true, [7800002] = true, [7800003] = true, [7800005] = true, [7800006] = true }
REQUESTED = {}
local DESC = {
  [7800001] = "Erhöht das Angriffstempo um 30%.",
  [7800002] = "Erhöht das Angriffstempo um 66%.",
  [7800003] = "Erhöht die Ausdauer um 10%.",
  [7800004] = "Erhöht das Angriffstempo um 25%.",
  [7800005] = "Ein Zauber ohne Zahl.",
  [7800006] = "Verringert das Angriffstempo um 20 %.",
}
C_Spell.IsSpellDataCached = function(id) return LOADED[id] == true end
C_Spell.RequestLoadSpellData = function(id) REQUESTED[id] = true end
C_Spell.GetSpellDescription = function(id) return LOADED[id] and DESC[id] or "" end
local survey = { v = 10, spells = {
  [7800001] = { name = "Neues Tempo A", passive = true },        -- eigene Zähmungen, gebufft gemessen
  [7800002] = { name = "Neues Tempo B", passive = true },        -- nur fremde Zähmungen
  [7800003] = { name = "Passiv ohne Tempo", passive = true },    -- eigene Zähmung mit 2,0 s
  [7800004] = { name = "Noch nicht geladen", passive = true },   -- eigene Zähmung, Daten fehlen
  [7800005] = { name = "Ohne Prozent", passive = true },         -- eigene Zähmung, Beschreibung ohne Zahl
  [7800006] = { name = "Langsam neu", passive = true },          -- eigene Zähmung, langsamer
} }

local obs, via, i = {}, {}, 0
local function tame(npc, spells, speed, rep, sender)
  i = i + 1
  obs[#obs + 1] = ("%d;30;%s;%s;%d;%s"):format(npc, spells, speed, 1792000000 + i, rep)
  if sender then via[rep] = sender end
end
local function foreign(npc, spells, speed, n)
  for k = 1, n do tame(npc, spells, speed, ("%07x%d"):format(npc % 0xfffffff, k), ("e%07d"):format(k)) end
end
tame(991001, "7371", "1.7", "")                    -- eigen, unter Buff: 1,7 s, kein Tempo-Zauber
tame(991002, "7371," .. FASTER_I, "1.5", "")       -- eigen, Tempo-Zauber, abweichend gemessen
foreign(991003, tostring(FASTER_I), "1.7", 2)      -- 2 fremde mit Tempo-Zauber
foreign(991004, tostring(FASTER_I), "1.7", 3)      -- 3 fremde mit Tempo-Zauber
foreign(991005, "", "1.7", 3)                      -- 3 fremde, 1,7 s ohne Tempo-Zauber
tame(991007, "7800001", "1.3", "")                 -- 30 % → 1,5 s, gemessen unter Buff 1,3 s
tame(991007, "7800001", "1.3", "")
foreign(991008, "7800002", "1.2", 3)
tame(991009, "7800003", "2.0", "")
tame(991010, "7800004", "1.6", "")
tame(991011, "7800005", "1.6", "")
tame(991012, "7800006", "2.2", "")                 -- −20 % → 2,5 s, gemessen unter Buff 2,2 s
-- eigene Sichtung eines wilden Tiers mit 1,3 s
local sights = { ("991006;30;0;1;deDE;Schnelles Tier;%d;;1.3"):format(1792000000) }
Login({ obs = obs, via = via, sights = sights, survey = survey, ui = { showUncertain = false } })
RunTimers()
NS.MergeSurveyAbilities()

local function has(list, a)
  for _, e in ipairs(list or {}) do if e.a == a then return true end end
  return false
end

-- gemessenes Tempo zählt nicht
ok(NS.Observed(991001, a1, a1.ranks[1]) == "refuted", "eigene Zähmung mit 1,7 s ohne Tempo-Zauber: widerlegt")
ok(not has(NS.ObservedExtra(991001), a1), "… und kein Schnellerer Angriff I beim Tier")
ok(NS.Observed(991002, a1, a1.ranks[1]) == "seen", "eigene Zähmung mit Tempo-Zauber, gemessen 1,5 s: gesehen")
ok(has(NS.ObservedExtra(991002), a1), "… und Schnellerer Angriff I beim Tier")
ok(NS.Observed(991003, a1, a1.ranks[1]) == "unsure", "2 fremde Melder mit Tempo-Zauber: unsicher")
ok(NS.Observed(991004, a1, a1.ranks[1]) == "seen", "3 fremde Melder mit Tempo-Zauber: belegt")
ok(NS.Observed(991005, a1, a1.ranks[1]) == "refuted", "3 fremde Melder mit 1,7 s ohne Tempo-Zauber: widerlegt")

-- kein Platzhalter, keine Lehrtiere aus Sichtungen
for _, a in ipairs(NS.Data.abilities) do
  if a.kind == "trait" then
    ok(a.ranks[1].id > 0, "Tempo-Fähigkeit mit echter Zauber-ID: " .. tostring(a.de) .. " " .. a.ranks[1].id)
    for _, t in ipairs(NS.ObservedTeachers(a, a.ranks[1])) do
      ok(t.id ~= 991006, "Sichtung mit 1,3 s macht das Tier nicht zum Lehrtier von " .. tostring(a.de))
    end
  end
end

-- neuer Tempo-Zauber aus der eigenen Zähmung, Tempo aus der Beschreibung
local a2 = traitOf(7800001)
ok(a2 and a2.de == "Neues Tempo A", "eigene Zähmung: neuer Tempo-Zauber wird sofort eine Fähigkeit")
ok(a2 and math.abs(a2.speed - 1.5) < 0.05, "… Tempo aus der Beschreibung (+30 % → 1,5 s), nicht gemessen 1,3 s: "
  .. tostring(a2 and a2.speed))
ok(a2 and a2.ranks[1].conf == nil and NS.Observed(991007, a2, a2.ranks[1]) == "seen", "… belegt beim Tier")
local slow = traitOf(7800006)
ok(slow and math.abs(slow.speed - 2.5) < 0.05, "langsamer (−20 % → 2,5 s), nicht gemessen 2,2 s: "
  .. tostring(slow and slow.speed))
ok(traitOf(7800002) == nil, "nur fremde Zähmungen: keine neue Tempo-Fähigkeit")
ok(traitOf(7800003) == nil, "passiver Zauber bei 2,0 s: keine Tempo-Fähigkeit")
ok(traitOf(7800005) == nil, "Beschreibung ohne Prozentzahl: keine Tempo-Fähigkeit")
ok(traitOf(7800004) == nil and REQUESTED[7800004], "Daten noch nicht geladen: angefordert, noch keine Fähigkeit")

-- nach dem Laden kommt er dazu
LOADED[7800004] = true
NS.MergeSurveyAbilities()
local late = traitOf(7800004)
ok(late and math.abs(late.speed - 1.6) < 0.05, "nach dem Laden: neue Tempo-Fähigkeit mit 1,6 s")

-- Reihenfolge: Tempo-Fähigkeiten stehen am Ende nach dem Tempo, auch die zur Laufzeit angelegten
local last, sorted, seenTrait, mixed = 0, true, false, false
for _, a in ipairs(NS.Data.abilities) do
  if a.kind == "trait" then
    seenTrait = true
    if a.speed < last then sorted = false end
    last = a.speed
  elseif seenTrait then
    mixed = true
  end
end
ok(sorted and not mixed, "Tempo-Fähigkeiten am Ende, nach dem Tempo sortiert")
