-- Forever Hunter Pets · Sichtung: Tiere erfassen, ohne sie zu zähmen (Umbau eigene Daten, Inkrement 4).
-- Ein Tier mit Familie im Ziel, unter der Maus oder mit Namensplakette liefert NPC-ID, Name in
-- Client-Sprache, Stufe, Einstufung, Familie und Angriffstempo. Nur außerhalb von Kampf und Instanz, alles durch
-- ns.clean().
-- Vorrang haben wenig Traffic, wenig Speicher und wenig Rechenzeit (Wunsch des Nutzers, 16.10.2026).
--
-- Gespeichert wird kontoweit in ForeverHunterPetsDB.sights, je Sichtung eine Zeichenkette
-- „npc;stufe;einstufung;familie;sprache;name;zeit;melder;tempo“ (Einstufung 0 normal, 1 Elite, 2 Rar-Elite,
-- 3 Boss, 4 Rar wie in den Daten; Sprache wie GetLocale(); Tempo in Sekunden mit einer Nachkommastelle, fehlt
-- bei Sichtungen vor dem 16.10.2026). Je Tier, Stufe, Sprache und Melder eine. Das Tempo des wilden Tiers ist
-- das, das es gezähmt hat (UnitAttackSpeed, im Spiel geprüft am 16.10.2026).
-- Eigene tragen das eigene Kürzel (Core/Comm.lua), fremde kommen über das Teilen dazu.
--
-- Reichweite: Die Fährte zählt aus jeder Entfernung (E7: Maus, Plakette, „Augen des Wildtiers“ und „Adlerauge“ reichen
-- weit), die Stammdaten nur, wenn das Tier in etwa 28 m steht (CheckInteractDistance 4), der Fundort nur aus
-- etwa 10 m (Core/Places.lua). Ziel und Maus bleiben 10 s beobachtet, Plaketten, bis sie
-- verschwinden – wer auf ein Tier zuläuft, liefert es. CheckInteractDistance meldet bei feindlichen
-- Tieren außerhalb des Kampfs true/false (im Spiel geprüft am 16.10.2026).
local _, ns = ...
local D = ns.Data

local WATCH = 10            -- Sekunden, die ein angevisiertes Tier beobachtet bleibt
local MAX_STORED = 10000      -- fremde Sichtungen; Speicher geht vor
local CLS = { normal = 0, trivial = 0, minus = 0, elite = 1, rareelite = 2, worldboss = 3, rare = 4 }
ns.LOCALES = { deDE = true, enUS = true, enGB = true, frFR = true, esES = true, esMX = true, ptBR = true,
  itIT = true, ruRU = true, koKR = true, zhCN = true, zhTW = true }

-- ---- Ablage ----
function ns.ParseSighting(s)
  if type(s) ~= "string" then return nil end
  -- Felder, die eine neuere Version hinten anhängt, bleiben unbeachtet (Protokollregel in Core/Comm.lua)
  local npc, level, cls, fam, lang, name, t, rep, speed, rest =
    s:match("^(%d+);(%d+);(%d);(%d+);(%a%a%u%u);([^;|]+);(%d+);(%x*);?([%d%.]*)(.*)$")
  if not npc or (rest ~= "" and rest:sub(1, 1) ~= ";") then return nil end
  local o = { npc = tonumber(npc), level = tonumber(level), cls = tonumber(cls), fam = tonumber(fam), lang = lang,
    name = name, time = tonumber(t), rep = rep, speed = tonumber(speed) }
  o.own = rep == "" or (ns.db and ns.db.myReps and ns.db.myReps[rep]) and true or false
  return o
end

-- byNpc[npc] = { names = { [Sprache] = Name }, min, max, fam, cls, speed, reps = { [Kürzel] = true }, own }
-- keys[Schlüssel] = Stelle in ForeverHunterPetsDB.sights
local byNpc, keys
local function key(o) return o.npc .. ":" .. o.level .. ":" .. o.lang .. ":" .. o.rep end

local function add(o, i)
  local b = byNpc[o.npc]
  if not b then
    b = { names = {}, reps = {}, min = o.level, max = o.level, fam = o.fam, cls = o.cls }
    byNpc[o.npc] = b
  end
  -- der eigene Name geht vor, sonst bleibt der erste
  if o.own or not b.names[o.lang] then b.names[o.lang] = o.name end
  if o.own then b.own = true; b.fam, b.cls = o.fam, o.cls end
  if o.speed and (o.own or not b.speed) then b.speed = o.speed end
  b.min, b.max = math.min(b.min, o.level), math.max(b.max, o.level)
  b.reps[o.rep] = true
  keys[key(o)] = i
