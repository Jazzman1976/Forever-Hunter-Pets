-- Forever Hunter Pets · eigene Karte: Kacheln des Clients mit den Fundorten darauf, und die
-- Kartenseite eines Tiers für die Detailspalte. Die Weltkarte des Spiels bleibt unberührt.
local _, ns = ...
local L = ns.L
local W = ns.W
local D = ns.Data

local MAX_PINS = 150
local DISK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- weiße Kreisscheibe, wird eingefärbt

-- ---- die Karte selbst ----
function ns.CreateMapCanvas(parent, width, height)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(width, height)
  if c.SetClipsChildren then c:SetClipsChildren(true) end   -- die Randkacheln ragen über das Kartenbild hinaus
  W.Fill(c, 0.03, 0.03, 0.04, 1)
  c.tiles = {}
  c.msg = W.Text(c, "GameFontDisable", true)
  c.msg:SetPoint("CENTER")
  c.msg:SetWidth(width - 40)
  c.msg:SetJustifyH("CENTER")

  local pinLayer = CreateFrame("Frame", nil, c)
  pinLayer:SetAllPoints()
  pinLayer:SetFrameLevel(c:GetFrameLevel() + 2)
  local pins = W.Pool(function()
    local p = CreateFrame("Frame", nil, pinLayer)
    p:SetSize(7, 7)
    p:EnableMouse(true)
    -- runder Punkt mit dunklem Rand, damit er sich von der Karte abhebt
    p.rim = p:CreateTexture(nil, "BORDER")
    p.rim:SetAllPoints()
    p.rim:SetTexture(DISK)
    p.rim:SetVertexColor(0, 0, 0, 0.9)
    p.dot = p:CreateTexture(nil, "ARTWORK")
    p.dot:SetPoint("TOPLEFT", 1, -1)
    p.dot:SetPoint("BOTTOMRIGHT", -1, 1)
    p.dot:SetTexture(DISK)
    p:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.Decimal(self.x) .. " / " .. ns.Decimal(self.y), 1, 1, 1)
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return p
  end)

  -- Erkundete Gebiete: der Client liefert je Gebiet ein Bild, zerlegt in Kacheln von 256 Pixeln.
  -- Die letzte Kachel einer Reihe oder Spalte zeigt nur den Rest, ihre Datei ist aber auf die
  -- nächste Zweierpotenz aufgefüllt – daher der Ausschnitt über SetTexCoord.
  local EXPLORED_TILE = 256
  local explored = W.Pool(function() return c:CreateTexture(nil, "ARTWORK", nil, 1) end)
  local function split(total)
    local n = math.ceil(total / EXPLORED_TILE)
    local rest = total % EXPLORED_TILE
    if rest == 0 then rest = EXPLORED_TILE end
    local file = 16
    while file < rest do file = file * 2 end
    return n, rest, file
  end
  local function drawExplored(mapID, scale, ox, oy)
    for _, e in ipairs(ns.MapExplored(mapID) or {}) do
      local w, h, files = tonumber(e.textureWidth), tonumber(e.textureHeight), e.fileDataIDs
      -- Stücke, die die Weltkarte nur unter dem Mauszeiger aufleuchten lässt, gehören nicht dazu
      if w and h and w > 0 and h > 0 and type(files) == "table" and not e.isShownByMouseOver then
        local cols, restW, fileW = split(w)
        local rows, restH, fileH = split(h)
        for row = 1, rows do
          local ph = row < rows and EXPLORED_TILE or restH
          for col = 1, cols do
            local file = files[(row - 1) * cols + col]
            if file then
              local pw = col < cols and EXPLORED_TILE or restW
              local t = explored:Get()
              t:SetTexture(file)
              t:SetTexCoord(0, col < cols and 1 or pw / fileW, 0, row < rows and 1 or ph / fileH)
              t:SetSize(pw * scale, ph * scale)
              t:ClearAllPoints()
              t:SetPoint("TOPLEFT", ox + ((e.offsetX or 0) + (col - 1) * EXPLORED_TILE) * scale,
                -(oy + ((e.offsetY or 0) + (row - 1) * EXPLORED_TILE) * scale))
            end
          end
        end
      end
    end
  end

  -- Zeigt die Karte mit den Punkten { {x, y}, … } in Prozent. Liefert false, wenn der Client kein Kartenbild hat.
  function c:Show_(mapID, pts, rare)
    for _, t in ipairs(self.tiles) do t:Hide() end
    explored:Reset()
    pins:Reset()
    local a = ns.MapArt(mapID)
    if not a then
      self.msg:SetText(L["The client has no map for this zone."])
      self.msg:Show()
      return false
    end
    self.msg:Hide()
    -- Kartenbild einpassen und mittig setzen
    local scale = math.min(width / a.w, height / a.h)
    local ox, oy = (width - a.w * scale) / 2, (height - a.h * scale) / 2
    for i, file in ipairs(a.textures) do
      local t = self.tiles[i]
      if not t then
        t = self:CreateTexture(nil, "ARTWORK")
        self.tiles[i] = t
      end
      local col, row = (i - 1) % a.cols, math.floor((i - 1) / a.cols)
      t:SetTexture(file)
      t:SetSize(a.tw * scale, a.th * scale)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", ox + col * a.tw * scale, -(oy + row * a.th * scale))
      t:Show()
    end
    drawExplored(mapID, scale, ox, oy)
    for _, pt in ipairs(pts) do
      local p = pins:Get()
      p.x, p.y = pt[1], pt[2]
      if rare then p.dot:SetVertexColor(1, 0.82, 0, 1) else p.dot:SetVertexColor(0.68, 0.07, 0.05, 1) end   -- das dunkle Rot der Standardknöpfe
      p:ClearAllPoints()
      p:SetPoint("CENTER", self, "TOPLEFT", ox + a.w * scale * pt[1] / 100, -(oy + a.h * scale * pt[2] / 100))
    end
    return true
  end

  return c
