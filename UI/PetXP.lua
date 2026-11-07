-- Forever Hunter Pets · EP-Leiste und Stufe am Pet-Rahmen des Clients (#120)
-- Eine schmale EP-Leiste direkt unter dem Pet-Rahmen und die Stufe des Pets in einem kleinen Kreis unten links.
-- Beides sind eigene Rahmen des Addons, an PetFrame gehängt; am PetFrame selbst wird nichts verändert (keine
-- Methoden ersetzt, keine Skripte überschrieben, Lehre aus #5). Verbirgt der Client den Pet-Rahmen, verschwinden
-- beide mit ihm. Fehlt PetFrame oder GetPetExperience (anderes Unit-Frame-Addon, API fehlt), passiert nichts.
-- Nur über Ereignisse, kein OnUpdate.
local _, ns = ...
local L = ns.L

local BAR_H = 7
local CELLS = 5                        -- Zellen der Leiste: ein Trennstrich alle 20 % (Wunsch des Maintainers, 07.11.2026)
local XP_COLOR = { 0.0, 0.39, 0.88 }   -- Blau wie die EP-Leiste des Spielers (Wunsch des Maintainers, 07.11.2026)

local function num(v) return tonumber(ns.clean(v)) end

local function call(fn, ...)
  if not fn then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return a, b
end

-- Zahl mit Tausenderpunkten, wie der Client sie schreibt
local function big(n)
  if BreakUpLargeNumbers then
    local s = call(BreakUpLargeNumbers, n)
    if type(s) == "string" then return s end
  end
  return tostring(n)
end

-- Stand des Pets: nil ohne Pet, sonst { level, cur, max, full }. Fehlt ein Wert (geheim oder nicht da), ist er
-- nil; full heißt Höchststufe: Der Client meldet keine EP mehr bis zur nächsten Stufe, oder das Pet hat die
-- Stufe des Jägers erreicht und kann nicht weiter steigen.
function ns.PetXPState()
  if not (UnitExists and ns.clean(call(UnitExists, "pet"))) then return nil end
  local level = UnitLevel and num(call(UnitLevel, "pet"))
  local cur, max = call(GetPetExperience)
  cur, max = num(cur), num(max)
  if not (level or cur) then return nil end
  local hunter = UnitLevel and num(call(UnitLevel, "player"))
  local full = (max ~= nil and max <= 0) or (level ~= nil and hunter ~= nil and level >= hunter)
  return { level = level, cur = cur, max = max, full = full }
end

-- Zeilen für den Tooltip der Leiste
function ns.PetXPTooltip(st)
  if not st then return {} end
  if st.full then
    return { st.level and (L["Level %d – Max"]):format(st.level) or L["Max"] }
  end
  if not (st.cur and st.max and st.max > 0) then return {} end
  local pct = math.floor(st.cur / st.max * 100)
  local out = {}
  if st.level then
    out[1] = (L["Level %d – %s / %s XP (%d%%)"]):format(st.level, big(st.cur), big(st.max), pct)
    out[2] = (L["%s XP to level %d"]):format(big(st.max - st.cur), st.level + 1)
  else
    out[1] = (L["%s / %s XP (%d%%)"]):format(big(st.cur), big(st.max), pct)
  end
  return out
end

-- Was zu zeigen ist, nach Stand und Einstellungen: { bar = bool, fill = 0..1, level = Zahl oder nil }
function ns.PetXPView()
  local ui = (ns.db and ns.db.ui) or {}
  local st = ui.petFrame ~= false and ns.PetXPState() or nil
  local view = { bar = false, fill = 0, level = nil, state = st }
  if not st then return view end
  if ui.petFrameLevel ~= false then view.level = st.level end
  if ui.petFrameXP ~= false and (st.full or (st.cur and st.max and st.max > 0)) then
    view.bar = true
    view.fill = st.full and 1 or math.min(1, math.max(0, st.cur / st.max))
  end
  return view
end

-- ---- Rahmen ----
local bar, badge

-- Wie die EP-Leiste des Spielers: dunkler Rahmen, Trennstriche, hier alle 20 % (CELLS Zellen)
local function line(parent, layer)
  local t = parent:CreateTexture(nil, layer or "OVERLAY")
  t:SetColorTexture(0, 0, 0, 0.9)
  return t
end

local function placeTicks(b)
  local w = b:GetWidth()
  if not (w and w > 0) then return end
  for i, t in ipairs(b.ticks) do
    t:ClearAllPoints()
    t:SetPoint("TOP", b, "TOPLEFT", math.floor(w * i / CELLS + 0.5), 0)
    t:SetPoint("BOTTOM", b, "BOTTOMLEFT", math.floor(w * i / CELLS + 0.5), 0)
  end
end

local function createBar()
  local b = CreateFrame("StatusBar", nil, PetFrame)
  b:SetHeight(BAR_H)
  -- bündig unter der Mana- bzw. Fokusleiste des Pets, gleich breit; der Rahmen liegt außen
  local mana = PetFrameManaBar
  if mana then
    b:SetPoint("TOPLEFT", mana, "BOTTOMLEFT", 0, -2)
    b:SetPoint("TOPRIGHT", mana, "BOTTOMRIGHT", 0, -2)
  else
    b:SetWidth(70)
    b:SetPoint("TOPLEFT", PetFrame, "BOTTOMLEFT", 46, 8)
  end
  b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  b:SetStatusBarColor(XP_COLOR[1], XP_COLOR[2], XP_COLOR[3])
  b:SetMinMaxValues(0, 1)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0, 0, 0, 0.6)
  -- Rahmen: je eine Linie oben, unten, links, rechts, 1 px außerhalb der Leiste
  local top, bottom, left, right = line(b), line(b), line(b), line(b)
  top:SetPoint("BOTTOMLEFT", b, "TOPLEFT", -1, 0); top:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 1, 0); top:SetHeight(1)
  bottom:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -1, 0); bottom:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 1, 0); bottom:SetHeight(1)
  left:SetPoint("TOPRIGHT", b, "TOPLEFT", 0, 0); left:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", 0, 0); left:SetWidth(1)
  right:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, 0); right:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 0, 0); right:SetWidth(1)
  -- Trennstriche zwischen den Zellen, nachgezogen, wenn sich die Breite ändert
  b.ticks = {}
  for i = 1, CELLS - 1 do
    local t = line(b)
    t:SetWidth(1)
    b.ticks[i] = t
  end
  b:SetScript("OnSizeChanged", placeTicks)
  placeTicks(b)
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    local lines = ns.PetXPTooltip(ns.PetXPState())
    if #lines == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(lines[1], 1, 1, 1)
    for i = 2, #lines do GameTooltip:AddLine(lines[i], 0.8, 0.8, 0.8) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:Hide()
  return b
