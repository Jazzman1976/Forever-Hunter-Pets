-- Forever Hunter Pets · kleine Bausteine für die Oberfläche: Fläche, Text, Icon, Scrollbereich, Pool
local _, ns = ...

local W = {}
ns.W = W

function W.Fill(frame, r, g, b, a, layer)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

-- Markierung der gewählten Zeile, in allen Reitern gleich: Füllung und links ein Strich, damit die Wahl
-- nicht nur an der Farbe hängt (#59). Das Ergebnis schaltet mit SetShown beides zusammen.
function W.Selection(frame)
  local fill = W.Fill(frame, 0.62, 0.83, 0.37, 0.2)
  local bar = frame:CreateTexture(nil, "ARTWORK")
  bar:SetColorTexture(0.62, 0.83, 0.37, 1)
  bar:SetWidth(3)
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("BOTTOMLEFT")
  local sel = {}
  function sel:SetShown(on)
    fill:SetShown(on)
    bar:SetShown(on)
  end
  sel:SetShown(false)
  return sel
end

function W.Text(parent, font, wrap)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(wrap and true or false)
  return fs
end

function W.Icon(parent, size)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size, size)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  return t
end

-- Kästchen für einen Haken: ein Knopf, der Haken liegt in box.check
function W.CheckBox(parent)
  local box = CreateFrame("Button", nil, parent)
  box:SetSize(18, 18)
  W.Fill(box, 0, 0, 0, 0.5)
  box.rim = box:CreateTexture(nil, "BORDER")
  box.rim:SetAllPoints()
  box.rim:SetColorTexture(1, 1, 1, 0.15)
  box.inner = box:CreateTexture(nil, "ARTWORK")
  box.inner:SetPoint("TOPLEFT", 1, -1)
  box.inner:SetPoint("BOTTOMRIGHT", -1, 1)
  box.inner:SetColorTexture(0.05, 0.05, 0.06, 1)
  box.check = box:CreateTexture(nil, "OVERLAY")
  box.check:SetSize(22, 22)
  box.check:SetPoint("CENTER", 1, 1)
  box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  return box
end

-- Scrollbereich fester Größe mit schmalem Balken. Inhalt an sf.content hängen und die Höhe
-- über sf:SetContentHeight melden.
local BAR_W = 4
function W.Scroll(parent, width, height)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  sf:SetSize(width, height)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(width - BAR_W - 6, 10)
  sf:SetScrollChild(content)
  sf.content = content
  sf.contentWidth = width - BAR_W - 6

  local thumb = sf:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(1, 1, 1, 0.25)
  thumb:SetWidth(BAR_W)

  function sf:MaxScroll()
    return math.max(0, content:GetHeight() - height)
  end
  function sf:UpdateThumb()
    local max = self:MaxScroll()
    if max <= 0 then thumb:Hide(); return end
    local th = math.max(24, height * height / content:GetHeight())
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(self:GetVerticalScroll() / max) * (height - th))
    thumb:Show()
  end
  function sf:ScrollTo(v)
    self:SetVerticalScroll(math.max(0, math.min(self:MaxScroll(), v or 0)))
    self:UpdateThumb()
  end
  function sf:SetViewHeight(h)
    height = h
    self:SetHeight(h)
    self:ScrollTo(self:GetVerticalScroll())
  end
  function sf:SetContentHeight(h)
    content:SetHeight(math.max(1, h))
    self:ScrollTo(self:GetVerticalScroll())
  end

  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, delta) self:ScrollTo(self:GetVerticalScroll() - delta * 60) end)
  return sf
end