end

local function index()
  if byNpc then return byNpc end
  byNpc, keys = {}, {}
  for i, s in ipairs((ns.db and ns.db.sights) or {}) do
    local o = ns.ParseSighting(s)
    if o then add(o, i) end
  end
  return byNpc
end

function ns.SightingsChanged() byNpc = nil end
function ns.SightingCount() return #((ns.db and ns.db.sights) or {}) end
function ns.SeenBeast(npc) return index()[npc] end

-- Name eines gesichteten Tiers in der Client-Sprache, sonst nil
function ns.SeenName(npc)
  local b = index()[npc]
  if not b then return nil end
  return b.names[GetLocale and GetLocale() or "enUS"]
end

-- Hat die gespeicherte Sichtung an Stelle i schon ein Tempo? (neun Felder statt acht)
local function hasSpeed(i)
  local s = ns.db and ns.db.sights and ns.db.sights[i]
  return type(s) == "string" and select(2, s:gsub(";", ";")) >= 8
end

-- Nimmt eine Sichtung auf, eigene wie fremde. Liefert true, wenn sie neu war oder eine ältere ohne Tempo
-- ergänzt hat (die wird ersetzt, nicht doppelt gespeichert).
function ns.AddSighting(s)
  local o = ns.ParseSighting(s)
  if not o then return false end
  index()
  local at = keys[key(o)]
  if at then
    if not (o.speed and not hasSpeed(at)) then return false end
    ns.db.sights[at] = s
    add(o, at)
    return true
  end
  if not o.own and ns.SightingCount() >= MAX_STORED then return false end
  ns.db.sights = ns.db.sights or {}
  table.insert(ns.db.sights, s)
  add(o, #ns.db.sights)
  return true
end

-- Kennen die mitgelieferten Daten das schon (Name in dieser Sprache, Stufe im Bereich)? Dann nicht teilen.
-- Ein abweichendes Tempo zählt nur als bekannt, wenn die Daten das Tier als Lehrtier eines Tempos führen.
local LANG_FIELD = { deDE = "de", enUS = "en", enGB = "en" }
local NORMAL_SPEED = 2.0
local traitBeasts
local function speedKnown(o)
  if not o.speed or math.abs(o.speed - NORMAL_SPEED) < 0.05 then return true end
  if not traitBeasts then
    traitBeasts = {}
    for _, a in ipairs(D.abilities) do
      if a.kind == "trait" then
        for _, t in ipairs(a.teach) do traitBeasts[t[1]] = true end
      end
    end
  end
  return traitBeasts[o.npc] or false
end
local function known(o)
  local b = D.beasts[o.npc]
  if not b then return false end
  local field = LANG_FIELD[o.lang]
  if not (field and b[field]) then return false end
  return b.min ~= nil and o.level >= b.min and o.level <= (b.max or b.min) and speedKnown(o)
end

-- ---- Teilen: gesammelt, sparsam ----
-- Der verborgene Kanal soll nicht volllaufen. Geteilt wird nur, was nötig ist: nicht, was die Daten
-- kennen; nicht, wenn schon FOREIGN_ENOUGH Melder das Tier gemeldet haben (mehr braucht die Regel
-- „ab 3 Meldern“ in Core/Observe.lua nicht); je Tier einmal je Sitzung, außer die Stufe liegt außerhalb des Bekannten.
-- Gesammelt wird höchstens alle SHARE_EVERY Sekunden verschickt, je Runde höchstens SHARE_MAX.
local SHARE_EVERY, SHARE_MAX, SHARE_QUEUE, FOREIGN_ENOUGH = 300, 20, 200, 3
local shareQueue, shareTimer, shared = {}, false, {}   -- shared[npc] = { min, max } dieser Sitzung

local function repCount(npc)
  local b = index()[npc]
  local n = 0
  for _ in pairs(b and b.reps or {}) do n = n + 1 end
  return n
end

local function flushShares()
  shareTimer = false
  local n = 0
  while #shareQueue > 0 and n < SHARE_MAX do
    local s = table.remove(shareQueue, 1)
    if ns.ShareSighting then ns.SafeCall("share", ns.ShareSighting, s) end
    n = n + 1
  end
  if #shareQueue > 0 then
    shareTimer = true
    ns.After(SHARE_EVERY, function() ns.SafeCall("share", flushShares) end)
  end
end

local function queueShare(s, o)
  if known(o) or repCount(o.npc) >= FOREIGN_ENOUGH then return end
  local r = shared[o.npc]
  if r and o.level >= r[1] and o.level <= r[2] then return end
  shared[o.npc] = r and { math.min(r[1], o.level), math.max(r[2], o.level) } or { o.level, o.level }
  if #shareQueue >= SHARE_QUEUE then table.remove(shareQueue, 1) end
  shareQueue[#shareQueue + 1] = s
  if not shareTimer then
    shareTimer = true
    ns.After(SHARE_EVERY, function() ns.SafeCall("share", flushShares) end)
  end
end

-- ---- Erfassen ----
-- Quellen: Ziel, Maus über einem Tier und Namensplaketten (Plaketten für Gegner müssen an sein). Ein
-- Beobachter für alle, geführt nach GUID: Ein Tier, das zugleich Ziel und Plakette ist, wird einmal
-- geprüft. Höchstens MAX_TRACKED gleichzeitig, ein Durchlauf je TICK Sekunden, nur solange etwas
-- beobachtet wird; in Kampf und Instanz ruht er.
local TICK, MAX_TRACKED = 1, 20
local tracked, count, ticking = {}, 0, false   -- tracked[guid] = { unit, npc, fam, untilT?, noted, sighted, cell }

local function quiet()
  if InCombatLockdown and ns.clean(InCombatLockdown()) then return true end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    if ok and ns.clean(inside) then return true end
  end
  return false
end

-- true/false, oder nil, wenn der Client es nicht sagt
local function near(unit, index)
  if not CheckInteractDistance then return nil end
  local ok, v = pcall(CheckInteractDistance, unit, index)
  if not ok then return nil end
  v = ns.clean(v)
  if v == nil then return nil end
  return v and true or false
end

-- Stammdaten einer Sichtung speichern und zum Teilen vormerken. Schon bekannte Sichtungen (gleiches
-- Tier, gleiche Stufe, Sprache und Melder) werden erkannt, bevor die Zeichenkette entsteht.
local function record(unit, npc, fam)
  local okL, level = pcall(UnitLevel, unit)
  level = okL and tonumber(ns.clean(level))
  if not (level and level > 0) then return end   -- „??“
  local rep = ns.MyRep and ns.MyRep()
  if not rep then return end
  local lang = GetLocale and GetLocale() or "enUS"
  index()
  local at = keys[npc .. ":" .. level .. ":" .. lang .. ":" .. rep]
  if at and hasSpeed(at) then return end
  -- Angriffstempo des wilden Tiers; beim ersten Lesen kann es wie beim Pet geheim sein, dann ohne
  local okS, speed = pcall(UnitAttackSpeed, unit)
  speed = okS and tonumber(ns.clean(speed))
  if not (speed and speed >= 0.5 and speed <= 5) then speed = nil end
  if at and not speed then return end
  local okN, name = pcall(UnitName, unit)
  name = okN and ns.clean(name)
  if type(name) ~= "string" or name == "" or name:find("[;|]") or #name > 60 then return end
  local okK, cls = pcall(UnitClassification, unit)
  cls = CLS[okK and ns.clean(cls) or "normal"] or 0
  local s = ("%d;%d;%d;%d;%s;%s;%d;%s"):format(npc, level, cls, fam, lang, name, time and time() or 0, rep)
    .. (speed and (";%.1f"):format(speed) or "")
  if ns.AddSighting(s) then queueShare(s, ns.ParseSighting(s)) end
end

-- Ist die Einheit ein Tier, das uns angeht? NPC-ID und Familie, sonst nil. Billige Prüfungen zuerst.
local function beast(unit)
  local okP, isPlayer = pcall(UnitIsPlayer, unit)
  if not okP or ns.clean(isPlayer) ~= false then return nil end
  local okF, famName, fam = pcall(UnitCreatureFamily, unit)
  fam = okF and tonumber(ns.clean(fam))
  if not fam then return nil end
  local okC, controlled = pcall(UnitPlayerControlled, unit)
  if not okC or ns.clean(controlled) ~= false then return nil end   -- Pets, gezähmte Tiere
  local okG, guid = pcall(UnitGUID, unit)
  guid = okG and ns.clean(guid)
  local npc = guid and ns.NpcFromGuid(guid)
  if not npc then return nil end
  return guid, npc, fam, ns.clean(famName)
end

-- Ein Durchlauf für ein Tier: Fährte aus jeder Entfernung, Stammdaten aus etwa 28 m, Fundort-Zelle aus
-- etwa 10 m (Core/Places.lua), je Zelle einmal. here = { map, cell } des Spielers, einmal je Durchlauf.
local function visit(t, here)
  if not t.noted and here.map then
    -- Fährte in dieser Zone (Core/Discover.lua): die Karte, auf der man steht. Zählt nur, wo das Tier
    -- einen echten Fundort hat – über eine Zonengrenze hinweg gesehen, schadet sie also nicht.
    t.noted = true
    if ns.NoteTrack then ns.NoteTrack(t.npc, here.map) end
    -- von weitem nur Name und Familie, lokal (Core/Discover.lua); die Sichtung ab 28 m ersetzt sie
    local okN, name = pcall(UnitName, t.unit)
    if okN then ns.NoteTrackName(t.npc, t.fam, ns.clean(name)) end
  end
  if near(t.unit, 4) == false then return end
  if not t.sighted then
    t.sighted = true
    record(t.unit, t.npc, t.fam)
    ns.NoteTrackName(t.npc, t.fam, nil)   -- jetzt gibt es die Sichtung: den Fernnamen nicht mehr führen
  end
  -- während „Augen des Wildtiers“ oder „Adlerauge“ steht der Spieler woanders als das, was er sieht: keine Zelle
  if here.map and t.cell ~= here.key and ns.UnitClose and ns.UnitClose(t.unit) and not ns.Possessing() then
    t.cell = here.key
    ns.AddCells(t.npc, here.map, here.cell)
  end
end

local tick
local function schedule()
  if ticking or count == 0 then return end
  ticking = true
  ns.After(TICK, function() ns.SafeCall("sight", tick) end)
end

tick = function()
  ticking = false
  if count == 0 then return end
  if not quiet() then
    local here = {}
    if ns.CellHere then
      here.map, here.cell = ns.CellHere()
      if here.map then here.key = here.map .. here.cell end
    end
    local now = GetTime()
    for guid, t in pairs(tracked) do
      local ok, g = pcall(UnitGUID, t.unit)
      -- Plaketten-Einheiten werden neu vergeben, Ziel und Maus wechseln: dann nicht mehr dieses Tier
      if not ok or ns.clean(g) ~= guid or (t.untilT and now > t.untilT) then
        tracked[guid] = nil
        count = count - 1
      else
        visit(t, here)
      end
    end
  end
  schedule()
end

-- Ein Tier in die Beobachtung nehmen. untilT: Ziel und Maus nur WATCH Sekunden, Plaketten bis sie gehen.
local function track(unit, timed)
  if quiet() then return end
  local guid, npc, fam, famName = beast(unit)
  if not guid then return end
  local t = tracked[guid]
  if t then
    -- Die Plakette geht vor: Sie bleibt, solange das Tier sichtbar ist. Ziel und Maus verlängern nur
    -- ihre eigene Frist.
    if not timed then
      t.unit, t.untilT = unit, nil
    elseif t.untilT then
      t.unit, t.untilT = unit, math.max(t.untilT, GetTime() + WATCH)
    end
  else
    if count >= MAX_TRACKED then return end
    -- den Familiennamen führt die Erhebung (Core/Survey.lua), auch für Familien ohne eigenes Pet
    if ns.SurveyFamily then ns.SurveyFamily(fam, famName) end
    t = { unit = unit, npc = npc, fam = fam, untilT = timed and (GetTime() + WATCH) or nil }
    tracked[guid] = t
    count = count + 1
  end
  -- sofort ein erster Blick, damit ein nahes Tier nicht eine Sekunde warten muss
  local here = {}
  if ns.CellHere then
    here.map, here.cell = ns.CellHere()
    if here.map then here.key = here.map .. here.cell end
  end
  visit(t, here)
  schedule()
end

local function untrack(unit)
  for guid, t in pairs(tracked) do
    if t.unit == unit and not t.untilT then
      tracked[guid] = nil
      count = count - 1
    end
  end
end

-- Die Proben (Entfernung, Inkrement 4; Angriffstempo, 16.10.2026) haben ihre Fragen beantwortet
ns.On("ADDON_LOADED", function() if ns.db then ns.db.sightProbe, ns.db.speedProbe = nil, nil end end)

ns.On("PLAYER_TARGET_CHANGED", function() ns.SafeCall("sight", track, "target", true) end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() ns.SafeCall("sight", track, "mouseover", true) end)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit)
  unit = ns.clean(unit)
  if type(unit) == "string" then ns.SafeCall("sight", track, unit, false) end
end)
ns.On("NAME_PLATE_UNIT_REMOVED", function(unit)
  unit = ns.clean(unit)
  if type(unit) == "string" then untrack(unit) end
end)
