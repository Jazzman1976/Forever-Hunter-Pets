-- Forever Hunter Pets · API-Probe (/fhp api). Entwicklerwerkzeug, nur deutsch.
-- Klärt, woher der Lernstand in Forever zu lesen ist. Alles landet zusätzlich in
-- ForeverHunterPetsDB.probe, damit es nach /reload aus der SavedVariables-Datei lesbar ist.
local _, ns = ...

local MAX_LINES = 1500
local issecret = _G.issecretvalue
local log

local silent = false   -- nur mitschreiben, nicht in den Chat (Zähm-Probe, sonst zu viel)
local function out(text)
  if log and #log < MAX_LINES then log[#log + 1] = text end
  if not silent then ns.Print(text) end
end

local function show(v)
  if issecret and issecret(v) then return "<geheim>" end
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    local x = v[k]
    if x == nil then x = v[tonumber(k)] end
    parts[#parts + 1] = k .. "=" .. ((issecret and issecret(x)) and "<geheim>" or tostring(x))
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function join(...)
  local n = select("#", ...)
  if n == 0 then return "(nichts)" end
  local t = {}
  for i = 1, n do t[i] = show((select(i, ...))) end
  return table.concat(t, " | ")
end

local function result(ok, ...)
  if ok then return join(...) end
  return "FEHLER: " .. tostring((...))
end

-- Ruft fn auf und schreibt alle Rückgabewerte hin
local function probe(label, fn, ...)
  if type(fn) ~= "function" then
    out(label .. " = (gibt es nicht)")
    return
  end
  out(label .. " = " .. result(pcall(fn, ...)))
end

local function exists(path)
  local v = _G
  for part in path:gmatch("[^%.]+") do
    v = type(v) == "table" and v[part] or nil
  end
  return v
end

-- ---- Fenster „Wildtierausbildung“ (alte Craft-API) ----
local function dumpCrafts(why)
  out("--- Craft-Liste (" .. why .. ") ---")
  if type(GetNumCrafts) ~= "function" then
    out("GetNumCrafts gibt es nicht")
    return
  end
  probe("GetCraftDisplaySkillLine()", GetCraftDisplaySkillLine)
  probe("GetCraftSkillLine(1)", GetCraftSkillLine, 1)
  local ok, n = pcall(GetNumCrafts)
  out("GetNumCrafts() = " .. tostring(n))
  n = ok and tonumber(ns.clean(n)) or 0
  for i = 1, math.min(n, 80) do
    probe("GetCraftInfo(" .. i .. ")", GetCraftInfo, i)
    if i <= 3 then
      probe("GetCraftRecipeLink(" .. i .. ")", GetCraftRecipeLink, i)
      probe("GetCraftItemLink(" .. i .. ")", GetCraftItemLink, i)
    end
  end
end

-- ---- Trainer-Fenster: in Forever öffnet „Wildtierausbildung“ offenbar als solches (TRAINER_SHOW) ----
local function dumpTrainer(why)
  out("--- Trainer-Fenster (" .. why .. ") ---")
  probe("UnitName(npc)", UnitName, "npc")
  probe("IsTradeskillTrainer()", IsTradeskillTrainer)
  probe("C_PetInfo.GetPetTrainingPoints()", C_PetInfo and C_PetInfo.GetPetTrainingPoints)
  for _, f in ipairs({ "available", "unavailable", "used" }) do
    probe("GetTrainerServiceTypeFilter(" .. f .. ")", GetTrainerServiceTypeFilter, f)
  end
  if type(GetNumTrainerServices) ~= "function" then
    out("GetNumTrainerServices gibt es nicht")
    return
  end
  local ok, n = pcall(GetNumTrainerServices)
  out("GetNumTrainerServices() = " .. tostring(n))
  n = ok and tonumber(ns.clean(n)) or 0
  for i = 1, math.min(n, 150) do
    probe("GetTrainerServiceInfo(" .. i .. ")", GetTrainerServiceInfo, i)
    if i <= 6 then
      probe("  GetTrainerServiceCost(" .. i .. ")", GetTrainerServiceCost, i)
      probe("  GetTrainerServiceLevelReq(" .. i .. ")", GetTrainerServiceLevelReq, i)
      probe("  GetTrainerServiceSkillReq(" .. i .. ")", GetTrainerServiceSkillReq, i)
      probe("  GetTrainerServiceItemLink(" .. i .. ")", GetTrainerServiceItemLink, i)
      probe("  GetTrainerServiceDescription(" .. i .. ")", GetTrainerServiceDescription, i)
    end
  end
end

-- ---- Zauberbuch des Pets ----
local function dumpPetSpells()
  out("--- Pet ---")
  probe("UnitExists(pet)", UnitExists, "pet")
  probe("UnitCreatureFamily(pet)", UnitCreatureFamily, "pet")
  probe("UnitLevel(pet)", UnitLevel, "pet")
  probe("GetPetTrainingPoints()", GetPetTrainingPoints)
  local SB = C_SpellBook
  if not (SB and SB.HasPetSpells and SB.GetSpellBookItemInfo) then
    out("C_SpellBook.HasPetSpells/GetSpellBookItemInfo gibt es nicht")
    probe("HasPetSpells()", HasPetSpells)
    return
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
  out("Enum.SpellBookSpellBank.Pet = " .. tostring(bank))
  local ok, n = pcall(SB.HasPetSpells)
  out("C_SpellBook.HasPetSpells() = " .. tostring(n))
  n = ok and tonumber(ns.clean(n)) or 0
  for i = 1, math.min(n, 40) do
    local ok2, info = pcall(SB.GetSpellBookItemInfo, i, bank)
    info = ok2 and ns.clean(info)
    if type(info) == "table" then
      local id = ns.clean(info.spellID)
      local sub = ns.clean(info.subName)
      if (not sub or sub == "") and id and C_Spell and C_Spell.GetSpellSubtext then
        local ok3, s = pcall(C_Spell.GetSpellSubtext, id)
        if ok3 then sub = ns.clean(s) end
      end
      local known = "?"
      if id and IsSpellKnown then
        local ok4, k = pcall(IsSpellKnown, id, true)
        known = ok4 and tostring(ns.clean(k)) or "FEHLER"
      end
      out(("  %d: id=%s name=%s sub=%s passiv=%s IsSpellKnown(id,true)=%s"):format(
        i, tostring(id), tostring(ns.clean(info.name)), tostring(sub), tostring(ns.clean(info.isPassive)), known))
    else
      out("  " .. i .. ": " .. tostring(info))
    end
  end
end

-- ---- Ereignisse mitschreiben, bis zum nächsten /reload ----
local EVENTS = {
  "CRAFT_SHOW", "CRAFT_UPDATE", "CRAFT_CLOSE", "TRAINER_SHOW", "PET_STABLE_SHOW",
  "UNIT_PET", "UNIT_PET_TRAINING_POINTS", "PET_BAR_UPDATE", "SPELLS_CHANGED",
  "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "PET_SPELL_POWER_UPDATE", "CHAT_MSG_SYSTEM",
}
local watching = false
local function watchEvents()
  if watching then return end
  watching = true
  local known, unknown = {}, {}
  for _, e in ipairs(EVENTS) do
    local ok = ns.On(e, function(...)
      out("EREIGNIS " .. e .. ": " .. join(...))
      if e == "TRAINER_SHOW" then dumpTrainer("nach TRAINER_SHOW") end
    end)
    local list = ok and known or unknown
    list[#list + 1] = e
  end
  out("Ereignisse registriert: " .. table.concat(known, ", "))
  out("Ereignisse unbekannt: " .. (#unknown > 0 and table.concat(unknown, ", ") or "keine"))
end

-- ---- Erkundete Kartenteile: liefert der Client die Bildstücke, die er über die Grundkarte legt? ----
-- Wie show(), aber auch für Tabellen in Tabellen (fileDataIDs, hitRect)
local function deep(v, depth)
  if issecret and issecret(v) then return "<geheim>" end
  if type(v) ~= "table" then return tostring(v) end
  if (depth or 0) >= 3 then return "{…}" end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for i, k in ipairs(keys) do
    if i > 12 then parts[#parts + 1] = "… (" .. #keys .. " Schlüssel)"; break end
    parts[#parts + 1] = tostring(k) .. "=" .. deep(v[k], (depth or 0) + 1)
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function dumpExplored(mapID, why)
  local E = C_MapExplorationInfo
  out("- Karte " .. tostring(mapID) .. " (" .. why .. ")")
  probe("  C_Map.GetMapInfo", C_Map and C_Map.GetMapInfo, mapID)
  if C_Map and C_Map.GetMapArtLayers then
    local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
    out("  GetMapArtLayers = " .. (ok and deep(layers) or ("FEHLER: " .. tostring(layers))))
  end
  if not (E and E.GetExploredMapTextures) then return end
  local ok, list = pcall(E.GetExploredMapTextures, mapID)
  if not ok then out("  GetExploredMapTextures FEHLER: " .. tostring(list)); return end
  list = ns.clean(list)
  if type(list) ~= "table" then out("  GetExploredMapTextures = " .. tostring(list)); return end
  out("  GetExploredMapTextures: " .. #list .. " Stück(e)")
  for i = 1, math.min(#list, 6) do out("    " .. i .. ": " .. deep(list[i])) end
  if E.GetExploredAreaIDsAtPosition and C_Map.GetPlayerMapPosition then
    local ok2, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    pos = ok2 and ns.clean(pos)
    if pos then
      local ok3, ids = pcall(E.GetExploredAreaIDsAtPosition, mapID, pos)
      out("  GetExploredAreaIDsAtPosition(Spieler) = " .. (ok3 and deep(ids) or ("FEHLER: " .. tostring(ids))))
    end
  end
end

-- /fhp karte: eigenes Protokoll in ForeverHunterPetsDB.probe
function ns.ProbeMap()
  log = {}
  ns.db.probe = log
  out("=== Karten-Probe " .. date("%Y-%m-%d %H:%M:%S") .. " · Addon " .. ns.version .. " ===")
  probe("GetBuildInfo()", GetBuildInfo)
  local names = {}
  for k, v in pairs(C_MapExplorationInfo or {}) do
    if type(v) == "function" then names[#names + 1] = k end
  end
  table.sort(names)
  out("C_MapExplorationInfo: " .. (C_MapExplorationInfo and table.concat(names, ", ") or "(gibt es nicht)"))
  for _, path in ipairs({ "MapExplorationPinMixin", "MapExplorationDataProviderMixin", "WorldMapFrame",
      "C_Map.GetMapArtID", "C_Map.GetMapArtLayerTextures", "C_Map.GetMapArtBackgroundAtlas",
      "C_Map.GetMapHighlightInfoAtPosition", "GetNumMapOverlays", "GetMapOverlayInfo" }) do
    out("  " .. path .. ": " .. type(exists(path)))
  end
  local here
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    here = ok and ns.clean(id) or nil
  end
  if here then
    probe("C_Map.GetMapArtID(hier)", C_Map.GetMapArtID, here)
    dumpExplored(here, "hier")
  else
    out("Keine Karte für den Standort – bitte in einer Außenzone aufrufen.")
  end
  -- zum Vergleich: je eine Startzone beider Seiten und eine hohe Zone
  for _, m in ipairs({ { 1429, "Wald von Elwynn" }, { 1411, "Durotar" }, { 1428, "Brennende Steppe" } }) do
    if m[1] ~= here then dumpExplored(m[1], m[2]) end
  end
  out("=== Ende. Jetzt /reload. ===")
end

function ns.ProbeApi()
  log = {}
  ns.db.probe = log
  out("=== API-Probe " .. date("%Y-%m-%d %H:%M:%S") .. " · Addon " .. ns.version .. " ===")
  probe("GetBuildInfo()", GetBuildInfo)
  out("WOW_PROJECT_ID = " .. tostring(WOW_PROJECT_ID) .. " · WOW_PROJECT_CAMELOT = " .. tostring(WOW_PROJECT_CAMELOT))
  probe("GetLocale()", GetLocale)
  probe("UnitClass(player)", UnitClass, "player")
  probe("UnitFactionGroup(player)", UnitFactionGroup, "player")
  probe("InCombatLockdown()", InCombatLockdown)
  out("issecretvalue vorhanden = " .. tostring(issecret ~= nil))

  out("--- Was es gibt ---")
  for _, path in ipairs({
    "GetNumCrafts", "GetCraftInfo", "GetCraftDisplaySkillLine", "GetCraftSkillLine", "GetCraftRecipeLink",
    "GetCraftDescription", "CraftFrame", "CraftFrame_LoadUI", "C_PetInfo", "C_StableInfo",
    "IsSpellKnown", "IsPlayerSpell", "IsSpellKnownOrOverridesKnown", "C_SpellBook.IsSpellKnown",
    "C_SpellBook.IsSpellInSpellBook", "C_SpellBook.HasPetSpells", "C_SpellBook.GetSpellBookItemInfo",
    "C_Spell.GetSpellInfo", "C_Spell.GetSpellDescription", "C_Spell.GetSpellSubtext", "C_Spell.GetSpellTexture",
    "GetPetTrainingPoints", "UnitCreatureFamily", "GetPetActionInfo",
    "C_Map.GetBestMapForUnit", "C_Map.GetMapInfo", "C_Map.GetAreaInfo", "C_Map.GetMapArtLayers",
    "C_Map.GetMapArtLayerTextures", "C_Map.GetPlayerMapPosition",
  }) do
    out("  " .. path .. ": " .. type(exists(path)))
  end

  -- Beißen Rang 1 und Knurren Rang 1 als Stichprobe
  out("--- Zauber ---")
  if C_Spell then
    probe("C_Spell.GetSpellInfo(17253)", C_Spell.GetSpellInfo, 17253)
    probe("C_Spell.GetSpellSubtext(17253)", C_Spell.GetSpellSubtext, 17253)
    probe("C_Spell.GetSpellDescription(17253)", C_Spell.GetSpellDescription, 17253)
  end
  for _, id in ipairs({ 17253, 2649 }) do
    probe("IsSpellKnown(" .. id .. ")", IsSpellKnown, id)
    probe("IsSpellKnown(" .. id .. ", true)", IsSpellKnown, id, true)
    probe("IsPlayerSpell(" .. id .. ")", IsPlayerSpell, id)
  end

  dumpPetSpells()
  dumpCrafts("beim Aufruf")

  -- Die Craft-API fehlt in Forever. Was steht stattdessen bereit?
  out("--- Namensräume und Globale rund ums Ausbilden ---")
  for _, space in ipairs({ "C_PetInfo", "C_StableInfo" }) do
    local names = {}
    for k, v in pairs(_G[space] or {}) do
      if type(v) == "function" then names[#names + 1] = k end
    end
    table.sort(names)
    out(space .. ": " .. table.concat(names, ", "))
  end
  local globals = {}
  for k in pairs(_G) do
    if type(k) == "string" and #globals < 150 then
      local l = k:lower()
      if l:find("pettrain", 1, true) or l:find("beasttrain", 1, true) or l:find("pet_train", 1, true)
          or l:find("beast_train", 1, true) or l:find("petabilit", 1, true) or l:find("trainerservice", 1, true) then
        globals[#globals + 1] = k
      end
    end
  end
  table.sort(globals)
  out("Globale (" .. #globals .. "): " .. table.concat(globals, ", "))

  out("--- Karte ---")
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and ns.clean(mapID)
    out("C_Map.GetBestMapForUnit(player) = " .. tostring(mapID))
    if mapID then
      probe("C_Map.GetMapInfo(map)", C_Map.GetMapInfo, mapID)
      local ok2, layers = pcall(C_Map.GetMapArtLayers, mapID)
      if ok2 and type(layers) == "table" then
        out("C_Map.GetMapArtLayers(map): " .. #layers .. " Ebene(n), erste = " .. show(layers[1]))
      else
        out("C_Map.GetMapArtLayers(map) = " .. tostring(layers))
      end
      local ok3, tex = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
      if ok3 and type(tex) == "table" then
        out("C_Map.GetMapArtLayerTextures(map, 1): " .. #tex .. " Kacheln, erste = " .. tostring(tex[1]))
      else
        out("C_Map.GetMapArtLayerTextures(map, 1) = " .. tostring(tex))
      end
    end
    -- Wald von Elwynn: Gebiets-ID 12 und uiMapID 1429
    probe("C_Map.GetAreaInfo(12)", C_Map.GetAreaInfo, 12)
    probe("C_Map.GetMapInfo(1429)", C_Map.GetMapInfo, 1429)
  end

  watchEvents()
  out("=== Ende. Jetzt das Fenster Wildtierausbildung öffnen, warten bis die Zeilen durch sind, danach /reload. ===")
end

-- ---- /fhp zaehmen: was der Client beim Zähmen meldet ----
-- Klärt für die Beobachtungen (Plan Datenqualität, Inkrement 2): in welcher Reihenfolge die Ereignisse
-- kommen, ob die GUID des Pets die NPC-ID trägt und ab wann das Zauberbuch die mitgebrachten Ränge zeigt.
-- Schreibt 10 Minuten lang still nach ForeverHunterPetsDB.probe; der Chat bekommt nur Wegmarken.
local TAME_EVENTS = {
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED",
  "PET_UI_UPDATE", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "LOCALPLAYER_PET_RENAMED", "PET_SPELL_POWER_UPDATE",
}
local tameUntil, tameStart, tameHooked = 0, 0, false

local function dumpUnit(unit)
  probe("UnitGUID(" .. unit .. ")", UnitGUID, unit)
  probe("UnitName(" .. unit .. ")", UnitName, unit)
  probe("UnitLevel(" .. unit .. ")", UnitLevel, unit)
  probe("UnitCreatureFamily(" .. unit .. ")", UnitCreatureFamily, unit)
end

-- Das Pet: GUID, Stufe, Tempo, Zauberbuch und was ns.PetRanks daraus macht
local function dumpPet(why)
  out(("--- Pet %s (+%.1f s) ---"):format(why, GetTime() - tameStart))
  dumpUnit("pet")
  probe("UnitAttackSpeed(pet)", UnitAttackSpeed, "pet")
  dumpPetSpells()
  local ranks = ns.PetRanks and ns.PetRanks()
  if ranks then
    local parts = {}
    for a, rank in pairs(ranks) do parts[#parts + 1] = ns.AbilityName(a) .. " " .. rank end
    table.sort(parts)
    out("ns.PetRanks(): " .. (#parts > 0 and table.concat(parts, ", ") or "(leer)"))
  else
    out("ns.PetRanks(): nil (kein Pet)")
  end
end

local function onTameEvent(e, ...)
  if GetTime() > tameUntil then return end
  local unit = ns.clean((...))
  -- UNIT_*-Ereignisse kommen auch für Namensplaketten und Gruppe; nur Spieler und Pet zählen
  if e:find("^UNIT_") and unit ~= "player" and unit ~= "pet" then return end
  silent = true
  out(("EREIGNIS +%.1f s %s: %s"):format(GetTime() - tameStart, e, join(...)))
  if e == "UNIT_SPELLCAST_START" or e == "UNIT_SPELLCAST_CHANNEL_START" then
    if unit == "player" then
      out("--- Ziel beim Zauberbeginn ---")
      dumpUnit("target")
    end
  elseif e == "UNIT_PET" and unit == "player" then
    dumpPet("bei UNIT_PET")
    -- das Zauberbuch kommt womöglich erst später: noch dreimal nachsehen
    for _, d in ipairs({ 1, 3, 6 }) do
      ns.After(d, function()
        silent = true
        dumpPet(("%d s nach UNIT_PET"):format(d))
        silent = false
      end)
    end
    silent = false
    ns.Print("Zähm-Probe: neues Pet erkannt, Zauberbuch wird gelesen. In etwa 10 Sekunden /reload, damit die SavedVariables geschrieben werden.")
  elseif (e == "PET_BAR_UPDATE" or e == "SPELLS_CHANGED") then
    out("  (Zauberbuch-Größe: " .. result(pcall(C_SpellBook and C_SpellBook.HasPetSpells or HasPetSpells)) .. ")")
  end
  silent = false
end

function ns.ProbeTame()
  log = {}
  ns.db.probe = log
  tameStart = GetTime()
  tameUntil = tameStart + 600
  silent = true
  out("=== Zähm-Probe " .. date("%Y-%m-%d %H:%M:%S") .. " · Addon " .. ns.version .. " ===")
  probe("GetBuildInfo()", GetBuildInfo)
  dumpPet("vor dem Zähmen")
  silent = false
  if not tameHooked then
    tameHooked = true
    for _, e in ipairs(TAME_EVENTS) do
      local name = e
      ns.On(name, function(...) onTameEvent(name, ...) end)
    end
  end
  ns.Print("Zähm-Probe läuft 10 Minuten. Pet freilassen (oder in den Stall), dann ein Tier zähmen. Am besten eins, dessen Fähigkeiten du kennst.")
end

-- ---- /fhp besitzer: erkennt man Begleiter von NPCs am Tooltip? (#90) ----
-- Schreibt 10 Minuten lang still nach ForeverHunterPetsDB.probe: je Tier mit Familie (Ziel, Maus, Namensplakette)
-- einmal die Einheit, die Tooltip-Zeilen über C_TooltipInfo (mit Zeilentyp) und über einen versteckten Tooltip.
-- Dazu die Vorlagen UNITNAME_* des Clients und rote Fehlermeldungen (UI_ERROR_MESSAGE), etwa beim Zähmen.
local ownerUntil, ownerStart, ownerHooked, ownerSeen, ownerTip = 0, 0, false, {}, nil

local function dumpTooltip(unit)
  if C_TooltipInfo and C_TooltipInfo.GetUnit then
    local ok, d = pcall(C_TooltipInfo.GetUnit, unit)
    d = ok and ns.clean(d)
    if type(d) == "table" and type(d.lines) == "table" then
      for i, l in ipairs(d.lines) do
        out(("  TooltipInfo %d: typ=%s links=%s rechts=%s"):format(i, show(l.type), show(l.leftText), show(l.rightText)))
      end
    else
      out("  C_TooltipInfo.GetUnit = " .. (ok and show(d) or ("FEHLER: " .. tostring(d))))
    end
  else
    out("  C_TooltipInfo.GetUnit gibt es nicht")
  end
  if ownerTip == nil and CreateFrame then
    local ok, t = pcall(CreateFrame, "GameTooltip", "ForeverHunterPetsProbeTip", nil, "GameTooltipTemplate")
    ownerTip = ok and t or false
  end
  if not ownerTip then out("  versteckter Tooltip: nicht anzulegen"); return end
  ownerTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  local ok, err = pcall(ownerTip.SetUnit, ownerTip, unit)
  if not ok then out("  SetUnit FEHLER: " .. tostring(err)) end
  local n = ownerTip:NumLines() or 0
  out("  versteckter Tooltip: " .. tostring(n) .. " Zeile(n)")
  for i = 1, n do
    local left, right = _G["ForeverHunterPetsProbeTipTextLeft" .. i], _G["ForeverHunterPetsProbeTipTextRight" .. i]
    out(("  Zeile %d: links=%s rechts=%s"):format(i, show(left and left:GetText()), show(right and right:GetText())))
  end
  ownerTip:Hide()
end

local function dumpOwnerUnit(unit, why)
  if UnitIsPlayer(unit) then return end
  local fam = ns.clean(UnitCreatureFamily(unit))
  if not fam then return end
  local guid = ns.clean(UnitGUID(unit))
  if guid and ownerSeen[guid] then return end
  if guid then ownerSeen[guid] = true end
  out(("--- %s (%s, +%.0f s) ---"):format(unit, why, GetTime() - ownerStart))
  dumpUnit(unit)
  probe("UnitCreatureType(" .. unit .. ")", UnitCreatureType, unit)
  probe("UnitClassification(" .. unit .. ")", UnitClassification, unit)
  probe("UnitPlayerControlled(" .. unit .. ")", UnitPlayerControlled, unit)
  probe("UnitIsOtherPlayersPet(" .. unit .. ")", UnitIsOtherPlayersPet, unit)
  probe("UnitIsCharmed(" .. unit .. ")", UnitIsCharmed, unit)
  probe("UnitReaction(" .. unit .. ", player)", UnitReaction, unit, "player")
  probe("UnitCanAttack(player, " .. unit .. ")", UnitCanAttack, "player", unit)
  dumpTooltip(unit)
end

local function onOwnerEvent(e, ...)
  if GetTime() > ownerUntil then return end
  silent = true
  if e == "PLAYER_TARGET_CHANGED" then
    if UnitExists("target") then dumpOwnerUnit("target", "Ziel") end
  elseif e == "UPDATE_MOUSEOVER_UNIT" then
    if UnitExists("mouseover") then dumpOwnerUnit("mouseover", "Maus") end
  elseif e == "NAME_PLATE_UNIT_ADDED" then
    local unit = ns.clean((...))
    if unit then dumpOwnerUnit(unit, "Namensplakette") end
  elseif e == "UI_ERROR_MESSAGE" then
    local _, msg = ...
    msg = ns.clean(msg)
    out(("EREIGNIS +%.0f s UI_ERROR_MESSAGE: %s"):format(GetTime() - ownerStart, join(...)))
    -- welche Konstante des Clients steckt hinter dem Text?
    if type(msg) == "string" then
      local hits = {}
      for k, v in pairs(_G) do
        if v == msg and type(k) == "string" and #hits < 10 then hits[#hits + 1] = k end
      end
      table.sort(hits)
      out("  Konstanten mit diesem Text: " .. (#hits > 0 and table.concat(hits, ", ") or "keine"))
    end
    if UnitExists("target") then
      out("  Ziel dabei:")
      probe("  UnitGUID(target)", UnitGUID, "target")
      probe("  UnitName(target)", UnitName, "target")
    end
  elseif e == "UNIT_SPELLCAST_FAILED" and ns.clean((...)) == "player" then
    out(("EREIGNIS +%.0f s UNIT_SPELLCAST_FAILED: %s"):format(GetTime() - ownerStart, join(...)))
  end
  silent = false
end

function ns.ProbeOwner()
  log = {}
  ns.db.probe = log
  ownerStart = GetTime()
  ownerUntil = ownerStart + 600
  ownerSeen = {}
  silent = true
  out("=== Besitzer-Probe " .. date("%Y-%m-%d %H:%M:%S") .. " · Addon " .. ns.version .. " ===")
  probe("GetBuildInfo()", GetBuildInfo)
  probe("GetLocale()", GetLocale)
  out("--- Vorlagen des Clients ---")
  local names = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and type(v) == "string" and (k:find("^UNITNAME_") or k:find("OWNER")) then
      names[#names + 1] = k
    end
  end
  table.sort(names)
  for i, k in ipairs(names) do
    if i > 60 then out("  … (" .. #names .. " insgesamt)"); break end
    out("  " .. k .. " = " .. _G[k])
  end
  if Enum and Enum.TooltipDataLineType then
    out("Enum.TooltipDataLineType = " .. show(Enum.TooltipDataLineType))
  end
  -- was gerade schon da ist
  if UnitExists("target") then dumpOwnerUnit("target", "Ziel beim Aufruf") end
  if UnitExists("mouseover") then dumpOwnerUnit("mouseover", "Maus beim Aufruf") end
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if UnitExists(unit) then dumpOwnerUnit(unit, "Namensplakette beim Aufruf") end
  end
  silent = false
  if not ownerHooked then
    ownerHooked = true
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
        "UI_ERROR_MESSAGE", "UNIT_SPELLCAST_FAILED" }) do
      local name = e
      ns.On(name, function(...) onOwnerEvent(name, ...) end)
    end
  end
  ns.Print("Besitzer-Probe läuft 10 Minuten. Tiere mit und ohne Besitzer in die Nähe holen, mit der Maus überfahren, anvisieren, eins zu zähmen versuchen. Danach /reload.")
end