end

-- Kreis aus denselben Texturen wie der Knopf an der Minikarte (UI/Settings.lua), verkleinert
local function createBadge()
  local f = CreateFrame("Frame", nil, PetFrame)
  f:SetSize(32, 32)
  f:SetScale(0.7)
  f:SetPoint("CENTER", PetFrame, "BOTTOMLEFT", 14, 12)
  f:SetFrameLevel((PetFrame:GetFrameLevel() or 0) + 5)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  f.bg:SetSize(22, 22)
  f.bg:SetPoint("CENTER")
  f.border = f:CreateTexture(nil, "OVERLAY")
  f.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  f.border:SetSize(54, 54)
  f.border:SetPoint("TOPLEFT")
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("CENTER", 0, 0)
  f:Hide()
  return f
end

function ns.UpdatePetXP()
  if not bar then return end
  local view = ns.PetXPView()
  if view.bar then
    bar:SetValue(view.fill)
    bar:Show()
  else
    bar:Hide()
  end
  if view.level then
    badge.text:SetText(tostring(view.level))
    badge:Show()
  else
    badge:Hide()
  end
end

local function build()
  if bar or not (PetFrame and GetPetExperience) then return end
  bar, badge = createBar(), createBadge()
  ns.UpdatePetXP()
end

-- für die Prüfung ohne Spiel (tools/test/szenarien/t120-pet-ep.lua)
function ns.PetXPFrames() return bar, badge end

local function update() ns.SafeCall("petxp", ns.UpdatePetXP) end

-- einmal außerhalb des Kampfs erzeugen; nach einem /reload im Kampf, sobald er vorbei ist
ns.On("PLAYER_LOGIN", function()
  if InCombatLockdown and InCombatLockdown() then return end
  ns.SafeCall("petxp", build)
end)
ns.On("PLAYER_REGEN_ENABLED", function() if not bar then ns.SafeCall("petxp", build) end end)
ns.On("PLAYER_ENTERING_WORLD", update)
ns.On("PET_UI_UPDATE", update)
ns.On("PLAYER_LEVEL_UP", update)
ns.On("UNIT_PET_EXPERIENCE", update)
ns.On("UNIT_PET", function(unit) if ns.clean(unit) == "player" then update() end end)
ns.On("UNIT_LEVEL", function(unit)
  unit = ns.clean(unit)
  if unit == "pet" or unit == "player" then update() end
end)
