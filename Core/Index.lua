-- Forever Hunter Pets · Zugriff auf die Daten: Namen in Client-Sprache, Tiere je Rang, Aufwand, Fundorte
local _, ns = ...
local L = ns.L
local D = ns.Data

-- Deutsch im deutschen Client, sonst Englisch
local LANG = (GetLocale and GetLocale() == "deDE") and "de" or "en"
ns.lang = LANG

-- Kommen Fähigkeiten aus der eigenen Erhebung dazu (ns.MergeSurveyAbilities), leert jeder seinen Zwischenspeicher
local abilityListeners = {}
function ns.OnAbilitiesChanged(fn) abilityListeners[#abilityListeners + 1] = fn end
function ns.Name(o)
  if not o then return "?" end
  return o[LANG] or o.de or o.en or "?"
end
-- Name nur in Client-Sprache, sonst nil – damit ein Name vom Client vor der anderen Sprache der Daten gehen kann (#3)
local function ownName(o) return o and o[LANG] end

-- ---- Fähigkeiten: Name und Icon nennt der Client, die Daten sind nur Reserve ----
-- Nur echte Zauber: Tempo-Einträge tragen eine negative Ersatz-ID (tools/build-data.mjs)
local function spellInfo(id)
  if not (id and id > 0 and C_Spell and C_Spell.GetSpellInfo) then return nil end
  local ok, info = pcall(C_Spell.GetSpellInfo, id)
  info = ok and ns.clean(info)
  return type(info) == "table" and info or nil
end

-- Icon des Addons: das von Wildtierkunde (1462), vom Client erfragt; der Pfad ist die Reserve
-- und steht so auch in der TOC (## IconTexture)
ns.BEAST_LORE = 1462
function ns.AddonIcon()
  local info = spellInfo(ns.BEAST_LORE)
  return (info and ns.clean(info.iconID)) or "Interface\\Icons\\Ability_Physical_Taunt"
end

-- Ausschnitt des Icons mit Rand `inset`: Die Zähne stehen in der Grafik etwas links der Mitte,
-- deshalb rückt der Ausschnitt um ICON_SHIFT nach links und das Motiv damit in die Mitte
local ICON_SHIFT = 0.02
function ns.AddonIconCoords(inset)
  return inset - ICON_SHIFT, 1 - inset - ICON_SHIFT, inset, 1 - inset
end

function ns.AbilityName(a)
  local info = spellInfo(a.ranks[1] and a.ranks[1].id)
  local name = info and ns.clean(info.name)
  if type(name) == "string" and name ~= "" then return name end
  return ns.Name(a)
end

function ns.AbilityIcon(a)
  local info = spellInfo(a.ranks[1] and a.ranks[1].id)
  local icon = info and ns.clean(info.iconID)
  if icon then return icon end
  -- erhobene Icons sind Datei-IDs, ältere Angaben Dateinamen
  if type(a.icon) == "number" then return a.icon end
  return "Interface\\Icons\\" .. (a.icon or "INV_Misc_QuestionMark")
end

-- Beschreibung eines Rangs: nur vom Client. Fehlt sie noch, wird sie angefordert und es steht „…“;
-- SPELL_TEXT_UPDATE meldet, wenn sie da ist, und die Ansichten zeichnen neu.
function ns.Description(r)
  if not (r.id and r.id > 0) then return "" end   -- Tempo-Eintrag: kein Zauber, der Hinweis erklärt ihn
  if C_Spell and C_Spell.GetSpellDescription then
    local ok, text = pcall(C_Spell.GetSpellDescription, r.id)
    text = ok and ns.clean(text)
    if type(text) == "string" and text ~= "" then return text end
    if C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, r.id) end
  end
  return "…"
end

-- Tempo eines Tempo-Zaubers in Sekunden aus seiner Beschreibung (#189), nie aus einem gemessenen Tempo: „Erhöht das
-- Angriffstempo um 25%.“ → 2,0 s ÷ 1,25 = 1,6 s (passt zu allen bekannten: +15 % 1,7 s, +33 % 1,5 s, +50 % 1,3 s).
-- faster: ob der Zauber schneller macht (die Richtung steht nur in Worten da, sie kommt aus den Zähmungen);
-- langsamer angenommen als 2,0 s ÷ (1 − p). nil, wenn die Beschreibung fehlt oder keine Prozentzahl nennt.
local NORMAL_SPEED = 2.0
function ns.TraitSpeed(id, faster)
  if not (C_Spell and C_Spell.GetSpellDescription) then return nil end
  local ok, text = pcall(C_Spell.GetSpellDescription, id)
  text = ok and ns.clean(text)
  local p = type(text) == "string" and tonumber(text:match("(%d+)[%s\194\160]*%%"))   -- auch „25 %“ mit Leerzeichen
  if not (p and p > 0 and p < 100) then return nil end
  local speed = faster and NORMAL_SPEED / (1 + p / 100) or NORMAL_SPEED / (1 - p / 100)
  return math.floor(speed * 10 + 0.5) / 10
end

-- Angriffstempo ist keine erlernbare Fähigkeit, sondern eine Eigenschaft des gezähmten Tiers
function ns.Learnable(a) return a.kind ~= "trait" end
function ns.AppliesToAll(a) return a.kind ~= "family" end

-- „?“ hinter einem Rang, der nur aus unsicheren fremden Zähmungen stammt (#136)
function ns.RankLabel(a, r)
  if a.kind == "trait" then return (L["Speed %s s"]):format(ns.Decimal(a.speed)) .. ns.ConfMark(r and r.conf) end
  if r.rank and r.rank > 0 then return (L["Rank %d"]):format(r.rank) .. ns.ConfMark(r.conf) end
  return ""
end

-- Wird der Rang gezeigt? Unsichere fremde Ränge nur mit „Unsichere Angaben zeigen“ (#136)
function ns.RankShown(r) return ns.ShowConf(r.conf) end

-- 1.3 → „1,3“ im deutschen Client
function ns.Decimal(n, digits)
  local s = string.format("%." .. (digits or 1) .. "f", n or 0)
  if LANG == "de" then s = s:gsub("%.", ",") end
  return s
end

-- ---- Familien und Zonen ----
-- Icon einer Familie: aus den Daten, sonst aus der eigenen Erhebung, sonst das von „Wildtier zähmen“.
-- Datei-ID (Zahl) oder Dateiname bzw. Pfad.
local FAMILY_ICON_FALLBACK = "Interface\\Icons\\Ability_Hunter_BeastTaming"

function ns.FamilyIcon(id)
  local f = id and D.families[id]
  local icon = (f and f.icon) or (id and ns.db and ns.db.survey and ns.db.survey.familyIcons and ns.db.survey.familyIcons[id])
  if type(icon) == "number" then return icon end
  if type(icon) == "string" and icon ~= "" then
    return icon:find("\\", 1, true) and icon or ("Interface\\Icons\\" .. icon)
  end
  return FAMILY_ICON_FALLBACK, true
end

-- Name einer Familie in Client-Sprache: aus den Daten, sonst vom eigenen Client (Erhebung, Pet, Anvisieren),
-- erst dann aus den Daten in der anderen Sprache (#3)
function ns.FamilyName(id)
  local f = id and D.families[id]
  local own = id and ns.db and ns.db.survey and ns.db.survey.families and ns.db.survey.families[id]
  return ownName(f) or own or (f and ns.Name(f)) or "?"
end

-- Alle bekannten Familien-IDs: aus den Daten und aus der eigenen Erhebung { [id] = true }
function ns.FamilyIds()
  local out = {}
  for id in pairs(D.families) do out[id] = true end
  for id in pairs((ns.db and ns.db.survey and ns.db.survey.families) or {}) do out[id] = true end
  return out
end

-- Zonen sind uiMapIDs (die Karte, auf der ein Fundort erfasst wurde); den Namen nennt der Client
function ns.ZoneName(id)
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, id)
    info = ok and ns.clean(info)
    local name = type(info) == "table" and ns.clean(info.name)
    if type(name) == "string" and name ~= "" then return name end
  end
  return (L["Map %d"]):format(id)
end

-- Familie des aktiven Pets: ID wie in den Daten und Name, oder nil ohne Pet.
-- UnitCreatureFamily liefert Name und ID („Eber“, 5); die ID ist die Familien-ID der Daten.
function ns.PetFamily()
  if not (UnitExists and UnitCreatureFamily) then return nil end
  local ok, exists = pcall(UnitExists, "pet")
  if not (ok and ns.clean(exists)) then return nil end
  local ok2, name, id = pcall(UnitCreatureFamily, "pet")
  if not ok2 then return nil end
  name, id = ns.clean(name), ns.clean(id)
  if type(id) == "number" then return id, (ns.FamilyName(id) ~= "?" and ns.FamilyName(id)) or name end
  -- Reserve, falls der Client keine ID liefert: über den Namen suchen
  for fid, f in pairs(D.families) do
    if name and (f.de == name or f.en == name) then return fid, ns.Name(f) end
  end
  return nil
end

-- Name in Client-Sprache, wo es einen gibt (#3): aus einer eigenen Sichtung (Core/Sightings.lua), aus den Daten,
-- aus einer Fährte (nur von weitem gesehen, Core/Discover.lua), aus einer fremden Sichtung; dann aus den Daten in
-- der anderen Sprache; sonst „Unbekanntes Tier (#ID)“ – dann kennt ihn noch niemand, und Anvisieren liefert ihn.
-- Die fremde Sichtung steht hinter den Daten, damit ein einzelner Melder keinen bekannten Namen ersetzt (#47); ist
-- sie unsicher (#136), steht „?“ dahinter.
function ns.BeastName(id)
  local seen, own, conf
  if ns.SeenName then seen, own, conf = ns.SeenName(id) end
  if seen and own then return seen end
  local b = D.beasts[id]
  if ownName(b) then return ownName(b) end
  local far = ns.TrackName and ns.TrackName(id)
  if far then return far end
  if seen then return seen .. ns.ConfMark(conf) end
  if b and (b.de or b.en) then return ns.Name(b) end
  return (L["Unknown beast (#%d)"]):format(id)
end

-- Stammdaten eines Tiers: aus den Daten, sonst aus der Sichtung oder Zähmung (eigene sofort, fremde ab der Schwelle, #103). Ein Tier, das man erst
-- selbst gesichtet oder gezähmt hat, steht bis zum nächsten Import nicht in den Daten – es zählt trotzdem.
function ns.BeastInfo(id)
  local b = D.beasts[id]
  if b then return b end
  -- conf: Belegung der Angaben, wenn sie von anderen Spielern stammen (#136); ns.LevelText setzt dann „?“
  local seen = ns.TrustedSighting and ns.TrustedSighting(id)   -- eigene sofort, fremde ab der Schwelle (#103)
  if seen then return { fam = seen.fam, min = seen.min, max = seen.max, cls = seen.cls or 0, conf = seen.conf } end
  -- Stufe aus Zähmungen: aus eigenen sofort, aus fremden nach der Schwelle (#103, #136)
  local own, foreign, reps, n = {}, {}, {}, 0
  for _, o in ipairs(ns.ObservationsOf and ns.ObservationsOf(id) or {}) do
    if o.level and o.own then
      own[#own + 1] = o.level
    elseif o.level then
      foreign[#foreign + 1] = o.level
      if not reps[o.rep] then reps[o.rep] = true; n = n + 1 end
    end
  end
  local levels, conf = own, ns.CONF_SURE
  if #own == 0 then
    conf = ns.ForeignConf and ns.ForeignConf(reps, n)
    levels = ns.ForeignShown and ns.ForeignShown(conf) and foreign or {}
  end
  if #levels > 0 then
    local lo, hi = levels[1], levels[1]
    for _, lv in ipairs(levels) do lo, hi = math.min(lo, lv), math.max(hi, lv) end
    return { min = lo, max = hi, cls = 0, conf = conf }
  end
  local fam
  if ns.TrackName then fam = select(2, ns.TrackName(id)) end   -- nicht „and“: das schnitte die Familie ab
  if fam then return { fam = fam, cls = 0 } end
  return nil
end

-- Familie eines Tiers: aus den Daten, sonst aus der eigenen Sichtung (fremde ab der Schwelle, #103). Ein Tier, das man nur selbst gezähmt hat,
-- steht in den Daten ohne Familie, bis die Sichtung importiert ist – angezeigt wird sie trotzdem.
-- Zweiter Wert: die Belegung, wenn die Familie aus fremden Sichtungen stammt (#136).
function ns.BeastFamily(id)
  local b = D.beasts[id]
  if b and b.fam then return b.fam end
  local seen = ns.TrustedSighting and ns.TrustedSighting(id)
  if seen and seen.fam then return seen.fam, seen.conf end
  local fam
  if ns.TrackName then fam = select(2, ns.TrackName(id)) end   -- nicht „and“: das schnitte die Familie ab
  return fam
end

-- Name der Familie eines Tiers zum Anzeigen, mit „?“, wenn sie unsicher ist (#136)
function ns.BeastFamilyText(id)
  local fam, conf = ns.BeastFamily(id)
  return ns.FamilyName(fam) .. ns.ConfMark(conf)
end

-- Stufe zum Anzeigen; „?“ dahinter, wenn sie aus unsicheren fremden Angaben stammt (#136)
function ns.LevelText(b)
  if not b.min then return "?" end
  local mark = ns.ConfMark(b.conf)
  if not b.max or b.max == b.min then return tostring(b.min) .. mark end
  return b.min .. "-" .. b.max .. mark
end

-- Einstufung: 1 Elite, 2 Rar-Elite, 3 Boss, 4 Rar
function ns.IsRare(b) return b.cls == 2 or b.cls == 4 end

-- ---- Fundorte: in den Daten sechs Ziffern je Punkt, hier { {x, y}, … } in Prozent ----
-- Dazu die im Spiel gesammelten Zellen (Core/Places.lua), als Mittelpunkt der Zelle.
local unpacked = {}
local function dataCoords(npcId, zoneId)
  local key = npcId .. ":" .. zoneId
  if unpacked[key] then return unpacked[key] end
  local packed = D.coords[npcId] and D.coords[npcId][zoneId]
  local pts = {}
  if packed then
    for i = 1, #packed - 5, 6 do
      pts[#pts + 1] = { tonumber(packed:sub(i, i + 2)) / 10, tonumber(packed:sub(i + 3, i + 5)) / 10 }
    end
  end
  unpacked[key] = pts
  return pts
end

-- Studiert in dieser Zone (Status „known“)? Dann zeigt der Entdeckermodus dort alle bekannten Fundorte (#170).
local function studiedIn(npcId, zoneId)
  return ns.BeastStatus ~= nil and ns.BeastStatus(npcId, zoneId) == "known"
end

-- Im Entdeckermodus nur die eigenen Zellen – keine mitgelieferten, keine fremden Fundorte –, bis das Tier in dieser
-- Zone studiert ist; dann alle bekannten wie im Komplettmodus (#170). Die Karte unterscheidet nicht, woher ein
-- Fundort stammt (Maintainer, 13.11.2026).
function ns.Coords(npcId, zoneId)
  if ns.Discovering and ns.Discovering() and not studiedIn(npcId, zoneId) then
    return ns.CellPoints and ns.CellPoints(npcId, zoneId, true) or {}
  end
  local cells = ns.CellPoints and ns.CellPoints(npcId, zoneId) or {}
  if #cells == 0 then return dataCoords(npcId, zoneId) end
  local pts = {}
  for _, p in ipairs(dataCoords(npcId, zoneId)) do pts[#pts + 1] = p end
  for _, p in ipairs(cells) do pts[#pts + 1] = p end
  return pts
end

-- Zonen eines Tiers mit der Zahl der Fundorte, aus Daten und Zellen: { [Zone] = Zahl }. Im Entdeckermodus nur
-- eigene Zellen, in Zonen, in denen das Tier studiert ist, alle (#170, wie ns.Coords); full = true immer alles (für
-- die Zählung „X von Y“ in Core/Discover.lua und für ns.BeastStatus, das deshalb nicht hierher zurückruft).
function ns.ZoneCounts(npcId, full)
  local out = {}
  if not full and ns.Discovering and ns.Discovering() then
    for z, n in pairs(ns.CellMaps and ns.CellMaps(npcId, true) or {}) do out[z] = n end
    for z, n in pairs(ns.ZoneCounts(npcId, true)) do
      if studiedIn(npcId, z) then out[z] = n end
    end
    return out
  end
  for z, packed in pairs(D.coords[npcId] or {}) do out[z] = #packed / 6 end
  for z, n in pairs(ns.CellMaps and ns.CellMaps(npcId) or {}) do out[z] = (out[z] or 0) + n end
  return out
end

-- Zonen eines Tiers: aus den Daten, dazu die, in denen Zellen liegen oder in denen man es selbst gezähmt hat
-- (ns.TamedZones, Core/Discover.lua). Im Entdeckermodus nur eigene Zellen und Zähmungen.
function ns.BeastZones(npcId)
  if ns.Discovering and ns.Discovering() then
    local set = {}
    for z in pairs(ns.CellMaps and ns.CellMaps(npcId, true) or {}) do set[z] = true end
    for z in pairs(ns.TamedZones and ns.TamedZones(npcId) or {}) do set[z] = true end
    local out = {}
    for z in pairs(set) do out[#out + 1] = z end
    table.sort(out)
    return out
  end
  local b = D.beasts[npcId]
  local cells = {}
  for z in pairs(ns.CellMaps and ns.CellMaps(npcId) or {}) do cells[z] = true end
  for z in pairs(ns.TamedZones and ns.TamedZones(npcId) or {}) do cells[z] = true end
  if not next(cells) then return (b and b.zones) or {} end
  local out, have = {}, {}
  for _, z in ipairs((b and b.zones) or {}) do out[#out + 1] = z; have[z] = true end
  local extra = {}
  for z in pairs(cells) do if not have[z] then extra[#extra + 1] = z end end
  table.sort(extra)
  for _, z in ipairs(extra) do out[#out + 1] = z end
  return out
end

local function pointCount(npcId)
  local n = 0
  for _, c in pairs(ns.ZoneCounts(npcId)) do n = n + c end
  return n
end

-- ---- Aufwand beim Zähmen (Faustregel wie auf der Seite, niedriger = leichter) ----
-- uiMapIDs: Dun Morogh, Wald von Elwynn, Teldrassil, Westfall, Loch Modan, Dunkelküste, Rotkammgebirge,
-- Dämmerwald, Sumpfland | Durotar, Mulgore, Tirisfal, Brachland, Silberwald
local FACTION_ZONES = {
  Alliance = { [1426] = true, [1429] = true, [1438] = true, [1436] = true, [1432] = true, [1439] = true, [1433] = true, [1431] = true, [1437] = true },
  Horde = { [1411] = true, [1412] = true, [1420] = true, [1413] = true, [1421] = true },
}
local CLS_EFFORT = {
  [1] = { 3, "Elite" },
  [2] = { 5, "Rare elite (rare and strong)" },
  [3] = { 6, "Boss" },
  [4] = { 3, "Rare (long respawn)" },
}

local function enemyZones()
  local ok, faction = pcall(UnitFactionGroup, "player")
  faction = ok and ns.clean(faction)
  if faction == "Alliance" then return FACTION_ZONES.Horde end
  if faction == "Horde" then return FACTION_ZONES.Alliance end
  return nil
end

-- ---- Belegung der Lehrtiere: 1 belegt, 2 unsicher, 3 unbelegt (drittes Feld in a.teach) ----
-- belegt: im Spiel gesehen, bei einer eigenen Zähmung oder von mindestens 3 anderen Charakteren gemeldet;
-- unsicher: bisher von weniger als 3 anderen Charakteren gemeldet; unbelegt: nur geschätzt, noch nicht gesehen
-- (siehe Plan „Lehrtiere schätzen“, bisher gibt es keine).
-- Was nicht belegt ist, zeigt das Addon nur auf Wunsch (Einstellungen) und dann mit „?“ bzw. „!“.
-- Widerlegt (4): Eine Zähmung zeigte den Rang nicht, obwohl die Stufe reichte. Die Fähigkeiten hängen an
-- der NPC-ID, das Paar stimmt also nicht – es wird nie gezeigt und nicht ausgeliefert.
ns.CONF_SURE, ns.CONF_UNSURE, ns.CONF_NONE, ns.CONF_REFUTED = 1, 2, 3, 4
local CONF_WHY = { "seen in the game", "reported by only a few characters", "estimated" }

-- Gibt es in den Daten geschätzte Paare? Sonst hat der Schalter „Unbelegte Angaben zeigen“ nichts zu zeigen.
function ns.HasUnproven()
  for _, a in ipairs(D.abilities) do
    for _, t in ipairs(a.teach or {}) do
      if t[3] == ns.CONF_NONE then return true end
    end
  end
  return false
end

function ns.ShowConf(conf)
  conf = conf or 1
  if conf == 1 then return true end
  if conf >= ns.CONF_REFUTED then return false end
  local ui = ns.db and ns.db.ui
  if not ui then return false end
  if conf == 2 then return ui.showUncertain and true or false end
  return ui.showUnproven and true or false
end

-- Zeichen hinter Angaben, die nicht belegt sind: „?“ unsicher, „!“ unbelegt – zwei Zeichen, damit
-- man die beiden Stufen ohne Farbe auseinanderhält
function ns.ConfMark(conf)
  conf = conf or 1
  if conf == ns.CONF_UNSURE then return "?" end
  if conf == ns.CONF_NONE then return "!" end
  return ""
end

local confListeners = {}
function ns.OnShowConfChanged(fn) confListeners[#confListeners + 1] = fn end
function ns.ShowConfChanged()
  for _, fn in ipairs(confListeners) do ns.SafeCall("conf", fn) end
end

-- Liefert { score, level = "easy" | "medium" | "hard", why = { … } }
function ns.Effort(npcId, conf, rankLevel, observed)
  local b = ns.BeastInfo(npcId) or { cls = 0 }
  local s, why = 0, {}
  local c = CLS_EFFORT[b.cls]
  if c then s = s + c[1]; why[#why + 1] = L[c[2]] else why[#why + 1] = L["normal beast"] end
  local zones = ns.BeastZones(npcId)
  local inst = 0
  for _, z in ipairs(zones) do inst = math.max(inst, (D.zones[z] and D.zones[z].inst) or 0) end
  if inst == 2 then
    s = s + 3; why[#why + 1] = L["in a dungeon"]
  elseif inst >= 3 then
    s = s + 5; why[#why + 1] = inst == 3 and L["in a raid"] or L["on a battleground"]
  end
  local n = pointCount(npcId)
  if n == 0 then
    s = s + 1.5; why[#why + 1] = L["no coordinates"]
  elseif n < 3 then
    s = s + 2; why[#why + 1] = (n == 1 and L["only 1 spawn point"] or L["only %d spawn points"]):format(n)
  else
    if n < 10 then s = s + 1 end
    why[#why + 1] = (L["%d spawn points"]):format(n)
  end
  conf = conf or 1
  s = s + (conf - 1)
  if observed == "seen" then why[#why + 1] = L["seen when you tamed it"]
  elseif observed == "refuted" then why[#why + 1] = L["missing when you tamed it"]
  else why[#why + 1] = L[CONF_WHY[conf] or CONF_WHY[1]] end
  s = s + math.max(0, (b.max or b.min or rankLevel) - rankLevel) / 10   -- früher zähmbar = leichter
  local enemy = enemyZones()
  if enemy and #zones > 0 then
    local all = true
    for _, z in ipairs(zones) do if not enemy[z] then all = false end end
    if all then s = s + 2; why[#why + 1] = L["enemy faction territory"] end
  end
  return { score = s, level = s <= 1.5 and "easy" or (s <= 4 and "medium" or "hard"), why = why }
end

-- Belegung eines Eintrags nach den Daten und nach eigenen Beobachtungen beim Zähmen (Core/Observe.lua)
local function effective(npcId, a, r, conf)
  if ns.EffectiveConf then return ns.EffectiveConf(npcId, a, r, conf) end
  return conf or ns.CONF_SURE
end

-- Lehrtiere eines Rangs, belegte zuerst und darin das leichteste zuerst: { { id, beast, conf, effort }, … }
-- Was nach den Einstellungen nicht gezeigt wird, fehlt; list.hidden sagt, wie viele das sind.
-- Tiere, die man selbst beim Zähmen mit diesem Rang gesehen hat, kommen dazu, auch wenn die Daten sie
-- nicht kennen. zone (optional) ist eine Menge von Zonen-IDs { [id] = true } und lässt nur Tiere dieser
-- Zonen übrig.
function ns.Teachers(a, r, zone)
  local list = { hidden = 0 }
  local listed = {}
  local function consider(id, b, conf, order)
    local observed = ns.Observed and ns.Observed(id, a, r)
    local here = not zone
    if zone then
      for _, z in ipairs(ns.BeastZones(id)) do if zone[z] then here = true end end
    end
    if here and not ns.ShowConf(conf) then
      list.hidden = list.hidden + 1
    elseif here then
      list[#list + 1] = { id = id, beast = b, conf = conf, effort = ns.Effort(id, conf, r.level or 0, observed), order = order }
    end
  end
  for i, t in ipairs(a.teach) do
    local b = D.beasts[t[1]]
    if t[2] == r.rank and b then
      listed[t[1]] = true
      consider(t[1], b, effective(t[1], a, r, t[3]), i)
    end
  end
  for _, x in ipairs(ns.ObservedTeachers and ns.ObservedTeachers(a, r) or {}) do
    -- ohne Stammdaten (etwa nur von 2 fremden Meldern gezähmt, #103) mit leerer Stufe („?“)
    local b = ns.BeastInfo(x.id) or { cls = 0 }
    if not listed[x.id] then consider(x.id, b, x.conf, #a.teach + 1) end
  end
  -- Entdeckermodus: nur Lehrtiere, die man studiert hat, mit der Belegung aus den kompletten Daten (#169; bis 1.2.0
  -- nur, wenn eine eigene Zähmung genau diesen Rang zeigte). Die übrigen zählen als unentdeckt (list.undiscovered),
  -- damit man weiß, dass es etwas zu finden gibt
  list.undiscovered = 0
  if ns.Discovering and ns.Discovering() then
    local own = { hidden = 0, undiscovered = 0 }
    for _, t in ipairs(list) do
      if ns.Studied and ns.Studied(t.id) then
        own[#own + 1] = t
      else
        own.undiscovered = own.undiscovered + 1
      end
    end
    list = own
  end
  -- table.sort ist nicht stabil; bei gleichem Aufwand gilt die Reihenfolge der Daten, wie auf der Seite
  table.sort(list, function(x, y)
    if x.conf ~= y.conf then return x.conf < y.conf end
    if x.effort.score ~= y.effort.score then return x.effort.score < y.effort.score end
    return x.order < y.order
  end)
  return list
end

-- Was ein Tier beibringt, umgekehrt zu a.teach: { { a = Fähigkeit, r = Rang, conf = Belegung }, … },
-- nil für Tiere ohne Eintrag. Erst das angeborene Angriffstempo, dann die erlernbaren Ränge nach Name
-- und Rangnummer. Der Index nach den Daten entsteht beim ersten Aufruf (die Namen kommen dann schon vom
-- Client); Belegung nach Beobachtungen und Ausblenden nach den Einstellungen gelten bei jedem Aufruf neu.
local teaches, names
local function byNameAndRank(x, y)
  local lx, ly = ns.Learnable(x.a), ns.Learnable(y.a)
  if lx ~= ly then return ly end
  if x.a ~= y.a then return names[x.a] < names[y.a] end
  return (x.r.rank or 0) < (y.r.rank or 0)
end

ns.OnAbilitiesChanged(function() teaches, names = nil, nil end)

local function baseTeaches()
  if teaches then return teaches end
  teaches, names = {}, {}
  for _, a in ipairs(D.abilities) do
    names[a] = ns.AbilityName(a)
    for _, t in ipairs(a.teach) do
      local r
      for _, x in ipairs(a.ranks) do
        if x.rank == t[2] then r = x; break end
      end
      if r then
        local list = teaches[t[1]] or {}
        teaches[t[1]] = list
        list[#list + 1] = { a = a, r = r, conf = t[3] or 1 }
      end
    end
  end
  for _, list in pairs(teaches) do table.sort(list, byNameAndRank) end
  return teaches
end

-- alles, unabhängig von den Einstellungen
function ns.AllBeastTeaches(npcId)
  local base = baseTeaches()[npcId]
  local extra = ns.ObservedExtra and ns.ObservedExtra(npcId)
  if not base and not (extra and #extra > 0) then return nil end
  local out, have = {}, {}
  for _, x in ipairs(base or {}) do
    have[x.r] = true
    out[#out + 1] = { a = x.a, r = x.r, conf = effective(npcId, x.a, x.r, x.conf) }
  end
  for _, x in ipairs(extra or {}) do
    if not have[x.r] then out[#out + 1] = { a = x.a, r = x.r, conf = x.conf or ns.CONF_SURE } end
  end
  if extra and #extra > 0 then table.sort(out, byNameAndRank) end
  return out
end

function ns.BeastTeaches(npcId)
  local all = ns.AllBeastTeaches(npcId)
  if not all then return nil end
  local shown = {}
  for _, x in ipairs(all) do
    if ns.ShowConf(x.conf) then shown[#shown + 1] = x end
  end
  return shown
end

-- ---- Fähigkeiten aus der eigenen Erhebung ----
-- Eigenes zählt sofort (docs/konzept/entscheidungen.md): Ränge, die die Erhebung (Core/Survey.lua) aus der
-- Wildtierausbildung, vom Tierausbilder oder aus dem Zauberbuch eines Pets kennt, gelten gleich – nicht erst,
-- wenn sie über den Import in den Daten stehen. Wie tools/build-data.mjs: Ränge gleichen Namens bilden eine
-- Fähigkeit; was der Tierausbilder in der Stadt anbietet, gilt für alle Familien, sonst für die Familien der
-- Pets, die den Rang hatten. Ohne Rangnummer bleibt ein Zauber draußen; ein Tempo-Zauber aus dem Zauberbuch einer
-- eigenen Zähmung wird eine Tempo-Fähigkeit (unten, #189).
-- Wer etwas über die Fähigkeiten zwischenspeichert, hängt sich an ns.OnAbilitiesChanged (oben).

-- Ränge vom Tierausbilder, wie sie die mitgelieferten Daten kennen – festgehalten beim Laden, bevor die
-- Erhebung etwas dazutut. Daran erkennt das Addon den Tierausbilder (Core/Known.lua, #16): Ein Jägerlehrer
-- bietet nie einen dieser Ränge an. Umgekehrt steht ein Rang einer Fähigkeit, die der Tierausbilder gar nicht
-- lehrt (Beißen, Klaue …), nur in der Wildtierausbildung (#32).
local dataTrainerRank, dataBeastRank = {}, {}
for _, a in ipairs(D.abilities) do
  for _, r in ipairs(a.ranks) do
    if a.source == "trainer" then dataTrainerRank[r.id] = true else dataBeastRank[r.id] = true end
  end
end
function ns.IsDataTrainerRank(id) return dataTrainerRank[id] == true end
function ns.IsDataBeastRank(id) return dataBeastRank[id] == true end

ns.foreignRankIds = ns.foreignRankIds or {}   -- fremde Ränge, die eingehängt sind (Core/ForeignRanks.lua)

function ns.MergeSurveyAbilities()
  -- erst die Erhebung auf den neuesten Stand bringen (Core/Survey.lua: räumt Jägerzauber weg, #16)
  local s = ns.SurveyStore and ns.SurveyStore() or (ns.db and ns.db.survey)
  if type(s) ~= "table" then return false end
  local knownId, byName = {}, {}
  for _, a in ipairs(D.abilities) do
    for _, r in ipairs(a.ranks) do knownId[r.id] = true end
    for _, n in ipairs({ a.de or false, a.en or false }) do
      if n then byName[n] = a end
    end
  end
  local added = false
  local function add(id, name, rank, level, icon, fams, trainer, conf)
    if type(id) ~= "number" or knownId[id] or type(name) ~= "string" or name == "" or type(rank) ~= "number" then
      return
    end
    local a = byName[name]
    if not a then
      a = { kind = trainer and "general" or "family", source = trainer and "trainer" or "tame", icon = icon,
        families = {}, ranks = {}, teach = {} }
      a[LANG] = name
      D.abilities[#D.abilities + 1] = a
      byName[name] = a
    end
    for _, r in ipairs(a.ranks) do
      if r.rank == rank then return end   -- denselben Rang unter anderer ID nicht doppelt
    end
    local r = { id = id, rank = rank, level = level }
    if conf then
      r.conf = conf ~= ns.CONF_SURE and conf or nil   -- unsicher nur mit dem Schalter (#136)
      ns.foreignRankIds[id] = r
    end
    a.ranks[#a.ranks + 1] = r
    table.sort(a.ranks, function(x, y) return (x.rank or 0) < (y.rank or 0) end)
    if a.kind == "family" then
      for fam in pairs(fams or {}) do
        local have = false
        for _, f in ipairs(a.families) do if f == fam then have = true end end
        if not have then a.families[#a.families + 1] = fam end
      end
    end
    knownId[id] = true
    added = true
  end
  for id, r in pairs(s.ranks or {}) do
    if type(r) == "table" then add(id, r.name, r.rank, r.petLevel, r.icon, nil, r.npc == true) end
  end
  for id, e in pairs(s.spells or {}) do
    if type(e) == "table" then add(id, e.name, e.rank, nil, nil, e.fam, false) end
  end
  -- Ränge aus fremden Zähmungen (Core/ForeignRanks.lua, #103): nur zu Fähigkeiten, die man schon kennt und von
  -- Tieren lernt. Eine ganz neue Fähigkeit kommt nur über die Stammdaten (Prüfung auf Jägerzauber beim Import).
  -- Unsicher ab 2 Meldern, belegt ab 3 (#136); ein schon eingehängter Rang bekommt die neue Belegung.
  for _, c in ipairs(ns.ForeignRankCandidates and ns.ForeignRankCandidates() or {}) do
    local had = ns.foreignRankIds and ns.foreignRankIds[c.id]
    if had then
      local conf = c.conf ~= ns.CONF_SURE and c.conf or nil
      if had.conf ~= conf then had.conf = conf; added = true end
    else
      local a = byName[c.name]
      if a and a.source == "tame" and ns.Learnable(a) then add(c.id, c.name, c.rank, nil, nil, c.fams, false, c.conf) end
    end
  end
  -- Angriffstempo, das die Daten noch nicht kennen (#189): nur aus dem Zauberbuch einer eigenen Zähmung, nie aus
  -- einem gemessenen Tempo (Buffs des Jägers verfälschen es). Ein passiver Zauber ohne Rang (der Client hat seine
  -- Daten, es gibt also keinen), den die Wildtierausbildung nicht kennt, wird eine Tempo-Fähigkeit, wie im Generator.
  -- Das Tempo in Sekunden kommt aus der Beschreibung des Zaubers (ns.TraitSpeed); die gemessenen Werte der eigenen
  -- Zähmungen sagen nur, ob schneller oder langsamer als normal, und keiner davon: kein Tempo-Zauber. Fremde
  -- Zähmungen kommen nur über die Stammdaten.
  local candidates
  for id, e in pairs(s.spells or {}) do
    if type(e) == "table" and e.passive and not e.rank and not knownId[id] and not (s.ranks and s.ranks[id])
      and type(e.name) == "string" and e.name ~= "" and ns.SpellDataCached then
      if ns.SpellDataCached(id) then
        candidates = candidates or {}
        candidates[id] = { fast = 0, slow = 0 }   -- eigene Zähmungen mit dem Zauber, schneller bzw. langsamer
      elseif ns.RequestSpellData then
        ns.RequestSpellData(id)   -- nach dem Laden liest Core/Survey.lua das Zauberbuch neu und ruft dies hier wieder
      end
    end
  end
  if candidates then
    for _, line in ipairs((ns.db and ns.db.obs) or {}) do
      local o = ns.ParseObservation and ns.ParseObservation(line)
      if o and o.own and o.speed then
        for id, c in pairs(candidates) do
          if o.spells[id] then
            if o.speed < NORMAL_SPEED - 0.05 then c.fast = c.fast + 1
            elseif o.speed > NORMAL_SPEED + 0.05 then c.slow = c.slow + 1 end
          end
        end
      end
    end
    for id, c in pairs(candidates) do
      local speed = c.fast ~= c.slow and ns.TraitSpeed(id, c.fast > c.slow)
      if speed and byName[s.spells[id].name] == nil then
        local a = { kind = "trait", source = "tame", speed = speed, families = {}, teach = {},
          ranks = { { id = id, rank = 1 } } }
        a[LANG] = s.spells[id].name
        -- nach dem Tempo zwischen die anderen Tempo-Fähigkeiten, wie in den Daten (die Liste übernimmt die Reihenfolge)
        local at = #D.abilities + 1
        for i, x in ipairs(D.abilities) do
          if x.kind == "trait" and x.speed and x.speed > speed then at = i; break end
        end
        table.insert(D.abilities, at, a)
        byName[a[LANG]] = a
        knownId[id] = true
        added = true
      end
    end
  end
  if added then
    for _, fn in ipairs(abilityListeners) do ns.SafeCall("abilities", fn) end
  end
  return added
end

ns.On("PLAYER_LOGIN", function() ns.SafeCall("abilities", ns.MergeSurveyAbilities) end)
-- offene Ansichten neu aufbauen
ns.OnAbilitiesChanged(function() if ns.ShowConfChanged then ns.ShowConfChanged() end end)

-- ---- Kennzahlen ----
function ns.Counts()
  local c = { abilities = #D.abilities, ranks = 0, families = 0, beasts = 0, zones = 0, located = 0 }
  for _, a in ipairs(D.abilities) do c.ranks = c.ranks + #a.ranks end
  for _ in pairs(D.families) do c.families = c.families + 1 end
  for _ in pairs(D.beasts) do c.beasts = c.beasts + 1 end
  for _ in pairs(D.zones) do c.zones = c.zones + 1 end
  for _ in pairs(D.coords) do c.located = c.located + 1 end
  return c
end

function ns.CountsText()
  local c = ns.Counts()
  return (L["%d abilities, %d ranks, %d families, %d beasts (%d with coordinates), %d zones"]):format(
    c.abilities, c.ranks, c.families, c.beasts, c.located, c.zones)
end
