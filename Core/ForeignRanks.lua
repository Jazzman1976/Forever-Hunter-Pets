-- Forever Hunter Pets · Fremde Ränge (#103): Zauber aus fremden Zähmungen, die die Daten noch nicht kennen.
-- Seit #114 werden solche Zähmungen gespeichert und geteilt. Hier wird jede unbekannte Zauber-ID über den eigenen
-- Client in Name und Rang aufgelöst (C_Spell.GetSpellName, Rangtext wie in Core/Survey.lua). Das sind Daten, die der
-- Client zur Laufzeit liefert; übertragen wird dafür nichts.
--
-- Ablage kontoweit: ForeverHunterPetsDB.spellNames[Zauber-ID] = { n = Name, r = Rang, l = Sprache des Clients },
-- höchstens MAX_NAMES Einträge. Ohne Rangtext (passive Zauber wie das Angriffstempo) bleibt eine ID unaufgelöst.
--
-- Ein aufgelöster Rang wird zur Fähigkeit (ns.MergeSurveyAbilities, Core/Index.lua), wenn sein Name zu einer
-- bekannten Fähigkeit passt, die man von Tieren lernt, und ns.FOREIGN_SURE fremde Melder über zwei Absender ihn beim
-- Zähmen zeigten. Er kommt ohne Pet-Stufe und TP; die bringt erst die Wildtierausbildung. Ganz neue Fähigkeiten
-- erscheinen im Spiel nie, sie kommen nur über die Stammdaten (Prüfung auf Jägerzauber beim Import, #37).
local _, ns = ...

local MAX_NAMES = 500

local function store()
  if not ns.db then return nil end
  if type(ns.db.spellNames) ~= "table" then ns.db.spellNames = {} end
  return ns.db.spellNames
end

-- Unbekannte Zauber-IDs aus fremden Zähmungen: { [id] = { reps = { [Kürzel] = true }, n, npcs = { [npc] = true } } }
local function unknownIds()
  local out = {}
  for _, s in ipairs((ns.db and ns.db.obs) or {}) do
    local o = ns.ParseObservation(s)
    if o and not o.own then
      for id in pairs(o.spells) do
        if not ns.IsKnownSpell(id) then
          local e = out[id]
          if not e then
            e = { reps = {}, n = 0, npcs = {} }
            out[id] = e
          end
          if not e.reps[o.rep] then e.reps[o.rep] = true; e.n = e.n + 1 end
          e.npcs[o.npc] = true
        end
      end
    end
  end
  return out
end

-- ---- Auflösen ----
local tried = {}   -- in dieser Sitzung geladen und ohne Rang: nicht noch einmal fragen
local function resolveOne(names, id, count)
  if names[id] or tried[id] then return count, false end
  local name
  if C_Spell and C_Spell.GetSpellName then
    local ok, v = pcall(C_Spell.GetSpellName, id)
    name = ok and ns.clean(v) or nil
  end
  local rank = ns.SubtextRank and ns.SubtextRank(id)
  if type(name) == "string" and name ~= "" and #name <= 60 and type(rank) == "number" and rank > 0 then
    if count >= MAX_NAMES then return count, false end
    names[id] = { n = name, r = rank, l = GetLocale and GetLocale() or "enUS" }
    return count + 1, true
  end
  if ns.SpellDataCached and ns.SpellDataCached(id) then
    tried[id] = true
  elseif ns.RequestSpellData then
    ns.RequestSpellData(id)
  end
  return count, false
end

-- Alle unbekannten IDs auflösen, die es noch nicht sind; danach die Fähigkeiten neu zusammenführen, wenn etwas dazukam
function ns.ResolveForeignRanks()
  local names = store()
  if not names then return end
  local count = 0
  for _ in pairs(names) do count = count + 1 end
  local added = false
  for id in pairs(unknownIds()) do
    local new
    count, new = resolveOne(names, id, count)
    added = added or new
  end
  if added and ns.MergeSurveyAbilities then ns.MergeSurveyAbilities() end
end

-- Kandidaten für ns.MergeSurveyAbilities: aufgelöste IDs ab ns.FOREIGN_SURE fremden Meldern über zwei Absender,
-- mit den Familien der Tiere, die sie zeigten: { { id, name, rank, fams = { [Familie] = true } }, … }
function ns.ForeignRankCandidates()
  local names = ns.db and ns.db.spellNames
  if type(names) ~= "table" or not next(names) then return {} end
  local out = {}
  for id, e in pairs(unknownIds()) do
    local nm = names[id]
    if type(nm) == "table" and type(nm.n) == "string" and type(nm.r) == "number" and ns.ForeignEnough(e.reps, e.n) then
      local fams = {}
      for npc in pairs(e.npcs) do
        local fam = ns.BeastFamily(npc)
        if fam then fams[fam] = true end
      end
      out[#out + 1] = { id = id, name = nm.n, rank = nm.r, fams = fams }
    end
  end
  return out
end

-- Für /fhp teilen: unbekannte Zauber aus fremden Zähmungen – aufgelöst, davon unter der Schwelle (noch nicht gezeigt)
function ns.ForeignRankStatus()
  local names = (ns.db and ns.db.spellNames) or {}
  local total, resolved, below = 0, 0, 0
  for id, e in pairs(unknownIds()) do
    total = total + 1
    if type(names[id]) == "table" then
      resolved = resolved + 1
      if not ns.ForeignEnough(e.reps, e.n) then below = below + 1 end
    end
  end
  return total, resolved, below
end

-- Beim Einloggen (wenn das Zauberbuch und die Daten stehen) und sobald der Client nachgeladene Daten meldet
local soon = false
local function resolveSoon(delay)
  if soon then return end
  soon = true
  ns.After(delay, function()
    soon = false
    ns.SafeCall("foreignranks", ns.ResolveForeignRanks)
  end)
end
ns.On("PLAYER_LOGIN", function() resolveSoon(10) end)
ns.On("SPELL_DATA_LOAD_RESULT", function() resolveSoon(1) end)
