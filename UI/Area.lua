-- Forever Hunter Pets · Reiter „Gebiet“: Fortschrittsbuch je Zone (Meilenstein M2, Inkremente E4 und E5).
-- Aufbau (Wunsch des Nutzers): oben die Zonenauswahl. Links die Tiere der Zone, anklickbar, je mit dem Kästchen
-- aus „Fähigkeiten“ (Haken = Fähigkeiten bekannt) und dem Icon der Familie. Rechts oben die Karte, darunter die
-- Zähler „X von Y“. Punkte zeigt die Karte nur für das gewählte Tier (ns.Coords), ohne Auswahl nie.
-- Die Modi (Nutzer, 17.10.2026): Im Komplettmodus steht alles, was bekannt ist, vollständig da – jedes Tier mit
-- Namen, ohne Status. Im Entdeckermodus zählt nur, was man selbst gefunden hat: Tiere bleiben anonym
-- („? unentdecktes Tier“), bis man eine Fährte hat, ab da mit Namen und Status-Tag.
-- Zähler aus Core/Discover.lua (ns.ZoneProgress), X je Modus. Ist X = Y, steht nur die Zahl, ohne Balken.
-- Gleiches sieht im ganzen Addon gleich aus. Gezählt und gezeichnet wird beim Öffnen, beim Zonenwechsel und bei
-- einer Auswahl, nichts im Hintergrund. Zahl und Wort sind maßgeblich, Balken und Symbole nur zusätzlich.
local _, ns = ...
local L = ns.L
local W = ns.W
local D = ns.Data

local LEFT_W, GAP, FILTER_H = 400, 12, 32   -- wie die Liste in „Fähigkeiten“
local ROW_H, LABEL_W, BAR_H = 40, 110, 8
local MAX_PINS = 150
local ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"
local STATUS = { known = { order = 1 }, found = { order = 2 }, track = { order = 3 } }   -- Entdeckermodus

-- Zone, in der der Spieler steht, wenn sie in der Auswahl vorkommt
local function currentZone(zones)
  local here = ns.CellHere and ns.CellHere()
  for _, z in ipairs(zones) do
    if z == here then return z end
  end
  return zones[1]
end

-- Familie und Stufe eines Tiers: aus den Daten, sonst aus der eigenen Sichtung
local function famAndLevel(npc)
  local b = D.beasts[npc]
  local seen = ns.SeenBeast and ns.SeenBeast(npc)
  local fam = ns.BeastFamily(npc)
  local level
  if b and b.min then level = ns.LevelText(b)
  elseif seen then level = seen.min == seen.max and tostring(seen.min) or (seen.min .. "-" .. seen.max) end
  return fam, level
end

-- Tooltip einer Zeile: Name, dann je Fähigkeit Icon, Name und Rang – oder „? unklar“ bzw. „lehrt nichts“
local function teachTooltip(owner, npc)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(ns.BeastName(npc))
  local info = ns.TeachInfo(npc, ns.Discovering())
  if not info then
    GameTooltip:AddLine(L["? unclear"], 0.8, 0.8, 0.8)
  elseif #info == 0 then
    GameTooltip:AddLine(L["teaches nothing"], 0.8, 0.8, 0.8)
  else
    for _, e in ipairs(info) do
      local rank = ns.RankLabel(e.a, e.r)
      GameTooltip:AddLine(("|T%s:16:16|t %s"):format(ns.AbilityIcon(e.a), ns.AbilityName(e.a))
        .. (rank ~= "" and (" · " .. rank) or ""), 1, 1, 1)
    end
  end
  GameTooltip:AddLine(L["Click: show on the map"], 0.4, 0.8, 1)
  GameTooltip:Show()
end

