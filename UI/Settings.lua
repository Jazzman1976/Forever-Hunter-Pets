-- Forever Hunter Pets · Einstellungen im Addon-Menü des Spiels und der Knopf an der Minikarte
local _, ns = ...
local L = ns.L

-- ---- Knopf an der Minikarte: Klick öffnet das Fenster, Strg + Ziehen verschiebt ihn am Ring ----
local mini

-- Addons, die die Minikarte eckig machen, melden das über GetMinimapShape
local function square()
  if not GetMinimapShape then return false end
  local ok, shape = pcall(GetMinimapShape)
  return ok and shape == "SQUARE"
end

local function place()
  local angle = math.rad(ns.db.ui.minimapAngle)
  local x, y = math.cos(angle), math.sin(angle)
  local w, h = Minimap:GetWidth() / 2 + 8, Minimap:GetHeight() / 2 + 8
  if square() then
    -- an der Kante entlang statt auf dem Kreis
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m * (w - 2), y / m * (h - 2)
  else
    x, y = x * w, y * h
  end
  mini:ClearAllPoints()
  mini:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- der Winkel von der Mitte der Minikarte zum Mauszeiger, in Grad
local function cursorAngle()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  px, py = ns.clean(px), ns.clean(py)
  if not (mx and my and px and py) then return nil end
  local scale = Minimap:GetEffectiveScale()
  return math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
end