-- Auswahlliste: ein Knopf mit dem gewählten Eintrag, darunter klappt eine scrollbare Liste auf.
-- options = { { value = …, label = "…" }, … }; onSelect(value) läuft bei jeder Wahl.
-- dd:SetOptions(options) tauscht die Einträge aus (der Reiter „Gebiet“ lernt neue Gebiete dazu, #22).
local DD_ROW, DD_MAX = 20, 320
function W.Dropdown(parent, width, options, onSelect)
  local dd = CreateFrame("Button", nil, parent)
  dd:SetSize(width, 24)
  W.Fill(dd, 1, 1, 1, 0.08)
  dd.hl = dd:CreateTexture(nil, "HIGHLIGHT")
  dd.hl:SetAllPoints()
  dd.hl:SetColorTexture(1, 1, 1, 0.08)
  dd.label = W.Text(dd, "GameFontHighlightSmall")
  dd.label:SetPoint("LEFT", 8, 0)
  dd.label:SetPoint("RIGHT", -20, 0)
  dd.arrow = dd:CreateTexture(nil, "ARTWORK")
  dd.arrow:SetSize(12, 12)
  dd.arrow:SetPoint("RIGHT", -5, -1)
  dd.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  dd.arrow:SetRotation(-math.pi / 2)

  -- Unsichtbare Fläche über dem ganzen Bildschirm: ein Klick daneben schließt die Liste
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:Hide()
  catcher:SetScript("OnClick", function(self) self:Hide() end)

  local height = math.max(DD_ROW, math.min(#options * DD_ROW, DD_MAX))
  local popup = CreateFrame("Frame", nil, catcher)
  popup:SetSize(width + 8, height + 8)
  popup:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  popup:EnableMouse(true)
  W.Fill(popup, 0, 0, 0, 1, "BACKGROUND")
  local inner = popup:CreateTexture(nil, "BORDER")
  inner:SetPoint("TOPLEFT", 1, -1)
  inner:SetPoint("BOTTOMRIGHT", -1, 1)
  inner:SetColorTexture(0.1, 0.11, 0.14, 1)
  local scroll = W.Scroll(popup, width, height)
  scroll:SetPoint("TOPLEFT", 4, -4)

  local rows, count = {}, 0
  function dd:SetValue(value)
    self.value = value
    for i = 1, count do
      local row = rows[i]
      local on = row.option.value == value
      if on then
        self.label:SetText(row.option.label)
        row.label:SetTextColor(1, 0.82, 0)
      else
        row.label:SetTextColor(1, 1, 1)
      end
    end
  end

  -- Zeilen werden wiederverwendet; überzählige bleiben versteckt
  function dd:SetOptions(list)
    for i, option in ipairs(list) do
      local row = rows[i]
      if not row then
        row = CreateFrame("Button", nil, scroll.content)
        row:SetHeight(DD_ROW)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * DD_ROW)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * DD_ROW)
        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.1)
        row.label = W.Text(row, "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 6, 0)
        row:SetScript("OnClick", function(self)
          catcher:Hide()
          dd:SetValue(self.option.value)
          onSelect(self.option.value)
        end)
        rows[i] = row
      end
      row.option = option
      row.label:SetText(option.label)
      row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    count = #list
    height = math.max(DD_ROW, math.min(count * DD_ROW, DD_MAX))
    popup:SetHeight(height + 8)
    scroll:SetViewHeight(height)
    scroll:SetContentHeight(count * DD_ROW)
    self:SetValue(self.value)
  end
  dd:SetOptions(options)

  dd:SetScript("OnClick", function() catcher:SetShown(not catcher:IsShown()) end)
  dd:SetScript("OnHide", function() catcher:Hide() end)
  dd:SetValue(options[1] and options[1].value)
  return dd
end

-- Mehrfachauswahl: ein Knopf mit Titel und Zähler, darunter klappt eine Liste mit Häkchen auf, die
-- beim Anhaken offen bleibt. options = { { key = "…", label = "…", tip = "…" }, { header = "…" }, … };
-- anfangs ist alles angehakt. onChange(key, checked) läuft bei jedem Umschalten.
local MD_ROW = 22
-- width nil: so schmal, wie die längste Aufschrift („Anzeigen: 88 von 88“) es zulässt – in allen Ansichten gleich
function W.MultiDropdown(parent, width, title, options, onChange)
  local L = ns.L
  local dd = CreateFrame("Button", nil, parent)
  W.Fill(dd, 1, 1, 1, 0.08)
  dd.hl = dd:CreateTexture(nil, "HIGHLIGHT")
  dd.hl:SetAllPoints()
  dd.hl:SetColorTexture(1, 1, 1, 0.08)
  dd.label = W.Text(dd, "GameFontHighlightSmall")
  dd.label:SetPoint("LEFT", 8, 0)
  dd.label:SetPoint("RIGHT", -20, 0)
  if not width then
    dd.label:SetText(title .. ": " .. (L["%d of %d"]):format(88, 88))
    width = math.ceil(dd.label:GetStringWidth()) + 8 + 20 + 4
  end
  dd:SetSize(width, 24)
  dd.arrow = dd:CreateTexture(nil, "ARTWORK")
  dd.arrow:SetSize(12, 12)
  dd.arrow:SetPoint("RIGHT", -5, -1)
  dd.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  dd.arrow:SetRotation(-math.pi / 2)

  -- Unsichtbare Fläche über dem ganzen Bildschirm: ein Klick daneben schließt die Liste
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:Hide()
  catcher:SetScript("OnClick", function(self) self:Hide() end)

  local popup = CreateFrame("Frame", nil, catcher)
  popup:SetSize(width + 8, #options * MD_ROW + 8)
  popup:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  popup:EnableMouse(true)
  W.Fill(popup, 0, 0, 0, 1, "BACKGROUND")
  local inner = popup:CreateTexture(nil, "BORDER")
  inner:SetPoint("TOPLEFT", 1, -1)
  inner:SetPoint("BOTTOMRIGHT", -1, 1)
  inner:SetColorTexture(0.1, 0.11, 0.14, 1)

  -- Der Knopf nennt, wie viele Häkchen gesetzt sind: zugeklappt sieht man sie nicht
  local rows = {}
  local function update()
    local on, all = 0, 0
    for _, row in pairs(rows) do
      all = all + 1
      if row.checked then on = on + 1 end
    end
    dd.label:SetText(title .. ": " .. (on == all and L["all"] or (L["%d of %d"]):format(on, all)))
  end

  -- setzt ein Häkchen, ohne onChange zu rufen
  function dd:SetChecked(key, on)
    local row = rows[key]
    if not row then return end
    row.checked = on and true or false
    row.box.check:SetShown(row.checked)
    update()
  end

  for i, option in ipairs(options) do
    local y = -4 - (i - 1) * MD_ROW
    if option.header then
      local head = W.Text(popup, "GameFontDisableSmall")
      head:SetPoint("TOPLEFT", 8, y - 6)
      head:SetText(option.header)
    else
      local row = CreateFrame("Button", nil, popup)
      row:SetHeight(MD_ROW)
      row:SetPoint("TOPLEFT", 4, y)
      row:SetPoint("TOPRIGHT", -4, y)
      row.hl = row:CreateTexture(nil, "HIGHLIGHT")
      row.hl:SetAllPoints()
      row.hl:SetColorTexture(1, 1, 1, 0.1)
      row.box = W.CheckBox(row)
      row.box:SetPoint("LEFT", 4, 0)
      row.box:EnableMouse(false)   -- der Klick gilt der ganzen Zeile
      row.label = W.Text(row, "GameFontHighlightSmall")
      row.label:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
      row.label:SetText(option.label)
      row.checked = true
      row:SetScript("OnClick", function(self)
        dd:SetChecked(option.key, not self.checked)
        onChange(option.key, self.checked)
      end)
      row:SetScript("OnEnter", function(self)
        if not option.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(option.label, 1, 1, 1)
        GameTooltip:AddLine(option.tip, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
      rows[option.key] = row
    end
  end
  -- Die aufgeklappte Liste darf breiter sein als der Knopf: so breit wie ihr längster Eintrag
  local need = width + 8
  for _, row in pairs(rows) do
    need = math.max(need, 4 + 4 + math.ceil(row.box:GetWidth()) + 6 + math.ceil(row.label:GetStringWidth()) + 8 + 4)
  end
  popup:SetWidth(need)

  dd:SetScript("OnClick", function() catcher:SetShown(not catcher:IsShown()) end)
  dd:SetScript("OnHide", function() catcher:Hide() end)
  update()
  return dd
end

-- Sortierschlüssel für Namen: Umlaute wie ihre Grundbuchstaben, Groß- und Kleinschreibung egal
local FOLD = { ["ä"] = "a", ["ö"] = "o", ["ü"] = "u", ["Ä"] = "a", ["Ö"] = "o", ["Ü"] = "u", ["ß"] = "ss" }
function W.SortKey(s)
  return (tostring(s):gsub("[\195][\128-\191]", FOLD)):lower()
end

-- Wiederverwendbare Rahmen: Reset() gibt alle zurück, Get() liefert den nächsten freien
function W.Pool(create)
  local pool = { items = {}, used = 0 }
  function pool:Reset()
    for i = 1, self.used do self.items[i]:Hide() end
    self.used = 0
  end
  function pool:Get()
    self.used = self.used + 1
    local item = self.items[self.used]
    if not item then
      item = create()
      self.items[self.used] = item
    end
    item:Show()
    return item
  end
  return pool
end
