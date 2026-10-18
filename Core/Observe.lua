-- Forever Hunter Pets · Beobachtungen beim Zähmen: was ein Tier wirklich mitbringt.
-- Ablauf laut Zähm-Probe (docs/technik/api-befunde.md): Zu Beginn von „Wildtier zähmen“ (1515)
-- ist das Tier noch das Ziel – nur dessen GUID trägt die NPC-ID, die des Pets nicht. Nach dem Kanal kommt
-- zweimal UNIT_PET; erst beim zweiten steht das Zauberbuch des neuen Pets bereit.
--
-- Gespeichert wird kontoweit in ForeverHunterPetsDB.obs, je Zähmung eine Zeichenkette
-- „npc;stufe;zauberIDs;tempo;zeit;melder“ (Zauber-IDs durch Kommas, Tempo mit einer Nachkommastelle,
-- Zeit in Sekunden seit 1970). Der Melder ist ein Kürzel aus acht Hexziffern (Core/Comm.lua), bei eigenen
-- Beobachtungen das des eigenen Charakters (ForeverHunterPetsDB.myReps); Namen werden nicht gespeichert.
local _, ns = ...
local L = ns.L
local D = ns.Data

local TAME_BEAST = 1515
local WAIT = 45          -- Sekunden ab Zauberbeginn, in denen ein neues Pet als gezähmt gilt (Kanal 20 s)

-- ---- Zauber-ID → Fähigkeit und Rang ----
-- Nur, was man von Tieren lernt: Knurren und Co. hat jedes Pet vom Tierausbilder, das sagt nichts über das Tier.
local bySpell
ns.OnAbilitiesChanged(function() bySpell = nil end)
local function spellIndex()
  if not bySpell then
    bySpell = {}
    for _, a in ipairs(D.abilities) do
      if a.source == "tame" and ns.Learnable(a) then
        for _, r in ipairs(a.ranks) do bySpell[r.id] = { a = a, r = r } end
      end
    end
  end
  return bySpell
end

-- ---- Gespeicherte Beobachtungen, ausgepackt je NPC ----
-- byNpc[npc] = { { npc, level, spells = { [id] = true }, speed, time, rep, own }, … }
local byNpc, keys
local function parse(s)
  if type(s) ~= "string" then return nil end
  local npc, level, spells, speed, t, rep = s:match("^(%d+);(%d+);([%d,]*);([%d%.]*);(%d*);(%x*)$")
  if not npc then return nil end
  local o = { npc = tonumber(npc), level = tonumber(level), spells = {}, speed = tonumber(speed), time = tonumber(t), rep = rep }
  for id in spells:gmatch("%d+") do o.spells[tonumber(id)] = true end
  o.own = rep == "" or (ns.db and ns.db.myReps and ns.db.myReps[rep]) and true or false
  return o
end
ns.ParseObservation = parse

local function index()
  if byNpc then return byNpc end
  byNpc, keys = {}, {}
  for _, s in ipairs((ns.db and ns.db.obs) or {}) do
    local o = parse(s)
    if o then
      byNpc[o.npc] = byNpc[o.npc] or {}
      table.insert(byNpc[o.npc], o)
      keys[o.rep .. ":" .. o.npc .. ":" .. (o.time or 0)] = true
    end
  end
  return byNpc
end

function ns.ObservationsChanged()
  byNpc = nil
  if ns.ShowConfChanged then ns.ShowConfChanged() end
end

-- Alle Zähmungen eines Tiers (eigene und fremde), ausgepackt: { { npc, level, spells, speed, time, rep, own }, … }
function ns.ObservationsOf(npcId)
  return index()[npcId] or {}
end

function ns.ObservationCount()
  return #((ns.db and ns.db.obs) or {})
end

-- Nimmt eine fremde Beobachtung auf (vom Teilen im Spiel). Doppelte – gleicher Melder, gleiches Tier,
-- gleiche Zeit – fallen weg. Liefert true, wenn sie neu war.
function ns.AddObservation(s)
  local o = parse(s)
  if not o or o.own then return false end
  index()
  local key = o.rep .. ":" .. o.npc .. ":" .. (o.time or 0)
  if keys[key] then return false end
  ns.db.obs = ns.db.obs or {}
  table.insert(ns.db.obs, s)
  keys[key] = true
  byNpc[o.npc] = byNpc[o.npc] or {}
  table.insert(byNpc[o.npc], o)
  return true
end

-- Was eine einzelne Zähmung über einen Rang sagt: „seen“, „refuted“ oder nil. Widerlegt ist ein Rang
-- nur, wenn die Stufe beim Zähmen für ihn reichte; das Angriffstempo hängt nicht an der Stufe.
local function verdict(o, a, r)
  if not ns.Learnable(a) then
    if not (o.speed and a.speed) then return nil end
    return math.abs(o.speed - a.speed) < 0.05 and "seen" or "refuted"
  end
  if o.spells[r.id] then return "seen" end
  -- Das Zauberbuch zeigt nur den höchsten Rang. Hat das Tier einen höheren Rang derselben Fähigkeit,
  -- sagt das nichts über diesen: dieselbe Art lehrt auf niedrigerer Stufe womöglich genau ihn.
  for _, x in ipairs(a.ranks) do
    if x.rank > r.rank and o.spells[x.id] then return nil end
  end
  -- Kein oder nur ein niedrigerer Rang, obwohl die Stufe reicht: widerlegt. Die Fähigkeiten hängen an der
  -- NPC-ID, nur der Rang an der Stufe (Classic; in Forever bisher bestätigt).
  if o.level >= (r.level or 0) then return "refuted" end
  return nil
