-- Forever Hunter Pets · das Fenster: verschiebbar, merkt sich seine Position, schließt mit ESC
local _, ns = ...
local L = ns.L

local W, H = 900, 632
local PAD, TOP = 12, 44
ns.CONTENT_W, ns.CONTENT_H = W - 2 * PAD, H - TOP - PAD
local main

local function border(f)
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 0, 0, 1)
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1)
      t:SetPoint(side .. "LEFT")
      t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(1)
      t:SetPoint("TOP" .. side)
      t:SetPoint("BOTTOM" .. side)
    end
  end
end

local function create()
  local f = CreateFrame("Frame", "ForeverHunterPetsFrame", UIParent)
  f:SetSize(W, H)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  local pos = ns.db.ui.pos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER") end
  f:SetScript("OnDragStart", function(self)
    if ns.OnFrameMoveStart then ns.OnFrameMoveStart() end
    self:StartMoving()
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.ui.pos = { p, rp, x, y }
    if ns.OnFrameMoved then ns.OnFrameMoved() end
  end)
  f:Hide()
  table.insert(UISpecialFrames, "ForeverHunterPetsFrame")

  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.bg:SetColorTexture(0.06, 0.07, 0.09, 1)
  border(f)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(24, 24)
  f.icon:SetPoint("TOPLEFT", 12, -10)
  f.icon:SetTexture(ns.AddonIcon())
  f.icon:SetTexCoord(ns.AddonIconCoords(0.08))

  f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.close:SetPoint("TOPRIGHT", -2, -2)

  -- Zahnrad links neben dem Schließen-Knopf: öffnet die Einstellungen des Addons
  f.gear = CreateFrame("Button", nil, f)
  f.gear:SetSize(20, 20)
  f.gear:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
  f.gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  f.gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  f.gear:SetScript("OnClick", function() ns.SafeCall("settings", ns.OpenSettings) end)
  f.gear:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L["Settings"], 1, 1, 1)
    GameTooltip:Show()
  end)
  f.gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- vor dem Zahnrad: welcher Modus gilt (Wunsch des Nutzers); vor der Wahl im Startdialog nichts
  f.mode = ns.W.Text(f, "GameFontDisableSmall")
  f.mode:SetPoint("RIGHT", f.gear, "LEFT", -6, 0)
  local function showMode()
    f.mode:SetText(not ns.ModeChosen() and "" or ns.Discovering() and L["Explorer mode"] or L["Complete mode"])
  end
  showMode()
  ns.OnModeChanged(showMode)
  -- Hover erklärt den Modus und wirbt für den Entdeckermodus, Klick öffnet die Einstellungen (#42). Die Schrift
  -- selbst empfängt keine Maus, deshalb ein unsichtbarer Knopf darüber; ohne Text (vor der Wahl) ist er 0 breit.
  f.modeHover = CreateFrame("Button", nil, f)
  f.modeHover:SetAllPoints(f.mode)
  f.modeHover:SetScript("OnClick", function() ns.SafeCall("settings", ns.OpenSettings) end)
  f.modeHover:SetScript("OnEnter", function(self)
    if not ns.ModeChosen() then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if ns.Discovering() then
      GameTooltip:SetText(L["Explorer mode"], 1, 1, 1)
      GameTooltip:AddLine(L["You are in explorer mode – our recommendation. If you would rather see all details right away, switch explorer mode off in the settings."], 0.8, 0.8, 0.8, true)
    else
      GameTooltip:SetText(L["Complete mode"], 1, 1, 1)
      GameTooltip:AddLine(L["You are in complete mode. There are no challenges here and no hunt of your own, but you see all details. Why not give explorer mode a try?"], 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(L["Click: open the settings"], 0.4, 0.8, 1)
    GameTooltip:Show()
  end)
  f.modeHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Inhaltsbereich unter der Titelzeile, je Ansicht ein eigener Rahmen an derselben Stelle
  f.content = CreateFrame("Frame", nil, f)
  f.content:SetPoint("TOPLEFT", PAD, -TOP)
  f.content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  local function pane()
    local p = CreateFrame("Frame", nil, f.content)
    p:SetAllPoints()
    return p
  end
  local abilitiesPane, trainingPane, areaPane = pane(), pane(), pane()

  f.abilities = ns.BuildAbilities(abilitiesPane)
  f.training = ns.BuildTraining(trainingPane)
  f.area = ns.BuildArea(areaPane)

  -- Reiter links in der Titelzeile; die Filter gehören der Ansicht „Fähigkeiten“ und sitzen dort
  local tabs = {}
  local function show(key)
    ns.db.ui.view = key
    abilitiesPane:SetShown(key == "abilities")
    trainingPane:SetShown(key == "training")
    areaPane:SetShown(key == "area")
    for k, tab in pairs(tabs) do
      local on = k == key
      if on then tab.bg:SetColorTexture(0.62, 0.83, 0.37, 0.35) else tab.bg:SetColorTexture(1, 1, 1, 0.06) end
      if on then tab.label:SetTextColor(1, 1, 1) else tab.label:SetTextColor(1, 0.82, 0) end
    end
    if key == "training" then f.training:Render() end
    if key == "area" then f.area:Render() end
  end
  local x = 8
  -- Reihenfolge: Fähigkeiten, Gebiet, Ausbildung (Wunsch des Nutzers, 16.10.2026)
  for _, t in ipairs({ { "abilities", L["Abilities"] }, { "area", L["Zone"] }, { "training", L["Training"] } }) do
    local tab = CreateFrame("Button", nil, f)
    tab.bg = ns.W.Fill(tab, 1, 1, 1, 0.06)
    tab.hl = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.hl:SetAllPoints()
    tab.hl:SetColorTexture(1, 1, 1, 0.08)
    tab.label = ns.W.Text(tab, "GameFontNormal")
    tab.label:SetPoint("CENTER")
    tab.label:SetText(t[2])
    tab:SetSize(tab.label:GetStringWidth() + 28, 24)
    tab:SetPoint("LEFT", f.icon, "RIGHT", x, 0)
    tab:SetScript("OnClick", function() show(t[1]) end)
    tabs[t[1]] = tab
    x = x + tab:GetWidth() + 4
  end

  f:SetScript("OnShow", function()
    if trainingPane:IsShown() then f.training:Render() end
    if areaPane:IsShown() then f.area:Render() end
  end)

  local view = ns.db.ui.view
  show((view == "training" or view == "area") and view or "abilities")
  return f
end

function ns.Toggle()
  -- ein Charakter ohne gewählten Modus wird erst gefragt (UI/ModeDialog.lua), damit nichts spoilert
  if not ns.ModeChosen() then
    ns.ShowModeDialog(ns.Toggle)
    return
  end
  if not main then
    main = create()
    ns.frame = main
  end
  main:SetShown(not main:IsShown())
end
