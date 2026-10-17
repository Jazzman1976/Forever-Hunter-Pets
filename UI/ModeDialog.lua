-- Forever Hunter Pets · Startdialog: Komplett- oder Entdeckermodus (Meilenstein M2, Inkrement E2).
-- Erscheint, wenn ein Charakter das Addon öffnet, der noch keinen Modus gewählt hat – jeder Charakter wird
-- einmal gefragt. Bis zur Wahl zeigt das Addon nichts, was spoilern könnte. ESC schließt ohne Wahl.
local _, ns = ...
local L = ns.L
local W = ns.W

local DW, DH = 520, 330
local LOGO = "Interface\\AddOns\\Forever-Hunter-Pets\\media\\logo"
local dialog, after

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

local function choose(discover)
  ns.SetMode(discover)
  local fn = after   -- vor dem Ausblenden: OnHide löscht die Folgeaktion (für ESC ohne Wahl)
  dialog:Hide()
  if fn then ns.SafeCall("window", fn) end
end

local function create()
  local f = CreateFrame("Frame", "ForeverHunterPetsModeDialog", UIParent)
  f:SetSize(DW, DH)
  f:SetPoint("CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:Hide()
  table.insert(UISpecialFrames, "ForeverHunterPetsModeDialog")
  W.Fill(f, 0.06, 0.07, 0.09, 1, "BACKGROUND")
  border(f)

  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(96, 96)
  logo:SetPoint("TOPLEFT", 16, -16)
  logo:SetTexture(LOGO)

  local title = W.Text(f, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 16, -4)
  title:SetText(L["How do you want to play?"])
  local intro = W.Text(f, "GameFontHighlight", true)
  intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  intro:SetWidth(DW - 96 - 16 * 3)
  intro:SetText(L["Forever Hunter Pets can show you everything that is known – or only what you find yourself."])

  -- zwei Wahlmöglichkeiten untereinander: Knopf, darunter ein Satz Erklärung
  local y = -16 - 96 - 20
  for _, c in ipairs({
    { false, L["Complete mode"], L["Shows the complete data – you don't have to search for anything."] },
    { true, L["Explorer mode"], L["Shows only what you have found yourself, and how much there is still to discover."] },
  }) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(180, 26)
    b:SetPoint("TOPLEFT", 16, y)
    b:SetText(c[2])
    b:SetScript("OnClick", function() ns.SafeCall("mode", choose, c[1]) end)
    local text = W.Text(f, "GameFontHighlightSmall", true)
    text:SetPoint("LEFT", b, "RIGHT", 12, 0)
    text:SetWidth(DW - 180 - 16 * 2 - 12)
    text:SetText(c[3])
    y = y - 44
  end

  local note = W.Text(f, "GameFontDisableSmall", true)
  note:SetPoint("BOTTOMLEFT", 16, 16)
  note:SetWidth(DW - 32)
  note:SetText(L["You can change this for this character at any time in the settings."])

  f:SetScript("OnHide", function() after = nil end)
  return f
end

-- Zeigt den Dialog; onChosen läuft nach der Wahl (etwa: das Fenster öffnen)
function ns.ShowModeDialog(onChosen)
  if not dialog then dialog = create() end
  after = onChosen
  dialog:Show()
end
