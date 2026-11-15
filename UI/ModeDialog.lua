-- Forever Hunter Pets · Startdialog: Komplett- oder Entdeckermodus (Meilenstein M2, Inkrement E2).
-- Erscheint, wenn ein Charakter das Addon öffnet, der noch keinen Modus gewählt hat – jeder Charakter wird
-- einmal gefragt. Bis zur Wahl zeigt das Addon nichts, was spoilern könnte. Beide Modi stehen nebeneinander, je
-- mit Icon, Beschreibung und Knopf, ohne Empfehlung (#177). Wer den Dialog ohne Wahl schließt (ESC), bekommt den
-- Entdeckermodus, den Standard (#42). Zeigt /fhp start den Dialog bei schon gewähltem Modus, ändert Schließen nichts.
local _, ns = ...
local L = ns.L
local W = ns.W

local DW, GAP = 640, 24
local COL = (DW - 16 * 2 - GAP) / 2   -- Breite einer Spalte
local ICON = 56
local LOGO = "Interface\\AddOns\\Forever-Hunter-Pets\\media\\logo"
-- Icons aus dem Client: Fernrohr für die eigene Suche, Buch für das komplette Wissen
local SPYGLASS = "Interface\\Icons\\INV_Misc_Spyglass_02"
local BOOK = "Interface\\Icons\\INV_Misc_Book_09"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
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
  local fn = after   -- vor dem Ausblenden: OnHide löscht die Folgeaktion
  dialog:Hide()
  if fn then ns.SafeCall("window", fn) end
end

-- Geschlossen ohne Wahl: Entdeckermodus, danach wie nach einem Klick die Folgeaktion. War schon ein Modus
-- gewählt (nach einem Klick oder bei /fhp start), bleibt alles, wie es ist.
local function closed()
  local fn = after
  after = nil
  if ns.ModeChosen() then return end
  ns.SetMode(true)
  if fn then ns.SafeCall("window", fn) end
end

local function create()
  local f = CreateFrame("Frame", "ForeverHunterPetsModeDialog", UIParent)
  f:SetWidth(DW)
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
  intro:SetText(L["Forever Hunter Pets turns finding pets into a hunt of your own – or simply shows you everything that is known."])

  -- Die Höhe folgt den Texten (je nach Sprache verschieden lang): y läuft von oben nach unten mit
  local y = -16 - math.max(96, 4 + title:GetStringHeight() + 10 + intro:GetStringHeight()) - 14

  -- zwei Spalten nebeneinander: Icon, Name, Beschreibung, Knopf. Die Knöpfe stehen auf einer Höhe, deshalb
  -- richten sich beide Spalten nach der längeren Beschreibung.
  local cols = {
    { true, SPYGLASS, L["Explorer mode"], L["You go hunting yourself: the addon reveals the information only bit by bit. First you see that a beast exists, then its name, then whether it teaches something, and once you have tamed it, what it teaches. Everything you see, find and tame fills the Zone tab."] },
    { false, BOOK, L["Complete mode"], L["You find every piece of information right away: every beast, what it teaches and where it lives. In return you may get spoiled, and nothing is left for you to discover yourself."] },
  }
  local top, bottom = y, y
  for i, c in ipairs(cols) do
    local x = 16 + (i - 1) * (COL + GAP)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("TOP", f, "TOPLEFT", x + COL / 2, top)
    icon:SetTexture(c[2])
    -- rund ausschneiden wie der Knopf an der Minikarte, wo der Client Masken kennt
    pcall(function()
      local mask = f:CreateMaskTexture()
      mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(icon)
      icon:AddMaskTexture(mask)
    end)
    local name = W.Text(f, "GameFontNormalLarge")
    name:SetPoint("TOP", icon, "BOTTOM", 0, -8)
    name:SetText(c[3])
    local ty = top - ICON - 8 - name:GetStringHeight() - 8
    local text = W.Text(f, "GameFontHighlightSmall", true)
    text:SetPoint("TOPLEFT", x, ty)
    text:SetWidth(COL)
    text:SetText(c[4])
    bottom = math.min(bottom, ty - text:GetStringHeight())
  end
  for i, c in ipairs(cols) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(180, 26)
    b:SetPoint("TOP", f, "TOPLEFT", 16 + (i - 1) * (COL + GAP) + COL / 2, bottom - 12)
    b:SetText(c[3])
    b:SetScript("OnClick", function() ns.SafeCall("mode", choose, c[1]) end)
  end
  y = bottom - 12 - 26 - 18

  -- die Daten wachsen noch (#177): damit niemand eine Lücke für einen Fehler hält
  local data = W.Text(f, "GameFontHighlightSmall", true)
  data:SetPoint("TOPLEFT", 16, y)
  data:SetWidth(DW - 32)
  data:SetText(L["The data is still being collected and grows more complete over time. So don't be surprised if something is still missing."])
  y = y - data:GetStringHeight() - 10

  local chars = W.Text(f, "GameFontHighlightSmall", true)
  chars:SetPoint("TOPLEFT", 16, y)
  chars:SetWidth(DW - 32)
  chars:SetText(L["Each character discovers on its own. In the settings you can show what your other characters have found."])
  y = y - chars:GetStringHeight() - 10

  -- Hinweis zum Teilen und zur Veröffentlichung (#49); fehlt, wenn Teilen schon aus ist
  local share = W.Text(f, "GameFontHighlightSmall", true)
  share:SetPoint("TOPLEFT", 16, y)
  share:SetWidth(DW - 32)
  share:SetText(L["Sharing is on: what you see and tame is shared with other players of the addon, and once enough of them have confirmed it, it becomes part of the addon's data under the MIT license. You can switch this off in the settings."])

  local note = W.Text(f, "GameFontDisableSmall", true)
  note:SetWidth(DW - 32)
  note:SetText(L["You can change this for this character at any time in the settings."])

  -- beim Zeigen: Teilen kann sich seit dem letzten Mal geändert haben
  function f.Layout()
    local on = not (ns.db and ns.db.ui and ns.db.ui.share == false)
    share:SetShown(on)
    local ny = on and y - share:GetStringHeight() - 10 or y
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", 16, ny)
    f:SetHeight(-ny + note:GetStringHeight() + 16)
  end

  f:SetScript("OnHide", function() ns.SafeCall("mode", closed) end)
  return f
end

-- Zeigt den Dialog; onChosen läuft nach der Wahl (etwa: das Fenster öffnen)
function ns.ShowModeDialog(onChosen)
  if not dialog then dialog = create() end
  after = onChosen
  dialog.Layout()
  dialog:Show()
end

-- ---- /fhp modus (#179) ----
-- Umschalten über dieselbe Einstellung wie im Menü, damit das Häkchen gleich den neuen Stand zeigt; deren Rückruf
-- setzt modeChosen und baut alle Ansichten neu (ns.ModeChanged). Ohne Einstellung (alter Client) über ns.SetMode.
local function switchTo(discover)
  if ns.modeSetting then ns.modeSetting:SetValue(discover) else ns.SetMode(discover) end
  ns.Print(discover and L["You are now in explorer mode."] or L["You are now in complete mode."])
end

-- Aus dem Entdeckermodus erst nach Rückfrage, denn der Komplettmodus verrät alles; zurück sofort. Ohne gewählten
-- Modus die Startansicht. Der Befehl steht nur in der Hilfe, beworben wird er nirgends.
function ns.ModeCommand()
  if not ns.ModeChosen() then
    ns.ShowModeDialog()
    return
  end
  if not ns.Discovering() then
    switchTo(true)
    return
  end
  StaticPopupDialogs.FOREVERHUNTERPETS_COMPLETE_MODE = StaticPopupDialogs.FOREVERHUNTERPETS_COMPLETE_MODE or {
    text = L["Switch to complete mode? Then you see everything that is known right away, including what you have not discovered yet."],
    button1 = L["Switch"],
    button2 = L["Cancel"],
    OnAccept = function() ns.SafeCall("mode", switchTo, false) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  StaticPopup_Show("FOREVERHUNTERPETS_COMPLETE_MODE")
end
