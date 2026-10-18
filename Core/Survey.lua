-- Forever Hunter Pets · Erhebung: das Gerüst der Fähigkeiten aus dem Spiel (Umbau eigene Daten, Inkrement 2).
-- Schreibt still mit, was der Client über Pet-Fähigkeiten verrät, kontoweit in ForeverHunterPetsDB.survey:
--   ranks[Zauber-ID]    was über einen Rang feststeht, gesammelt aus allen Listen: Name in Client-Sprache, Rang,
--                       Icon; aus der Wildtierausbildung (bw) die Pet-Stufe (petLevel), vom Tierausbilder in
--                       der Stadt (npc) Jägerstufe (hunterLevel) und Preis in Kupfer (gold)
--   lists[Familien-ID]  die zuletzt gelesene vollständige Wildtierausbildung eines Pets dieser Familie:
--                       rows[Zauber-ID] = „Status/angezeigte TP“. Sie ersetzt die vorige, statt sie zu ergänzen:
--                       Der Client zeigt beim ersten Öffnen mitunter eine falsche Liste (16.10.2026), das
--                       zweite Öffnen berichtigt sie. Die TP sind die angezeigten, also abzüglich des aktuellen
--                       Rangs (siehe UI/Training.lua); den Preis rechnet der Import aus den Status aus.
--   spells[Zauber-ID]   ein Zauber aus dem Zauberbuch eines Pets: Name, Rang, passiv, Familien
--   families[ID]        Familienname in Client-Sprache
--   familyIcons[ID]     Icon der Familie (GetPetIcon des aktiven Pets), Datei-ID oder Pfad
--   lastRead            die zuletzt gelesene Liste roh, zur Fehlersuche
--   petRead             das Zauberbuch gleich nach dem letzten Zähmen roh: ID, Name, Rangtext, Subtext, geladen (#17)
-- Die Trainer-Liste selbst nennt keine Zauber-ID, der Tooltip der Zeile schon: Es ist die des Pet-Rangs,
-- in beiden Fenstern gleich und wie im Zauberbuch (im Spiel geprüft am 16.10.2026, Beißen 3 = 17256).
-- Damit ist die ID der Schlüssel, auch für Zeilen, denen kurz nach dem Öffnen noch der Rangtext fehlt.
-- Ohne ID (Tooltip versagt) steht die Zeile unter „Name|Rang“.
-- tools/import-observations.mjs holt das nach tools/eigene/. Nur außerhalb des Kampfs.
local _, ns = ...

local VERSION = 9

local function now() return time and time() or 0 end

local function store()
  if not ns.db then return nil end
  local s = ns.db.survey
  if type(s) ~= "table" then
    s = {}
    ns.db.survey = s
  end
  -- Version 1 stand unter „Name|Rang“ und mischte Pet- und Jägerstufe: Ränge neu erheben
  -- Version 2 und 3 sammelten Familien und TP je Rang auf, auch aus falschen Listen: das fällt weg, der
  -- Rest bleibt; die Listen je Familie kommen beim nächsten Öffnen
  -- Bis Version 4 galt auch der Jägerlehrer als Tierausbilder (#16): Ränge, die nur von dort stammen und die
  -- die Daten nicht als Tierausbilder-Rang kennen, sind Jägerzauber und fallen weg. Ein echter neuer Rang des
  -- Tierausbilders käme beim nächsten Besuch zurück.
  if s.v == 2 or s.v == 3 or s.v == 4 then
    for key, e in pairs(s.ranks or {}) do
      if type(e) == "table" and e.npc and not e.bw and not (s.spells and s.spells[key])
        and not (type(key) == "number" and ns.IsDataTrainerRank and ns.IsDataTrainerRank(key)) then
        s.ranks[key] = nil
      end
    end
  end
  if s.v == 2 or s.v == 3 then
    for _, e in pairs(s.ranks or {}) do e.tp, e.tpSeen, e.fam, e.used = nil, nil, nil, nil end
  elseif s.v ~= VERSION and not (type(s.v) == "number" and s.v >= 4 and s.v <= 8) then
    s.ranks, s.lists, s.lastRead = nil, nil, nil
  end
  -- Bis Version 8 galt die Wildtierausbildung als Tierausbilder, wenn zugleich ein NPC angesprochen war (#32):
  -- Pet-Stufen standen als Jägerstufe, TP als Preis da. Falsche und echte Angaben lassen sich nicht trennen,
  -- also fallen alle Tierausbilder-Angaben weg; ein Rang, der nur von dort stammte, ganz. Die Daten kennen den
  -- Tierausbilder, und der nächste Besuch dort erhebt ihn neu.
  if type(s.v) == "number" and s.v >= 2 and s.v <= 8 then
    for key, e in pairs(s.ranks or {}) do
      if type(e) == "table" and e.npc then
        e.npc, e.hunterLevel, e.gold = nil, nil, nil
        if not e.bw and not (s.spells and s.spells[key]) then s.ranks[key] = nil end
      end
    end
  end
  s.v = VERSION
  ns.db.trainerProbe = nil   -- Probe aus dem Test von #32
  s.locale = GetLocale and GetLocale() or s.locale
  s.ranks, s.lists, s.spells, s.families = s.ranks or {}, s.lists or {}, s.spells or {}, s.families or {}
  s.familyIcons = s.familyIcons or {}
  return s
end
ns.SurveyStore = store

local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function rankOf(text)
  return type(text) == "string" and tonumber(text:match("%d+")) or nil
end

local function subtextRank(id)
  if not (C_Spell and C_Spell.GetSpellSubtext) then return nil end
  local ok, sub = pcall(C_Spell.GetSpellSubtext, id)
  return ok and rankOf(ns.clean(sub)) or nil
end

-- Familie des aktiven Pets: ID und Name, sonst nil
local function petFamily()
  if not (UnitExists and UnitCreatureFamily) then return nil end
  local ok, exists = pcall(UnitExists, "pet")
  if not (ok and ns.clean(exists)) then return nil end
  local ok2, name, id = pcall(UnitCreatureFamily, "pet")
  name, id = ns.clean(name), ns.clean(id)
  if not (ok2 and id) then return nil end
  return id, name
end

-- ---- Zauber-ID aus dem Tooltip einer Trainer-Zeile ----
-- Zwei Wege, die im Spiel dasselbe liefern; der zweite nur, wenn der erste nichts bringt
local tip
local function tooltipId(i)
  if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
    local ok, d = pcall(C_TooltipInfo.GetTrainerService, i)
    d = ok and ns.clean(d)
    local id = type(d) == "table" and ns.clean(d.id)
    if type(id) == "number" and id > 0 then return id end
  end
  if CreateFrame and tip == nil then
    local ok, t = pcall(CreateFrame, "GameTooltip", "ForeverHunterPetsSurveyTip", nil, "GameTooltipTemplate")
    tip = ok and t or false
  end
  if not (tip and tip.SetTrainerService and tip.GetSpell) then return nil end
  tip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  local id
  if pcall(tip.SetTrainerService, tip, i) then
    -- je nach Client (name, id) oder (name, rang, id): die erste Zahl nehmen
    local res = { pcall(tip.GetSpell, tip) }
    for k = 2, #res do
      local v = res[1] and ns.clean(res[k])
      if type(v) == "number" and v > 0 then id = v; break end
    end
  end
  tip:Hide()
  return id
end

-- auch für den Lernstand (Core/Known.lua)
ns.TrainerServiceId = tooltipId

local function mark(set, key)
  if key == nil then return set end
  set = set or {}
  set[key] = true
  return set
end

-- Familienname aus einer anderen Quelle (Sichtung beim Anvisieren, Core/Sightings.lua)
function ns.SurveyFamily(id, name)
  local s = store()
  if s and type(id) == "number" and type(name) == "string" and name ~= "" then s.families[id] = name end
end

-- ---- Daten eines Zaubers nachladen (#17) ----
-- Einen Zauber, den der Client in dieser Sitzung noch nicht gezeigt hat, kennt er direkt nach dem Zähmen nur
-- mit ID und Name: Rangtext und Subtext fehlen, und ohne Rang nimmt MergeSurveyAbilities die Fähigkeit nicht
-- auf. Dann die Daten anfordern; sobald der Client sie meldet, das Zauberbuch noch einmal lesen.
-- loaded[id]: der Client hat die Daten (gemeldet oder laut IsSpellDataCached) – fehlt der Rang dann noch,
-- hat der Zauber keinen (etwa das Angriffstempo).
local requested, loaded = {}, {}
local function cached(id)
  if loaded[id] then return true end
  if C_Spell and C_Spell.IsSpellDataCached then
    local ok, v = pcall(C_Spell.IsSpellDataCached, id)
    if ok and ns.clean(v) then loaded[id] = true; return true end
  end
  return false
end

local function requestLoad(id)
  if requested[id] or cached(id) or not (C_Spell and C_Spell.RequestLoadSpellData) then return end
  requested[id] = true
  pcall(C_Spell.RequestLoadSpellData, id)
end

-- Wartet für diese Zauber-IDs noch ein Rang auf die Daten des Clients? (Chatzeile beim Zähmen, Core/Observe.lua)
function ns.SurveyRankPending(ids)
  local s = ns.db and ns.db.survey
  for _, id in ipairs(ids or {}) do
    local e = s and s.spells and s.spells[id]
    if not (e and e.rank) and not cached(id) then return true end
  end
  return false
end

local rereadSoon = false
local function onLoaded(id)
  id = ns.clean(id)
  if not requested[id] then return end
  requested[id], loaded[id] = nil, true
  if rereadSoon then return end
  rereadSoon = true
  ns.After(0.2, function()
    rereadSoon = false
    ns.SafeCall("survey", ns.SurveyPetSpells)
  end)
end
ns.On("SPELL_DATA_LOAD_RESULT", onLoaded)
ns.On("SPELL_TEXT_UPDATE", onLoaded)

-- ---- Zauberbuch des aktiven Pets ----
-- tame: gleich nach dem Zähmen; dann bleibt das Lesen roh in survey.petRead (Messpunkt zu #17)
function ns.SurveyPetSpells(tame)
  if inCombat() then return end
  local s = store()
  local SB = C_SpellBook
  if not (s and SB and SB.HasPetSpells and SB.GetSpellBookItemInfo) then return end
  local fam, famName = petFamily()
  if not fam then return end
  s.families[fam] = famName or s.families[fam]
  -- das Icon der Familie nennt der Client nur für das aktive Pet
  if GetPetIcon then
    local okI, icon = pcall(GetPetIcon)
    icon = okI and ns.clean(icon)
    if icon then s.familyIcons[fam] = icon end
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
  local ok, n = pcall(SB.HasPetSpells)
  n = ok and tonumber(ns.clean(n)) or 0
  local raw = tame and { at = now() } or nil
  for i = 1, math.min(n, 60) do
    local ok2, info = pcall(SB.GetSpellBookItemInfo, i, bank)
    info = ok2 and ns.clean(info)
    local id = type(info) == "table" and ns.clean(info.spellID)
    if type(id) == "number" then
      local e = s.spells[id] or {}
      e.name = ns.clean(info.name) or e.name
      local sub = ns.clean(info.subName)
      local fromSub = subtextRank(id)
      e.rank = rankOf(sub) or fromSub or e.rank
      e.passive = ns.clean(info.isPassive) and true or nil
      e.fam = mark(e.fam, fam)
      e.t = now()
      s.spells[id] = e
      if not e.rank then requestLoad(id) end
      if raw and #raw < 20 then
        raw[#raw + 1] = ("%d | %s | %s | %s | geladen %s"):format(id, tostring(e.name), tostring(sub),
          tostring(fromSub), tostring(cached(id)))
      end
    end
  end
  if raw then s.petRead = raw end
  -- ein neuer Rang gilt sofort (Core/Index.lua)
  if ns.MergeSurveyAbilities then ns.MergeSurveyAbilities() end
end

-- ---- Trainer-Liste: Wildtierausbildung oder Tierausbilder in der Stadt ----
-- Aufgerufen aus Core/Known.lua, wenn die Liste vollständig zu sehen ist (auch „Bereits bekannt“).
function ns.SurveyTrainer(atNpc)
  if inCombat() or not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
  local s = store()
  if not s then return end
  local fam
  if not atNpc then
    local famName
    fam, famName = petFamily()
    if fam then s.families[fam] = famName or s.families[fam] end
  end
  local ok, n = pcall(GetNumTrainerServices)
  n = ok and tonumber(ns.clean(n)) or 0
  -- Protokoll des letzten Lesens, roh: zeigt, ob und was gelesen wurde (wird jedes Mal ersetzt)
  -- how: wie Core/Known.lua das Fenster beim Öffnen eingeordnet hat (NPC da?, Sekunden seit 5149, Ergebnis, #32)
  local raw = { at = now(), npc = atNpc and true or nil, fam = fam, n = n, how = ns.trainerDecision }
  s.lastRead = raw
  -- die IDs dieses Lesens je Zeile, für den Lernstand gleich danach (eine Tooltip-Abfrage je Zeile reicht)
  local ids = {}
  ns.trainerIds = ids
  -- Liste der Familie: gilt nur, wenn jede Zeile Rangtext und ID hat (sonst ist sie unfertig)
  local rows, complete = {}, n > 0
  for i = 1, math.min(n, 200) do
    local ok2, name, status, icon, level, rankText = pcall(GetTrainerServiceInfo, i)
    if #raw < 40 then
      local parts = { tostring(ok2) }
      for _, v in ipairs({ name, status, icon, level, rankText }) do
        parts[#parts + 1] = (ns.clean(v) == nil and v ~= nil) and "<geheim>" or tostring(v)
      end
      raw[#raw + 1] = table.concat(parts, " | ")
    end
    name, status, icon, level = ns.clean(name), ns.clean(status), ns.clean(icon), tonumber(ns.clean(level))
    -- Kopfzeilen der Liste haben den Status „header“
    if ok2 and type(name) == "string" and status ~= "header" then
      local id = tooltipId(i)
      ids[i] = id
      local rank = rankOf(ns.clean(rankText)) or (id and subtextRank(id))
      local key = id or (rank and (name .. "|" .. rank))
      if key then
        local e = s.ranks[key] or {}
        e.name, e.rank, e.icon = name, rank or e.rank, icon or e.icon
        local ok3, cost = pcall(GetTrainerServiceCost, i)
        cost = ok3 and tonumber(ns.clean(cost)) or nil
        if atNpc then
          -- Stufe des Jägers; 0 heißt „kennt er schon“, dann nennt die Liste keine
          e.npc, e.gold = true, cost or e.gold
          if level and level > 0 then e.hunterLevel = level end
        else
          e.bw, e.petLevel = true, level or e.petLevel
          if id and rankOf(ns.clean(rankText)) then
            rows[id] = tostring(status) .. "/" .. tostring(cost)
          else
            complete = false
          end
        end
        e.t = now()
        s.ranks[key] = e
      else
        complete = false
      end
    end
  end
  if not atNpc then
    if fam and complete then s.lists[fam] = { at = now(), rows = rows } end
    ns.SurveyPetSpells()
  elseif ns.MergeSurveyAbilities then
    ns.MergeSurveyAbilities()   -- ein neuer Rang gilt sofort (Core/Index.lua)
  end
end

-- Pet gerufen oder etwas gelernt: Zauberbuch kurz danach lesen, mehrere Ereignisse ergeben einen Durchlauf
local pending = false
local function petSoon()
  if pending then return end
  pending = true
  ns.After(3, function()
    pending = false
    ns.SafeCall("survey", ns.SurveyPetSpells)
  end)
end
ns.On("UNIT_PET", function(unit) if ns.clean(unit) == "player" then petSoon() end end)
ns.On("SPELLS_CHANGED", petSoon)

-- /fhp erhebung: Stand im Chat (Entwicklerwerkzeug, nur deutsch)
function ns.SurveyStatus()
  local s = store()
  if not s then return end
  local abilities, ranks, bw, npc, noId, fams, spells = {}, 0, 0, 0, 0, 0, 0
  for key, e in pairs(s.ranks) do
    abilities[e.name] = true
    ranks = ranks + 1
    if e.bw then bw = bw + 1 end
    if e.npc then npc = npc + 1 end
    if type(key) ~= "number" then noId = noId + 1 end
  end
  local nAbilities = 0
  for _ in pairs(abilities) do nAbilities = nAbilities + 1 end
  -- je Familie: Name und Zeilen der gültigen Liste, ohne Liste „keine Liste“
  local famNames = {}
  for id, name in pairs(s.families) do
    fams = fams + 1
    local list, count = s.lists[id], 0
    for _ in pairs(list and list.rows or {}) do count = count + 1 end
    famNames[#famNames + 1] = tostring(name) .. (list and (" " .. count) or " (keine Liste)")
  end
  table.sort(famNames)
  for _ in pairs(s.spells) do spells = spells + 1 end
  ns.Print(("Erhebung: %d Fähigkeiten, %d Ränge (%d aus der Wildtierausbildung, %d vom Tierausbilder, %d ohne "
    .. "Zauber-ID) · %d Zauber aus Pet-Zauberbüchern · %d Familien: %s"):format(
    nAbilities, ranks, bw, npc, noId, spells, fams, fams > 0 and table.concat(famNames, ", ") or "–"))
  if ns.SeenBeast then
    local npcs, beasts, own = {}, 0, 0
    for _, s2 in ipairs(ns.db.sights or {}) do
      local o = ns.ParseSighting(s2)
      if o then
        if o.own then own = own + 1 end
        if not npcs[o.npc] then npcs[o.npc] = true; beasts = beasts + 1 end
      end
    end
    ns.Print(("Sichtungen: %d von %d Tieren, davon %d eigene"):format(ns.SightingCount(), beasts, own))
  end
  local r = s.lastRead
  if type(r) == "table" then
    ns.Print(("Zuletzt gelesen um %s: %s, %d Zeilen"):format(date and date("%H:%M:%S", r.at) or "?",
      r.npc and "Tierausbilder" or "Wildtierausbildung", r.n or 0))
  else
    ns.Print("Eine Trainer-Liste wurde noch nicht gelesen.")
  end
end