end

-- Alle Zähmungen eines Tiers zusammen. Eigene gelten als bewiesen, gesehen wie nicht gesehen, und gehen
-- allem Fremden vor (Wunsch des Nutzers, 16.10.2026). Fremde gelten erst ab 3 verschiedenen Meldern
-- (bis 17.10.2026: 10; wie FOREIGN_NEEDED in tools/build-data.mjs, #1); unter Fremden geht gesehen vor widerlegt. Widersprechen sich Zähmungen, meldet das der Generator.
local FOREIGN_NEEDED = 3
function ns.Observed(npcId, a, r)
  local list = index()[npcId]
  if not list then return nil end
  local ownSeen, ownRefuted = false, false
  local seen, refuted, nSeen, nRefuted = {}, {}, 0, 0
  for _, o in ipairs(list) do
    local v = verdict(o, a, r)
    if o.own then
      if v == "seen" then ownSeen = true elseif v == "refuted" then ownRefuted = true end
    elseif v == "seen" and not seen[o.rep] then
      seen[o.rep] = true; nSeen = nSeen + 1
    elseif v == "refuted" and not refuted[o.rep] then
      refuted[o.rep] = true; nRefuted = nRefuted + 1
    end
  end
  if ownSeen then return "seen" end
  if ownRefuted then return "refuted" end
  if nSeen >= FOREIGN_NEEDED then return "seen" end
  if nRefuted >= FOREIGN_NEEDED and nSeen == 0 then return "refuted" end
  return nil
end

-- Hat eine eigene Zähmung diesen Rang bei diesem Tier gezeigt? (Entdeckermodus)
function ns.OwnSeen(npcId, a, r)
  for _, o in ipairs(index()[npcId] or {}) do
    if o.own and verdict(o, a, r) == "seen" then return true end
  end
  return false
end

-- Belegung nach Beobachtungen: gesehen → belegt, widerlegt → ausgeblendet, sonst wie in den Daten
function ns.EffectiveConf(npcId, a, r, conf)
  local o = ns.Observed(npcId, a, r)
  if o == "seen" then return ns.CONF_SURE end
  if o == "refuted" then return ns.CONF_REFUTED end
  return conf or ns.CONF_SURE
end

-- Ränge, die Beobachtungen bei einem Tier zeigen (auch über die Daten hinaus): { { a, r }, … }
function ns.ObservedExtra(npcId)
  local list = index()[npcId]
  if not list then return nil end
  local out, have = {}, {}
  local idx = spellIndex()
  local function try(a, r)
    if not have[r] and ns.Observed(npcId, a, r) == "seen" then
      have[r] = true
      out[#out + 1] = { a = a, r = r }
    end
  end
  for _, o in ipairs(list) do
    for id in pairs(o.spells) do
      local x = idx[id]
      if x then try(x.a, x.r) end
    end
    if o.speed then
      for _, a in ipairs(D.abilities) do
        if not ns.Learnable(a) and a.speed and math.abs(o.speed - a.speed) < 0.05 then try(a, a.ranks[1]) end
      end
    end
  end
  return out
end

-- Tiere, bei denen Beobachtungen diesen Rang zeigen: { npcId, … }
function ns.ObservedTeachers(a, r)
  local out = {}
  if a.source ~= "tame" and ns.Learnable(a) then return out end
  for npc, list in pairs(index()) do
    for _, o in ipairs(list) do
      if verdict(o, a, r) == "seen" then
        if ns.Observed(npc, a, r) == "seen" then out[#out + 1] = npc end
        break
      end
    end
  end
  return out
end

-- ---- Zähmen mitverfolgen ----
local pending   -- { npc, level, started }

local function npcFromGuid(guid)
  guid = ns.clean(guid)
  if type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end
ns.NpcFromGuid = npcFromGuid

local function petSpells()
  local SB = C_SpellBook
  if not (SB and SB.HasPetSpells and SB.GetSpellBookItemInfo) then return nil end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
  local ok, n = pcall(SB.HasPetSpells)
  n = ok and tonumber(ns.clean(n)) or 0
  if n == 0 then return nil end   -- beim ersten UNIT_PET ist das Zauberbuch noch leer
  local ids = {}
  for i = 1, math.min(n, 40) do
    local ok2, info = pcall(SB.GetSpellBookItemInfo, i, bank)
    info = ok2 and ns.clean(info)
    local id = type(info) == "table" and tonumber(ns.clean(info.spellID))
    if id then ids[#ids + 1] = id end   -- Begleiterbefehle haben keine Zauber-ID
  end
  table.sort(ids)
  return ids
end

local function record()
  if not pending then return end
  if GetTime() - pending.started > WAIT then pending = nil; return end
  if not pending.stopped then return end
  local ok, exists = pcall(UnitExists, "pet")
  if not (ok and ns.clean(exists)) then return end
  local ids = petSpells()
  if not ids then return end
  local okL, level = pcall(UnitLevel, "pet")
  level = okL and tonumber(ns.clean(level)) or pending.level
  local okS, speed = pcall(UnitAttackSpeed, "pet")
  speed = okS and tonumber(ns.clean(speed))
  local p = pending
  pending = nil
  if p.map and ns.AddCells then ns.AddCells(p.npc, p.map, p.cell) end
  if p.seenMap and ns.NoteSeenIn then ns.NoteSeenIn(p.npc, p.seenMap) end
  if not (level and level > 0) then return end

  ns.db.obs = ns.db.obs or {}
  local function entry(spd)
    return ("%d;%d;%s;%s;%d;%s"):format(p.npc, level, table.concat(ids, ","), spd and ("%.1f"):format(spd) or "",
      p.time, ns.MyRep and ns.MyRep() or "")
  end
  p.time = time and time() or 0
  table.insert(ns.db.obs, entry(speed))
  -- Das Tempo ist beim ersten Lesen oft noch geheim (Zähm-Probe): kurz danach nachtragen
  if not speed then
    local slot = #ns.db.obs
    for _, d in ipairs({ 1, 3 }) do
      ns.After(d, function()
        if ns.db.obs[slot] ~= entry(nil) then return end
        local ok2, s = pcall(UnitAttackSpeed, "pet")
        s = ok2 and tonumber(ns.clean(s))
        if s and s > 0 then
          ns.db.obs[slot] = entry(s)
          ns.ObservationsChanged()
        end
      end)
    end
  end

  -- Chatzeile: was das Tier mitbrachte. Erst das Zauberbuch erheben: Ein Rang, den noch kein Pet hatte, ist
  -- sonst unbekannt (Junger Fleischreißer mit Demoralisierendem Kreischen, 16.10.2026).
  if ns.SurveyPetSpells then ns.SafeCall("survey", ns.SurveyPetSpells) end
  ns.MergeSurveyAbilities()
  local idx, parts = spellIndex(), {}
  for _, id in ipairs(ids) do
    local x = idx[id]
    if x then
      local rank = ns.RankLabel(x.a, x.r)
      parts[#parts + 1] = ns.AbilityName(x.a) .. (rank ~= "" and (" " .. rank) or "")
    end
  end
  table.sort(parts)
  ns.Print((L["Observed: %s (level %d) brought %s"]):format(ns.BeastName(p.npc),
    level, #parts > 0 and table.concat(parts, ", ") or L["no ability"]))
  ns.ObservationsChanged()
  -- teilen, wenn das Tempo nachgetragen sein kann (Core/Comm.lua)
  local slot = #ns.db.obs
  ns.After(4, function()
    if ns.ShareOwn then ns.SafeCall("share", ns.ShareOwn, ns.db.obs[slot]) end
  end)
end

ns.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if ns.clean(unit) ~= "player" or ns.clean(spellID) ~= TAME_BEAST then return end
  local okG, guid = pcall(UnitGUID, "target")
  local npc = okG and npcFromGuid(guid)
  if not npc then pending = nil; return end
  local okL, level = pcall(UnitLevel, "target")
  pending = { npc = npc, level = okL and tonumber(ns.clean(level)) or nil, started = GetTime() }
  -- Fundort beim Zauberbeginn, solange das Tier noch steht; gespeichert wird er erst, wenn das Zähmen gelingt.
  -- Immer, nicht erst aus 10 m (Core/Places.lua): „Wildtier zähmen“ reicht nur etwa 30 m, die Zelle des
  -- Spielers (60–100 m) zeigt also die Gegend des Tiers. Vorher fehlte Tieren, die man aus der Ferne zähmte,
  -- der Fundort (Junger Fleischreißer, 16.10.2026).
  pending.map, pending.cell = ns.CellHere()
  -- die Zone für seenIn (Core/Discover.lua) unabhängig von der Entfernung
  pending.seenMap = ns.CellHere and (ns.CellHere())
end)

ns.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit, _, spellID)
  if pending and ns.clean(unit) == "player" and ns.clean(spellID) == TAME_BEAST then pending.stopped = true end
end)

local function cancel(unit, _, spellID)
  if pending and ns.clean(unit) == "player" and ns.clean(spellID) == TAME_BEAST then pending = nil end
end
ns.On("UNIT_SPELLCAST_INTERRUPTED", cancel)
ns.On("UNIT_SPELLCAST_FAILED", cancel)

ns.On("UNIT_PET", function(unit)
  if not pending or ns.clean(unit) ~= "player" then return end
  ns.SafeCall("observe", record)
  -- falls das Zauberbuch noch fehlt: kurz danach noch einmal
  ns.After(1, function() ns.SafeCall("observe", record) end)
end)
ns.On("SPELLS_CHANGED", function()
  if pending then ns.SafeCall("observe", record) end
end)