function ns.BuildArea(parent)
  local v = {}
  local zones = ns.DiscoverZones()
  local RIGHT_W = ns.CONTENT_W - LEFT_W - GAP
  local H = ns.CONTENT_H - FILTER_H

  local empty = W.Text(parent, "GameFontDisable", true)
  empty:SetPoint("TOPLEFT", 4, -8)
  empty:SetWidth(ns.CONTENT_W - 8)
  empty:SetText(L["No zone with beasts known yet."])
  empty:SetShown(#zones == 0)
  if #zones == 0 then
    function v:Render() end
    return v
  end

  local zone, selected = currentZone(zones), nil
  local options = {}
  for _, z in ipairs(zones) do options[#options + 1] = { value = z, label = ns.ZoneName(z) } end
  local dd = W.Dropdown(parent, LEFT_W, options, function(value)
    zone, selected = value, nil
    v:Render()
  end)
  dd:SetPoint("TOPLEFT", 0, 0)
  dd:SetValue(zone)

  -- ---- links: die Tiere der Zone ----
  local list = W.Scroll(parent, LEFT_W, H)
  list:SetPoint("TOPLEFT", 0, -FILTER_H)
  local LW = list.contentWidth
  local rows = W.Pool(function()
    local b = CreateFrame("Button", nil, list.content)
    b:SetSize(LW, ROW_H)
    b.sel = W.Fill(b, 0.62, 0.83, 0.37, 0.2)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.06)
    -- das Kästchen aus „Fähigkeiten“, hier nur zur Anzeige
    b.box = W.CheckBox(b)
    b.box:SetPoint("LEFT", 6, 0)
    b.box:EnableMouse(false)
    b.icon = W.Icon(b, 28)
    b.icon:SetPoint("LEFT", 32, 0)
    b.name = W.Text(b, "GameFontHighlight")
    b.name:SetPoint("TOPLEFT", 68, -4)
    b.name:SetPoint("TOPRIGHT", -4, -4)
    b.sub = W.Text(b, "GameFontHighlightSmall")
    b.sub:SetPoint("TOPLEFT", 68, -22)
    b.sub:SetPoint("TOPRIGHT", -4, -22)
    b:SetScript("OnEnter", function(self)
      if self.npc then teachTooltip(self, self.npc) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
      if not self.npc then return end
      selected = self.npc   -- keine Abwahl: ohne Auswahl stünden alle Fundorte der Zone auf der Karte
      v:Render()
    end)
    return b
  end)

  -- ---- rechts: oben die Karte, darunter die Zähler ----
  local right = CreateFrame("Frame", nil, parent)
  right:SetPoint("TOPLEFT", LEFT_W + GAP, -FILTER_H)
  right:SetSize(RIGHT_W, H)
  -- Titel in der Kopfzeile neben der Zonenauswahl, die Karte bündig mit der Liste (wie in „Ausbildung“)
  local mapTitle = W.Text(parent, "GameFontNormal")
  mapTitle:SetPoint("LEFT", parent, "TOPLEFT", LEFT_W + GAP, -12)
  mapTitle:SetWidth(RIGHT_W)
  local mapH = math.floor(RIGHT_W * 668 / 1002)
  local canvas = ns.CreateMapCanvas(right, RIGHT_W, mapH)
  canvas:SetPoint("TOPLEFT", 0, 0)
  local mapInfo = W.Text(right, "GameFontHighlightSmall", true)
  mapInfo:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -6)
  mapInfo:SetWidth(RIGHT_W)

  local barW = RIGHT_W - LABEL_W - 8
  local y = -(mapH + 30)
  local function row(label, withBar)
    local r = {}
    r.label = W.Text(right, "GameFontNormal")
    r.label:SetPoint("TOPLEFT", 0, y)
    r.label:SetWidth(LABEL_W)
    r.label:SetText(label)
    r.value = W.Text(right, "GameFontHighlight")
    r.value:SetPoint("TOPLEFT", LABEL_W, y)
    if withBar then
      r.bar = CreateFrame("Frame", nil, right)
      r.bar:SetSize(barW, BAR_H)
      r.bar:SetPoint("TOPLEFT", r.value, "BOTTOMLEFT", 0, -5)
      W.Fill(r.bar, 1, 1, 1, 0.1)
      r.fill = r.bar:CreateTexture(nil, "ARTWORK")
      r.fill:SetPoint("TOPLEFT")
      r.fill:SetPoint("BOTTOMLEFT")
      r.fill:SetColorTexture(0.62, 0.83, 0.37, 0.9)
    end
    y = y - (withBar and 34 or 24)
    return r
  end
  local function setBar(r, x, total)
    if not r.bar then return end
    local share = total > 0 and math.min(1, x / total) or 0
    r.fill:SetWidth(math.max(0.001, barW * share))
    r.fill:SetShown(share > 0)
  end
  -- „X von Y …“ mit Balken; ist alles bekannt (X = Y), nur die Zahl ohne Balken (Wunsch des Nutzers)
  local function showCount(r, x, total, fmt)
    local done = x >= total
    r.value:SetText(done and tostring(total) or (L[fmt]):format(x, total))
    if r.bar then
      r.bar:SetShown(not done)
      setBar(r, x, total)
    end
  end
  local yBeasts = y
  local beasts = row(L["Beasts"], true)
  -- Was die Status bedeuten, beim Überfahren des Zählers (Wunsch des Nutzers: nicht selbsterklärend)
  local beastsHover = CreateFrame("Frame", nil, right)
  beastsHover:SetPoint("TOPLEFT", 0, yBeasts)
  beastsHover:SetSize(RIGHT_W, yBeasts - y)
  beastsHover:EnableMouse(true)
  beastsHover:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Beasts"], 1, 1, 1)
    if ns.Discovering() then
      GameTooltip:AddLine(ns.StatusWord("track") .. ": "
        .. L["You saw it in this zone, but were never close to it. It is not on your map yet."], 0.8, 0.8, 0.8, true)
      GameTooltip:AddLine(ns.StatusWord("found") .. ": "
        .. L["You were close to it in this zone, so its spawn point is on your map."], 0.8, 0.8, 0.8, true)
      GameTooltip:AddLine(ns.StatusWord("known") .. ": "
        .. L["Found, and you have tamed it, so you know what it teaches."], 0.8, 0.8, 0.8, true)
      GameTooltip:AddLine(L["Only “abilities known” moves the progress."], 0.8, 0.8, 0.8, true)
    else
      GameTooltip:AddLine(L["Known: the data or a taming shows what it teaches."], 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
  end)
  beastsHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local teachers = row(L["Teaching beasts"], true)
  local ranks = row(L["Abilities"], true)
  local cells = row(L["Spawn points"], false)

  -- ---- Zeichnen ----
  local function drawList()
    rows:Reset()
    local discover = ns.Discovering()
    -- Einträge: Entdeckermodus nach Status (bekannt, gefunden, Fährte, unentdeckt), unentdeckte anonym und nicht
    -- anklickbar; Komplettmodus jedes Tier mit Namen, die mit bekannter Lehre zuerst
    local entries = {}
    for npc in pairs(ns.BeastsIn(zone)) do
      local e = { npc = npc }
      if discover then
        e.st = ns.BeastStatus(npc, zone)
        e.pick = STATUS[e.st] ~= nil
        e.order = e.pick and STATUS[e.st].order or 9
      else
        e.st = ns.TeachInfo(npc, false) and "known" or "open"
        e.pick, e.order = true, e.st == "known" and 1 or 2
      end
      if e.pick then e.name = ns.BeastName(npc) end
      entries[#entries + 1] = e
    end
    table.sort(entries, function(a, b)
      if a.order ~= b.order then return a.order < b.order end
      if a.name and b.name and a.name ~= b.name then return a.name < b.name end
      return a.npc < b.npc
    end)
    -- Sobald es in der Zone etwas anzuklicken gibt, ist immer ein Tier gewählt (Wunsch des Nutzers: sonst
    -- stehen hunderte Punkte auf der Karte). Fehlt die Auswahl in der Liste, nimmt sie das erste Tier.
    local keep
    for _, e in ipairs(entries) do
      if e.pick and e.npc == selected then keep = true break end
    end
    if not keep then selected = entries[1] and entries[1].pick and entries[1].npc or nil end
    local ry = 0
    for _, e in ipairs(entries) do
      local r = rows:Get()
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -ry)
      local fam, level = famAndLevel(e.npc)
      local where = {}
      if fam then where[#where + 1] = ns.FamilyName(fam) end
      if level then where[#where + 1] = (L["Level %s"]):format(level) end
      -- Haken = Fähigkeiten bekannt. Entdeckermodus: leeres Kästchen = Tier gefunden, kein Kästchen bei Fährte
      -- und unentdeckt; Komplettmodus: leeres Kästchen = noch unklar, was es lehrt
      r.box:SetShown(not discover or e.st == "known" or e.st == "found")
      r.box.check:SetShown(e.st == "known")
      if e.pick then
        r.npc = e.npc
        r.icon:SetTexture((ns.FamilyIcon(fam)))
        r.name:SetText(e.name)
        if discover then table.insert(where, 1, ns.StatusWord(e.st)) end   -- Status-Tag nur im Entdeckermodus
        where[#where + 1] = ns.TeachText(e.npc)
        r.sub:SetText(table.concat(where, " · "))
        r:Enable()
      else
        -- unentdeckt (nur Entdeckermodus): anonym, bis man eine Fährte hat
        r.npc = false
        r.icon:SetTexture(ICON_UNKNOWN)
        r.name:SetText(L["? undiscovered beast"])
        r.sub:SetText("")
        r:Disable()
      end
      r.sel:SetShown(r.npc and e.npc == selected or false)
      ry = ry + ROW_H
    end
    list:SetContentHeight(ry)
  end

  local function drawMap()
    local pts = {}
    if selected then
      pts = ns.Coords(selected, zone)
      mapTitle:SetText(ns.BeastName(selected))
    else
      -- nichts anklickbar: leere Karte, in beiden Modi gleich
      mapTitle:SetText(L["No beast found yet"])
    end
    local shown = ns.Sample(pts, MAX_PINS)
    local ok = canvas:Show_(ns.MapForZone(zone), shown, false)
    local text
    if not selected then
      text = ""
    elseif #pts == 0 then
      text = L["Spawn point unknown"]
    else
      text = #pts == 1 and L["1 spawn point on the map"] or (L["%d spawn points on the map"]):format(#pts)
      if ok and #shown < #pts then text = text .. " · " .. (L["%d of them drawn"]):format(#shown) end
    end
    mapInfo:SetText(text)
  end

  function v:Render()
    if not zone then return end
    drawList()
    drawMap()
    local p = ns.ZoneProgress(zone)
    showCount(beasts, p.beastsKnown, p.beasts, "%d of %d known")
    showCount(teachers, p.teachersKnown, p.teachers, "%d of %d identified")
    showCount(ranks, p.ranksFound, p.ranks, "%d of %d ranks discovered")
    -- Fundorte: im Entdeckermodus die eigenen Zellen, im Komplettmodus alle Fundorte der Zone
    if ns.Discovering() then
      cells.value:SetText(p.cells == 1 and L["1 cell"] or (L["%d cells"]):format(p.cells))
    else
      cells.value:SetText(p.points == 1 and L["1 spawn point"] or (L["%d spawn points"]):format(p.points))
    end
  end

  -- Moduswechsel: neu zeichnen, wenn der Reiter gerade zu sehen ist
  ns.OnModeChanged(function() if parent:IsVisible() then v:Render() end end)
  return v
end
