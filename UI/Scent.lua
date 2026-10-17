-- Forever Hunter Pets · Witterung (Plan Entdecken, E7c): die Namen, die „Wildtiere aufspüren“ auf der
-- Minikarte zeigt, geben passenden Tieren der Zone eine Fährte. Angezeigt wird dabei nichts (Wunsch des
-- Nutzers: der Kasten an der Minikarte bliebe sonst überladen; der Tier-Tooltip reicht).
--
-- Der Client schreibt die Namen in den GameTooltip (Besitzer UIParent), alle in Zeile 1, durch Zeilenumbrüche
-- getrennt, gleiche Tiere auch doppelt, und tauscht den Text aus, ohne den Tooltip neu zu zeigen (Spur-Probe,
-- 16.10.2026). „OnEnter“ der Minikarte kommt in Forever nicht an. Deshalb: Erscheint der Tooltip, während die
-- Maus über der Minikarte steht, wird alle POLL Sekunden nachgesehen, bis er verschwindet – sonst nie.
-- Spieler, Pets, Knöpfe und Tiere ohne Fundort in der Zone gehen leer aus (ns.NoteTrack prüft das).
-- Name statt NPC-ID: Mehrere Tiere gleichen Namens bekommen alle die Fährte.
local _, ns = ...

local POLL = 0.2
local ticker, done
local byName, byNameMap   -- Name → { npc, … } der Zone byNameMap; neu bei jedem neuen Tooltip

local function namesIn(map)
  if byName and byNameMap == map then return byName end
  byName, byNameMap = {}, map
  for npc in pairs(ns.BeastsIn(map)) do
    local name = ns.BeastName(npc)
    byName[name] = byName[name] or {}
    table.insert(byName[name], npc)
  end
  return byName
end

local function stop()
  if ticker then ticker:Cancel(); ticker = nil end
  done = nil
end

local function tick()
  if not (GameTooltip:IsShown() and Minimap:IsMouseOver()) then return stop() end
  if GameTooltip:GetOwner() ~= UIParent then return end
  local fs = GameTooltipTextLeft1
  local text = fs and ns.clean(fs:GetText())
  if type(text) ~= "string" or text == "" or text == done then return end
  done = text
  local map = ns.CellHere()
  if not map then return end
  local index = namesIn(map)
  for name in text:gmatch("[^\n]+") do
    for _, npc in ipairs(index[name] or {}) do ns.NoteTrack(npc, map) end
  end
end

local function shown()
  if ticker or not Minimap:IsMouseOver() then return end
  byName = nil   -- neue Sichtungen und Zellen seit dem letzten Mal
  tick()
  ticker = C_Timer.NewTicker(POLL, function() ns.SafeCall("scent", tick) end)
end

ns.On("PLAYER_LOGIN", function()
  if Minimap and GameTooltip and GameTooltip.HookScript and C_Timer and C_Timer.NewTicker then
    GameTooltip:HookScript("OnShow", function() ns.SafeCall("scent", shown) end)
  end
end)
