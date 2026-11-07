-- #103 B1/B2: unbekannte Zauber aus fremden Zähmungen über den eigenen Client auflösen; ein neuer Rang einer bekannten
-- Fähigkeit erscheint ab 3 Meldern, ohne Pet-Stufe, und widerlegt nichts. Fremde Namen: nichts. 2 Melder: unsicher
-- (seit #136).
local a
for _, x in ipairs(NS.Data.abilities) do
  if x.de == "Ducken" then a = x end
end
ok(a ~= nil and a.source == "tame", "Fähigkeit Ducken in den Daten")
local top = 0
for _, r in ipairs(a.ranks) do top = math.max(top, r.rank) end
local NEW_RANK = top + 1

-- Zauber, die der Client kennt (Name, Rangtext); 7700003 lädt er erst nach
local SPELLS = {
  [7700001] = { "Ducken", NEW_RANK },        -- neuer Rang, 3 Melder
  [7700002] = { "Ducken", NEW_RANK + 1 },    -- neuer Rang, nur 2 Melder
  [7700003] = { "Ducken", NEW_RANK + 2 },    -- neuer Rang, 3 Melder, erst nach dem Nachladen
  [7700004] = { "Feuerball", 3 },            -- keine bekannte Fähigkeit, 3 Melder
}
LOADED = { [7700001] = true, [7700002] = true, [7700004] = true }
REQUESTED = {}
C_Spell.GetSpellName = function(id) return LOADED[id] and SPELLS[id] and SPELLS[id][1] or nil end
C_Spell.GetSpellSubtext = function(id) return LOADED[id] and SPELLS[id] and ("Rang " .. SPELLS[id][2]) or nil end
C_Spell.IsSpellDataCached = function(id) return LOADED[id] == true end
C_Spell.RequestLoadSpellData = function(id) REQUESTED[id] = true end

local obs, via, i = {}, {}, 0
local function tames(npc, spell, n)
  for k = 1, n do
    i = i + 1
    local rep = ("%07x%d"):format(npc % 0xfffffff, k)
    obs[#obs + 1] = ("%d;60;%s;;%d;%s"):format(npc, spell, 1792000000 + i, rep)
    via[rep] = ("e%07d"):format(k)
  end
end
tames(990401, "7700001", 3)
tames(990402, "7700002", 2)
tames(990403, "7700003", 3)
tames(990404, "7700004", 3)
tames(990405, "", 3)   -- Gegenprobe: Zähmungen ohne Zauber auf Stufe 60
Login({ obs = obs, via = via })
RunTimers()

local names = NS.db.spellNames
ok(names[7700001] and names[7700001].n == "Ducken" and names[7700001].r == NEW_RANK and names[7700001].l == "deDE",
  "Name und Rang vom Client gespeichert")
ok(names[7700004] and names[7700004].n == "Feuerball", "auch eine fremde Fähigkeit wird aufgelöst und gemerkt")
ok(names[7700003] == nil and REQUESTED[7700003], "nicht im Cache: Daten angefordert, noch nicht gespeichert")

local function rankOf(id)
  for _, x in ipairs(NS.Data.abilities) do
    for _, r in ipairs(x.ranks) do if r.id == id then return x, r end end
  end
end
local a1, r1 = rankOf(7700001)
ok(a1 == a and r1.rank == NEW_RANK, "Rang " .. NEW_RANK .. " hängt an Ducken (3 Melder)")
ok(r1.level == nil and r1.tp == nil, "ohne Pet-Stufe und TP")
local a2, r2 = rankOf(7700002)
ok(a2 == a and r2.conf == NS.CONF_UNSURE, "2 Melder: Rang als unsicher eingehängt (#136)")
ok(not NS.RankShown(r2) and NS.RankShown(r1), "unsicherer Rang ohne „Unsichere Angaben zeigen“ verborgen, belegter gezeigt")
ok(NS.RankLabel(a, r2) == "Rang " .. (NEW_RANK + 1) .. "?", "unsicherer Rang trägt „?“: " .. NS.RankLabel(a, r2))
ok(rankOf(7700004) == nil, "Name passt zu keiner Fähigkeit: keine neue Fähigkeit im Spiel")
ok(not NS.HasUnknownSpell(NS.ObservationsOf(990401)[1]), "der Zauber gilt jetzt als bekannt")

-- Lehrtiere und Widerlegen
local found = false
for _, t in ipairs(NS.Teachers(a, r1)) do if t.id == 990401 then found = true end end
ok(found, "Tier 990401 lehrt den neuen Rang")
ok(NS.Observed(990405, a, r1) == nil, "Zähmungen ohne den Rang widerlegen einen Rang ohne Pet-Stufe nicht")
local low = a.ranks[1]
ok(NS.Observed(990401, a, low) == nil, "der neue, höhere Rang widerlegt auch den niedrigeren nicht")

-- nachgeladen
LOADED[7700003] = true
FireEvent("SPELL_DATA_LOAD_RESULT", 7700003, true)
RunTimers()
ok(names[7700003] and names[7700003].r == NEW_RANK + 2, "nach dem Nachladen aufgelöst")
local a3 = rankOf(7700003)
ok(a3 == a, "und als Rang eingehängt")

-- /fhp teilen
PRINTED = {}
NS.ShareStatus()
local line
for _, m in ipairs(PRINTED) do if m:find("Unbekannte Zauber aus fremden") then line = m end end
print("  " .. tostring(line))
ok(line and line:find("unter der Schwelle 0", 1, true), "/fhp teilen: ab 2 Meldern ist nichts mehr unter der Schwelle (#136)")
