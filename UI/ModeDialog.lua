-- Forever Hunter Pets · Startdialog: Komplett- oder Entdeckermodus (Meilenstein M2, Inkrement E2).
-- Erscheint, wenn ein Charakter das Addon öffnet, der noch keinen Modus gewählt hat – jeder Charakter wird
-- einmal gefragt. Bis zur Wahl zeigt das Addon nichts, was spoilern könnte. Der Entdeckermodus steht oben und
-- ist empfohlen; wer den Dialog ohne Wahl schließt (ESC), hat ihn gewählt (#42). Zeigt /fhp start den Dialog
-- bei schon gewähltem Modus, ändert Schließen nichts.
local _, ns = ...
local L = ns.L
local W = ns.W

local DW = 520
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

  -- Hinweis zur Beta, „Beta“ als Wort in Gold. Bis 1.0.0 – zum Release 1.0.0 entfernen
  -- (docs/konzept/konzept.md, Meilensteine und Stand)
  local beta = W.Text(f, "GameFontHighlightSmall", true)
  beta:SetPoint("TOPLEFT", 16, y)
  beta:SetWidth(DW - 32)
  beta:SetText("|cffffd100" .. L["Beta"] .. "|r – "
    .. L["Forever Hunter Pets is still young, and hunters are gathering its knowledge right now. Some beasts, ranks or spawn points may still be missing or incomplete. That isn't broken – it's just waiting to be discovered. Every time you play with the addon, you help fill the gaps for everyone. Thank you, and happy hunting!"])
  y = y - beta:GetStringHeight() - 16

  -- zwei Wahlmöglichkeiten untereinander, der Entdeckermodus zuerst: Knopf, daneben die Erklärung
  for _, c in ipairs({
    { true, L["Explorer mode"], L["Recommended. Track the beasts down yourself: every beast you sight, find and tame is added to the Zone tab, your guide to the beasts of each zone. This is what the addon is made for."] },
    { false, L["Complete mode"], L["If you would rather not search: shows everything hunters have identified with the addon so far. You see all details at once, but part of the fun is lost."] },
  }) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(180, 26)
    b:SetPoint("TOPLEFT", 16, y)
    b:SetText(c[2])
    b:SetScript("OnClick", function() ns.SafeCall("mode", choose, c[1]) end)
    local text = W.Text(f, "GameFontHighlightSmall", true)
    text:SetPoint("TOPLEFT", b, "TOPRIGHT", 12, 0)
    text:SetWidth(DW - 180 - 16 * 2 - 12)
    text:SetText(c[3])
    y = y - math.max(26, text:GetStringHeight()) - 14
  end

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
