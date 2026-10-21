-- Forever Hunter Pets · Tooltip eines Tiers: sein Status in dieser Zone (Fährte, gefunden, bekannt), dann
-- Angriffstempo und die Ränge, die es beibringt, jeweils mit Lernstand des Jägers („gelernt“/„neu“). Über die Lehre wird nichts vermutet: Weiß
-- sie noch niemand, sagt das im Komplettmodus eine eigene Zeile (#23); fehlen noch Belege, eine andere (#40).
-- Gelernt / neu unterscheiden Farbe und Wort – nie die Farbe allein. Was nicht belegt ist, erscheint nur
-- nach den Einstellungen und trägt ein „?“ bzw. „!“; erklärt wird das dort, nicht hier.
local _, ns = ...
local L = ns.L
local D = ns.Data

-- Fähigkeits-Icon wie in der Wildtierausbildung
local function iconTag(a)
  return "|T" .. ns.AbilityIcon(a) .. ":16:16|t"
end

-- NPC-ID aus einer GUID wie „Creature-0-5250-0-12-525-0000ABCDEF“; nil für Spieler, Pets und Geheimes
local function npcIdFromGuid(guid)
  guid = ns.clean(guid)
  if type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end

-- Status des Tiers in dieser Zone (E7), mit denselben Wörtern wie im Reiter „Gebiet“. Der Tooltip kann vor
-- der Sichtung kommen; deshalb nimmt er Fährte und Fundort notfalls selbst auf, damit „Fährte aufgenommen“ nie
-- bei einem Tier steht, das im selben Moment gefunden wird. Kein Fundort in Kampf, Instanz und während
-- „Augen des Wildtiers“ oder „Adlerauge“ – wie bei der Sichtung (Core/Sightings.lua).
local function quiet()
  if InCombatLockdown and ns.clean(InCombatLockdown()) then return true end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    if ok and ns.clean(inside) then return true end
  end
  return ns.Possessing()
end

-- Nur ein wildes Tier unter der Maus, wie bei der Sichtung (ns.WildBeast): mit Familie, Wildtier, keinem Spieler
-- gehörend. Sonst bekämen Wachen, Händler und Dämonen (#80) Fährten und Fundorte.
local function wildBeastUnderMouse(guid)
  local okG, g = pcall(UnitGUID, "mouseover")
  if not (okG and guid and ns.clean(g) == ns.clean(guid)) then return false end
  local fam = ns.WildBeast("mouseover")
  return fam ~= nil, fam
end

local function statusLine(id, guid)
  local wild, fam = wildBeastUnderMouse(guid)
  if not wild then return nil end
  local map, cell = ns.CellHere()
  if not map then return nil end
  ns.NoteTrack(id, map)
  local okN, name = pcall(UnitName, "mouseover")
  if okN then ns.NoteTrackName(id, fam, ns.clean(name)) end
  if not quiet() and ns.UnitClose("mouseover") then
    ns.AddCells(id, map, cell)
  end
  return ns.StatusText(id, map)   -- nil bei unentdeckt oder ohne Fundort in der Zone: keine Zeile, wie im Reiter
end

local function addLines(tooltip, guid)
  if not (ns.db and ns.db.ui.tooltip) then return end
  if not ns.ModeChosen() then return end   -- vor der Wahl des Modus nichts verraten
  local id = npcIdFromGuid(guid)
  local status = id and statusLine(id, guid)
  local list
  if ns.Discovering() then
    -- Entdeckermodus: nur, was eine eigene Zähmung bei diesem Tier gezeigt hat
    local own = id and ns.TeachInfo(id, true)
    if own and #own > 0 then
      -- das angeborene Angriffstempo vorn, wie im Komplettmodus
      list = {}
      for _, pass in ipairs({ false, true }) do
        for _, x in ipairs(own) do
          if ns.Learnable(x.a) == pass then list[#list + 1] = { a = x.a, r = x.r, conf = ns.CONF_SURE } end
        end
      end
    end
  else
    list = id and ns.BeastInfo(id) and ns.BeastTeaches(id)
  end
  list = list or {}
  -- Schon gelernte Ränge weglassen, wenn die Einstellung „Bekannte Fähigkeiten anzeigen“ aus ist
  if ns.db.ui.tooltipShowKnown == false and ns.char then
    local rest = {}
    for _, e in ipairs(list) do
      if not (ns.Learnable(e.a) and ns.IsKnown(e.r)) then rest[#rest + 1] = e end
    end
    list = rest
  end
  -- Weiß man, dass das Tier nichts lehrt, sagt der Tooltip das (Wunsch des Nutzers: sonst fehlt jeder Hinweis)
  local info, unsure
  if id then info, unsure = ns.TeachInfo(id, ns.Discovering()) end
  -- wie die gelernten Ränge: mit „Bekannte Fähigkeiten anzeigen“ aus nicht zeigen (Wunsch des Nutzers)
  local nothing = info ~= nil and #info == 0 and ns.db.ui.tooltipShowKnown ~= false
  -- Komplettmodus: Weiß noch niemand, was ein wildes Tier lehrt, sagt der Tooltip das, statt zu schweigen (#23,
  -- sonst wirkt es, als könne das Tier nichts). Geprüft wird roh, nicht nach den Einstellungen: ausgeblendete
  -- unsichere Angaben sind keine fehlenden Daten.
  local missing = id and not ns.Discovering() and #ns.ObservationsOf(id) == 0
    and #(ns.AllBeastTeaches(id) or {}) == 0 and wildBeastUnderMouse(guid)
  -- Komplettmodus: Gibt es Angaben unter der Schwelle, bittet eine Zeile um mehr Belege (#40). Auch roh geprüft:
  -- Die Aussage stimmt auch bei ausgeblendeten Angaben, und ohne sie bliebe ein Tier mit nur unsicheren Lehren
  -- stumm. Nach einer eigenen Zähmung ist alles belegt, die Zeile fällt von selbst weg.
  local proof = unsure and not missing and wildBeastUnderMouse(guid)
  if #list == 0 and not status and not nothing and not missing and not proof then return end

  -- Leerzeilen davor und danach trennen die Zeilen von denen anderer Addons (Einstellungen)
  if ns.db.ui.tooltipGapBefore then tooltip:AddLine(" ") end
  tooltip:AddLine("Forever Hunter Pets", 0.62, 0.83, 0.37)
  -- alle Zeilen bündig mit der Kopfzeile (Wunsch des Nutzers)
  if status then tooltip:AddLine(status, 1, 0.82, 0) end
  if nothing then tooltip:AddLine(L["teaches nothing"], 0.6, 0.6, 0.6) end   -- grau wie „gelernt“
  if missing then   -- gold wie der Status
    tooltip:AddLine(L["No hunter knows yet what this beast teaches. Tame it and help!"], 1, 0.82, 0, true)
  end
  if proof then   -- gold wie #23, einmal je Tier
    tooltip:AddLine(L["Hunters need more proof of what this beast teaches. Tame it!"], 1, 0.82, 0, true)
  end
  for _, e in ipairs(list) do
    local text = iconTag(e.a) .. " " .. ns.AbilityName(e.a)
    if not ns.Learnable(e.a) then
      -- angeborenes Angriffstempo, steht vorn: „Schnellerer Angriff III (1,5 s)“, ohne Lernstand
      tooltip:AddLine(text .. " (" .. ns.Decimal(e.a.speed) .. " s)" .. ns.ConfMark(e.conf), 1, 1, 1)
    else
      -- „Beißen (Rang 3)“, nicht belegt „Beißen (Rang 3)?“; ohne Rangnummer nur der Name
      local rank = ns.RankLabel(e.a, e.r)
      text = text .. (rank ~= "" and " (" .. rank .. ")" or "") .. ns.ConfMark(e.conf)
      if not ns.char then
        tooltip:AddLine(text, 1, 1, 1)
      elseif ns.IsKnown(e.r) then
        tooltip:AddLine(text .. " – " .. L["you have it"], 0.6, 0.6, 0.6)
      else
        tooltip:AddLine(text .. " – " .. L["you lack it"], 0.25, 1, 0.25)
      end
    end
  end
  if ns.db.ui.tooltipGapAfter then tooltip:AddLine(" ") end
end

local function hook()
  local function run(tooltip, guid)
    local ok, err = pcall(addLines, tooltip, guid)
    if not ok then ns.ReportError("tooltip", err) end
  end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
      -- nur der gewöhnliche Tooltip, nicht Vergleichs- oder Addon-eigene
      if tooltip == GameTooltip then run(tooltip, data and data.guid) end
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
      local _, unit = self:GetUnit()
      unit = ns.clean(unit)
      if unit then run(self, UnitGUID(unit)) end
    end)
  end
end

ns.On("PLAYER_LOGIN", function() ns.SafeCall("tooltip", hook) end)