local function createButton()
  local b = CreateFrame("Button", "ForeverHunterPetsMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  b.bg:SetSize(22, 22)
  b.bg:SetPoint("CENTER")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(ns.AddonIcon())
  b.icon:SetSize(20, 20)
  b.icon:SetPoint("CENTER")
  b.icon:SetTexCoord(ns.AddonIconCoords(0.06))
  -- rund ausschneiden, wo der Client Masken kennt
  pcall(function()
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)
  end)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b.border:SetSize(54, 54)
  b.border:SetPoint("TOPLEFT")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  b:SetScript("OnClick", function() ns.SafeCall("window", ns.Toggle) end)
  b:SetScript("OnDragStart", function(self)
    if not (IsControlKeyDown and IsControlKeyDown()) then return end
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
      local angle = cursorAngle()
      if not angle then return end
      ns.db.ui.minimapAngle = angle
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Forever Hunter Pets", 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Click"], L["Open or close"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Ctrl + drag"], L["Move"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- Zeigt oder versteckt den Knopf nach der Einstellung; gebaut wird er erst, wenn er gebraucht wird
function ns.UpdateMinimapButton()
  if not Minimap then return end
  if ns.db.ui.minimap and not mini then
    mini = createButton()
    place()
  end
  if mini then mini:SetShown(ns.db.ui.minimap and true or false) end
end

-- ---- Seite im Addon-Menü des Spiels (Optionen → AddOns) ----
-- Die Einstellungen lesen und schreiben ns.db.ui selbst; hier folgt nur der Knopf nach.
-- „Filter merken“ braucht das nicht: es wirkt beim nächsten Aufbau des Fensters.
-- Logo oben auf der Seite: ein eigenes Element aus der Vorlage in UI/Settings.xml (#5). Bis 0.8.0 war es
-- eine Überschrift des Clients mit ersetztem InitFrame und GetExtent – damit richtete unser Code Rahmen ein,
-- die sich alle Seiten der Optionen teilen, und der Client blockierte auf fremden Seiten Aktionen („wurde
-- geblockt“, etwa auf „Kontakte“). Jetzt ersetzt das Addon keine Funktion und fasst keinen Rahmen an: Die
-- Vorlage erbt Init von der Überschrift des Clients, die Liste hält für sie einen eigenen Pool.
-- Passt etwas nicht zum Client, bleibt die Seite ohne Logo – lieber kein Logo als eine blockierte Aktion.
local LOGO_TEMPLATE = "ForeverHunterPetsLogoTemplate"
local function addLogo(layout)
  if not (layout and layout.AddInitializer and Settings.CreateElementInitializer
    and CreateSettingsListSectionHeaderInitializer) then return end
  -- Die Vorlage erbt von „SettingsListSectionHeaderTemplate“; nur wenn die Überschrift des Clients so heißt
  local header = CreateSettingsListSectionHeaderInitializer("")
  if not (header and header.GetTemplate and header:GetTemplate() == "SettingsListSectionHeaderTemplate") then return end
  if not (C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(LOGO_TEMPLATE)) then return end
  layout:AddInitializer(Settings.CreateElementInitializer(LOGO_TEMPLATE, { name = "" }))
end

local function registerSettings()
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
  local category, layout = Settings.RegisterVerticalLayoutCategory("Forever Hunter Pets")
  ns.SafeCall("logo", addLogo, layout)
  -- Entdeckermodus je Charakter (Core/Discover.lua); umschalten heißt auch: gewählt
  if ns.char then
    local mode = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_DiscoverMode", "discover", ns.char,
      Settings.VarType.Boolean, L["Explorer mode"], false)
    mode:SetValueChangedCallback(function()
      ns.char.modeChosen = true
      ns.SafeCall("mode", ns.ModeChanged)
    end)
    local modeInit = Settings.CreateCheckbox(category, mode,
      L["Shows only what you have found yourself: beasts you sighted, found or tamed, and what they teach. Abilities and ranks stay visible, and the addon tells you how much there is still to discover. Switched off (complete mode), it shows the complete data. Applies to this character. Tip: with enemy nameplates switched on, the addon notices beasts as you ride past."])
    -- Funde der anderen Charaktere (#43): Unteroption, eingerückt und nur bedienbar im Entdeckermodus
    local shared = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_ShareFinds", "shareFinds", ns.char,
      Settings.VarType.Boolean, L["Show finds of my other characters"], false)
    shared:SetValueChangedCallback(function() ns.SafeCall("mode", ns.ModeChanged) end)
    local sharedInit = Settings.CreateCheckbox(category, shared,
      L["Also counts what your other characters on this account have sighted, found and tamed. Switched off, this character discovers everything on its own."])
    if modeInit and sharedInit and sharedInit.SetParentInitializer then
      pcall(sharedInit.SetParentInitializer, sharedInit, modeInit, function() return ns.char.discover == true end)
    end
  end
  local setting = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_Minimap", "minimap", ns.db.ui,
    Settings.VarType.Boolean, L["Minimap button"], true)
  setting:SetValueChangedCallback(function() ns.SafeCall("minimap", ns.UpdateMinimapButton) end)
  Settings.CreateCheckbox(category, setting,
    L["Shows a button at the minimap that opens Forever Hunter Pets. Hold Ctrl and drag to move it around the minimap."])
  local keep = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_KeepFilters", "keepFilters", ns.db.ui,
    Settings.VarType.Boolean, L["Remember filters"], true)
  Settings.CreateCheckbox(category, keep,
    L["Keeps the filters of the Abilities and Training views (ticks, zone and family) for your next session, separately for each character. Switched off, every session starts with everything shown. Takes effect the next time you log in or reload."])
  local tip = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_Tooltip", "tooltip", ns.db.ui,
    Settings.VarType.Boolean, L["Beast tooltips"], true)
  local tipInit = Settings.CreateCheckbox(category, tip,
    L["Adds to the tooltip of a beast which ranks it teaches and whether you have learned them already, plus its attack speed; in explorer mode also how far you are with this beast."])
  -- Leerzeilen davor und danach, als Unteroptionen: eingerückt und nur bedienbar, solange die Tooltips an sind
  local function sub(key, variable, label, default, text)
    local s = Settings.RegisterAddOnSetting(category, key, variable, ns.db.ui, Settings.VarType.Boolean, label, default)
    local init = Settings.CreateCheckbox(category, s, text)
    if tipInit and init and init.SetParentInitializer then
      pcall(init.SetParentInitializer, init, tipInit, function() return ns.db.ui.tooltip end)
    end
  end
  sub("ForeverHunterPets_TooltipGapBefore", "tooltipGapBefore", L["Empty line before"], true,
    L["Puts an empty line above the addon's lines in the tooltip, to set them apart from other addons."])
  sub("ForeverHunterPets_TooltipGapAfter", "tooltipGapAfter", L["Empty line after"], false,
    L["Puts an empty line below the addon's lines in the tooltip, to set them apart from other addons."])
  sub("ForeverHunterPets_TooltipKnown", "tooltipShowKnown", L["Show known abilities"], true,
    L["Also lists the ranks you have already learned (marked “learned”) and “teaches nothing” for beasts that teach nothing. Switched off, the tooltip only shows what is new to you and the attack speed."])
  -- Belegung der Lehrtiere: unsicher und unbelegt sind standardmäßig aus. Wer sie einschaltet, liest
  -- hier, was „?“ und „!“ bedeuten; in Liste und Tooltip steht dazu kein Erklärtext.
  local function conf(key, variable, label, text)
    local s = Settings.RegisterAddOnSetting(category, key, variable, ns.db.ui, Settings.VarType.Boolean, label, false)
    s:SetValueChangedCallback(function() ns.SafeCall("conf", ns.ShowConfChanged) end)
    Settings.CreateCheckbox(category, s, text)
  end
  conf("ForeverHunterPets_ShowUncertain", "showUncertain", L["Show uncertain beasts"],
    L["Also lists beasts that fewer than 3 other players have reported so far. In all views and in the tooltip they are marked with “?”."])
  -- unbelegt heißt geschätzt; solange die Daten keine Schätzung enthalten, fehlt der Schalter
  if ns.HasUnproven() then
    conf("ForeverHunterPets_ShowUnproven", "showUnproven", L["Show unproven beasts"],
      L["Also lists beasts that are only estimated and have not been seen yet. In all views and in the tooltip they are marked with “!”."])
  end
  -- Lernstand von Hand: standardmäßig aus, damit kein Häkchen aus Versehen gesetzt wird
  local manual = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_ManualEdit", "manualEdit", ns.db.ui,
    Settings.VarType.Boolean, L["Manual editing"], false)
  manual:SetValueChangedCallback(function() ns.SafeCall("manual", ns.ShowConfChanged) end)   -- Liste neu aufbauen
  Settings.CreateCheckbox(category, manual,
    L["Lets you tick or untick ranks as learned by hand in the Abilities view. Usually not needed: the addon picks up what you learn from the Beast Training window and the game's messages. Switched off, the boxes only show what you know."])
  local share = Settings.RegisterAddOnSetting(category, "ForeverHunterPets_Share", "share", ns.db.ui,
    Settings.VarType.Boolean, L["Share observations"], true)
  share:SetValueChangedCallback(function() ns.SafeCall("share", ns.ShareChanged) end)
  Settings.CreateCheckbox(category, share,
    L["When you target or tame a beast, the addon notes what you see and shares it with other players of the addon (guild, group and a hidden channel). Sent are: the beast with its name, level and family, the abilities and attack speed it brought along, where you saw it (rounded to about 100 m), the time, and a short code instead of your name. What others report counts once 3 different players saw the same. Switched off, nothing is sent or received."])
  Settings.RegisterAddOnCategory(category)
  ns.settingsCategory = category
end

-- Öffnet Optionen → AddOns direkt auf unserer Seite; das Addon-Fenster geht dabei zu, sonst läge es darüber
function ns.OpenSettings()
  local category = ns.settingsCategory
  if not (category and Settings and Settings.OpenToCategory) then return end
  if ns.frame then ns.frame:Hide() end
  local id = category.GetID and category:GetID() or category.ID
  Settings.OpenToCategory(id)
end

ns.On("PLAYER_LOGIN", function()
  ns.SafeCall("settings", registerSettings)
  ns.SafeCall("minimap", ns.UpdateMinimapButton)
end)