end

-- ---- 3D-Modell eines Tiers ----
-- Der Client zeichnet es selbst (PlayerModel). Erst über die Anzeige-ID aus den Daten, dann über die
-- NPC-ID; lädt beides nicht, bleibt das Familien-Icon stehen. Ziehen mit der Maus dreht das Modell.
local function createModel(parent, size)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)
  W.Fill(holder, 0, 0, 0, 0.25)
  holder.icon = W.Icon(holder, math.floor(size * 0.4))
  holder.icon:SetPoint("CENTER")
  holder.icon:SetAlpha(0.6)
  local ok, m = pcall(CreateFrame, "PlayerModel", nil, holder)
  if not (ok and m) then m = nil end
  if m then
    m:SetAllPoints()
    if m.EnableMouse then m:EnableMouse(false) end   -- die Maus gehört dem Rahmen darunter (Drehen)
    pcall(m.SetScript, m, "OnModelLoaded", function() holder.icon:Hide() end)
  end
  local facing = -0.5
  local function now() return GetTime and GetTime() or 0 end
  local function loaded()
    if not (m and m.GetModelFileID) then return false end
    local ok2, file = pcall(m.GetModelFileID, m)
    file = ok2 and ns.clean(file)
    return file ~= nil and file ~= 0
  end

  function holder:Next()
    self.step = self.step + 1
    local try = self.tries[self.step]
    pcall(m.ClearModel, m)
    if not try then self.checkAt = nil; return end
    pcall(m[try[1]], m, try[2])
    pcall(m.SetFacing, m, facing)
    self.checkAt, self.checks = now() + 0.4, 0
  end

  function holder:SetBeast(npcId, beast)
    -- Bis das Modell geladen ist, das Familien-Icon; ohne Icon (die eigenen Daten kennen keins) bleibt
    -- der Bereich leer, ebenso wenn das Modell nicht lädt
    local icon, fallback = ns.FamilyIcon(ns.BeastFamily(npcId))
    if not fallback then
      self.icon:SetTexture(icon)
      self.icon:Show()
    else
      self.icon:Hide()
    end
    if not m then return end
    facing = -0.5
    self.tries = {}
    if beast.disp then self.tries[#self.tries + 1] = { "SetDisplayInfo", beast.disp } end
    self.tries[#self.tries + 1] = { "SetCreature", npcId }
    self.step = 0
    self:Next()
  end

  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
  holder:SetScript("OnMouseUp", function(self) self.dragX = nil end)
  holder:SetScript("OnHide", function(self) self.dragX = nil end)
  holder:SetScript("OnUpdate", function(self)
    if not m then return end
    -- geladen? Sonst nach ein paar Blicken den nächsten Weg versuchen
    if self.checkAt and now() >= self.checkAt then
      if loaded() then
        self.icon:Hide()
        self.checkAt = nil
        pcall(m.SetFacing, m, facing)
      else
        self.checks = self.checks + 1
        if self.checks >= 4 then self:Next() else self.checkAt = self.checkAt + 0.5 end
      end
    end
    if self.dragX then
      local x = GetCursorPosition()
      facing = facing + (x - self.dragX) * 0.012
      self.dragX = x
      pcall(m.SetFacing, m, facing)
    end
  end)
  return holder
end

-- ---- Kartenseite eines Tiers: Zurück, Name, Modell, Zonen-Umschalter, Karte, Fundortzeile ----
local MODEL = 130
function ns.BuildBeastPage(parent, width, height)
  local page = CreateFrame("Frame", nil, parent)
  page:SetSize(width, height)
  page:Hide()

  local model = createModel(page, MODEL)
  model:SetPoint("TOPRIGHT")

  local back = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  back:SetSize(90, 22)
  back:SetPoint("TOPLEFT")
  back:SetText("< " .. L["Back"])
  back:SetScript("OnClick", function() if page.onBack then page.onBack() end end)

  -- Name und Unterzeile stehen links neben dem Modell und brechen davor um
  local name = W.Text(page, "GameFontNormalLarge", true)
  name:SetPoint("TOPLEFT", 0, -32)
  name:SetWidth(width - MODEL - 10)
  local sub = W.Text(page, "GameFontHighlightSmall", true)
  sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
  sub:SetWidth(width - MODEL - 10)

  local mapH = math.floor(width * 668 / 1002)
  local canvas = ns.CreateMapCanvas(page, width, mapH)
  local info = W.Text(page, "GameFontHighlightSmall", true)
  info:SetWidth(width)
  local note = W.Text(page, "GameFontDisableSmall", true)
  note:SetWidth(width)
  note:SetText(L["Spawn points as players have seen them; they show the area, not the exact spot."])

  local tabs = W.Pool(function()
    -- eigener flacher Knopf: beim Standardknopf sähe die gewählte Zone ausgegraut aus
    local b = CreateFrame("Button", nil, page)
    b:SetHeight(22)
    b.bg = W.Fill(b, 1, 1, 1, 0.08)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.08)
    b.label = W.Text(b, "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b:SetScript("OnClick", function(self) page:ShowZone(self.zone) end)
    return b
  end)

  function page:ShowZone(zoneId)
    self.zone = zoneId
    for i = 1, tabs.used do
      local b = tabs.items[i]
      local on = b.zone == zoneId
      if on then b.bg:SetColorTexture(0.62, 0.83, 0.37, 0.45) else b.bg:SetColorTexture(1, 1, 1, 0.08) end
      if on then b.label:SetTextColor(1, 1, 1) else b.label:SetTextColor(0.7, 0.7, 0.7) end
    end
    local pts = ns.Coords(self.teacher.id, zoneId)
    local shown = ns.Sample(pts, MAX_PINS)
    local ok = canvas:Show_(ns.MapForZone(zoneId), shown, ns.IsRare(self.teacher.beast))
    local text = (#pts == 1 and L["%s: 1 spawn point"] or L["%s: %d spawn points"]):format(ns.ZoneName(zoneId), #pts)
    if ok and #shown < #pts then text = text .. " · " .. (L["%d of them drawn"]):format(#shown) end
    if not ok then
      -- keine Karte: wenigstens ein paar Koordinaten als Text
      local list = {}
      for i, pt in ipairs(ns.Sample(pts, 12)) do list[i] = ns.Decimal(pt[1]) .. " / " .. ns.Decimal(pt[2]) end
      text = text .. "\n" .. table.concat(list, " · ")
    end
    info:SetText(text)
  end

  -- t: Eintrag aus ns.Teachers; what: „Beißen · Rang 1“ für die Unterzeile
  function page:Open(t, what)
    self.teacher = t
    local b = t.beast
    name:SetText(ns.BeastName(t.id))
    sub:SetText((L["Level %s"]):format(ns.LevelText(b)) .. " · " .. ns.FamilyName(ns.BeastFamily(t.id)) .. " · " .. what)

    -- Zonen mit Fundorten, die mit den meisten Punkten zuerst
    local zones = {}
    for z, n in pairs(ns.ZoneCounts(t.id)) do zones[#zones + 1] = { id = z, n = n } end
    table.sort(zones, function(x, y)
      if x.n ~= y.n then return x.n > y.n end
      return x.id < y.id
    end)

    model:SetBeast(t.id, b)

    tabs:Reset()
    local y = MODEL + 8   -- alles Weitere beginnt unter dem Modell
    if #zones > 1 then
      local x = 0
      for _, z in ipairs(zones) do
        local tab = tabs:Get()
        tab.zone = z.id
        tab.label:SetText(ns.ZoneName(z.id) .. " (" .. z.n .. ")")
        tab:SetWidth(tab.label:GetStringWidth() + 20)
        if x > 0 and x + tab:GetWidth() > width then x = 0; y = y + 26 end
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", x, -y)
        x = x + tab:GetWidth() + 4
      end
      y = y + 30
    end

    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", 0, -y)
    info:ClearAllPoints()
    info:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -8)
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -6)

    canvas:SetShown(#zones > 0)
    note:SetShown(#zones > 0)
    if #zones > 0 then
      self:ShowZone(zones[1].id)
    else
      info:ClearAllPoints()
      info:SetPoint("TOPLEFT", 0, -y)
      local where = {}
      for i, z in ipairs(ns.BeastZones(t.id)) do where[i] = ns.ZoneName(z) end
      if #where == 0 and b.zoneText and b.zoneText ~= "" then where[1] = b.zoneText end
      info:SetText(L["Spawn point unknown"] .. (#where > 0 and ("\n" .. table.concat(where, ", ")) or ""))
    end
    self:Show()
  end

  return page
end
