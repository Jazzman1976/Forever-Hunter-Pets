-- Forever Hunter Pets · Ansicht „Fähigkeiten“: links eine Zeile je Rang, rechts die Details zur gewählten Zeile
local _, ns = ...
local L = ns.L
local W = ns.W
local D = ns.Data

local LIST_W, ROW_H, GAP, COUNT_H = 400, 40, 12, 18
local FILTER_H, DD_GAP = 32, 8   -- Filterzeile über den Spalten: 24 hoch, darunter 8 Abstand
local SOURCE_LABEL = { tame = "Taming", trainer = "Pet trainer", unknown = "Unknown", trait = "Attack speed" }
local SOURCE_COLOR = { tame = "9fd45f", trainer = "66ccff", unknown = "9aa3b5", trait = "ffd100" }

local BEAST_H = 36
local EFFORT_COLOR = { easy = { 0.62, 0.83, 0.37 }, medium = { 1, 0.82, 0 }, hard = { 1, 0.45, 0.35 } }
local CLS_LABEL = { [1] = "Elite", [2] = "Rare elite", [3] = "Boss", [4] = "Rare" }
local MAX_OPEN = 8   -- „? unentdecktes Tier“-Zeilen höchstens, dann „und n weitere“
local CONF_HEAD = { [2] = "Uncertain – reported by fewer than 3 other players", [3] = "Unproven – estimated, not seen yet" }

local function zonesText(id, b)
  local zones = ns.BeastZones(id)
  if #zones == 0 then return (b.zoneText and b.zoneText ~= "") and b.zoneText or L["Spawn point unknown"] end
  local names = {}
  for i, z in ipairs(zones) do names[i] = ns.ZoneName(z) end
  return table.concat(names, ", ")
end

local CURRENT = "current"   -- Wert der Auswahlen „Aktuelle Zone“ und „Aktuelle Familie“
local NO_ZONE = {}          -- leere Zonenmenge: in der aktuellen Zone steht kein Lehrtier

local function sourceKey(a)
  return a.kind == "trait" and "trait" or a.source
end

-- Eine Zeile je Fähigkeit und Rang. Im deutschen Client stehen die Daten schon richtig sortiert
-- (Umlaute eingeordnet), sonst nach dem Namen, den der Client nennt.
local function orderedAbilities()
  local abilities = {}
  for i, a in ipairs(D.abilities) do abilities[i] = { a = a, name = ns.AbilityName(a), order = i } end
  if ns.lang ~= "de" then
    table.sort(abilities, function(x, y)
      if x.name ~= y.name then return x.name < y.name end
      return x.order < y.order
    end)
  end
  return abilities
end

local function contains(list, value)
  for _, x in ipairs(list) do if x == value then return true end end
  return false
end

-- zone ist eine Menge von Zonen-IDs: { [id] = true }
local function inZones(list, zone)
  for _, x in ipairs(list) do if zone[x] then return true end end
  return false
end

-- Die Zeilen für die gewählten Filter, gleiche Regeln wie renderAbilities() der Seite:
-- Familie blendet Fähigkeiten aus, die sie nicht lernen kann. Zone lässt nur Fähigkeiten mit
-- einem Lehrtier dort übrig, kürzt die Tierlisten auf die Zone und streicht Zähm-Ränge ohne Tier.
local function buildEntries(abilities, fam, zone)
  local entries = {}
  for _, x in ipairs(abilities) do
    local a = x.a
    if not fam or ns.AppliesToAll(a) or contains(a.families, fam) then
      -- gezählt wird nur, was die Einstellungen zeigen (unsichere und unbelegte Lehrtiere sind sonst aus)
      local inZone, shown = 0, 0
      for _, t in ipairs(a.teach) do
        if ns.ShowConf(t[3]) then
          shown = shown + 1
          local b = zone and D.beasts[t[1]]
          if b and inZones(ns.BeastZones(t[1]), zone) then inZone = inZone + 1 end
        end
      end
      -- dazu, was eigene Zähmungen zeigten, auch bei Tieren, die (noch) nicht in den Daten stehen
      for _, r in ipairs(a.ranks) do
        for _, id in ipairs(ns.ObservedTeachers and ns.ObservedTeachers(a, r) or {}) do
          shown = shown + 1
          if zone and inZones(ns.BeastZones(id), zone) then inZone = inZone + 1 end
        end
      end
      if not zone or inZone > 0 then
        local filtered = zone ~= nil and inZone < shown
        for _, r in ipairs(a.ranks) do
          local teachers = ns.Teachers(a, r, zone)
          -- Angeborenes hängt am gezähmten Tier selbst: mit gewählter Familie zählen nur deren
          -- Tiere, und ohne ein solches fällt der Eintrag weg
          local trait = fam and not ns.Learnable(a)
          if trait then
            local own = {}
            for _, t in ipairs(teachers) do
              if ns.BeastFamily(t.id) == fam then own[#own + 1] = t end
            end
            teachers = own
          end
          if not ((trait or (a.source == "tame" and filtered)) and #teachers == 0) then
            entries[#entries + 1] = { a = a, r = r, name = x.name, teachers = teachers }
          end
        end
      end
    end
  end
  return entries
end

local function familyOptions()
  local options = {}
  for id in pairs(ns.FamilyIds()) do options[#options + 1] = { value = id, label = ns.FamilyName(id) } end
  table.sort(options, function(x, y) return W.SortKey(x.label) < W.SortKey(y.label) end)
  table.insert(options, 1, { label = L["All families"] })
  table.insert(options, 2, { value = CURRENT, label = L["Current family"] })
  return options
end

-- Nur Zonen, in denen überhaupt ein Lehrtier steht. Der Wert einer Auswahl ist eine Menge von
-- Zonen-IDs: Forever führt manche Zone unter zwei IDs (Desolace), die gehören zusammen. Eine
-- Instanz, die wie eine Zone heißt (Vorgebirge von Hillsbrad), bleibt getrennt und wird benannt.
local function zoneOptions()
  local seen, byKey, options = {}, {}, {}
  for _, a in ipairs(D.abilities) do
    -- Lehrtiere aus den Daten und aus Zähmungen, auch Tiere, die (noch) nicht in den Daten stehen
    local ids = {}
    for _, t in ipairs(a.teach) do ids[#ids + 1] = t[1] end
    for _, r in ipairs(a.ranks) do
      for _, id in ipairs(ns.ObservedTeachers and ns.ObservedTeachers(a, r) or {}) do ids[#ids + 1] = id end
    end
    for _, npc in ipairs(ids) do
      for _, z in ipairs(ns.BeastZones(npc)) do
        if not seen[z] then
          seen[z] = true
          local name, inst = ns.ZoneName(z), (D.zones[z] and D.zones[z].inst) and true or false
          local key = name .. (inst and "#i" or "")
          local option = byKey[key]
          if not option then
            option = { value = {}, ids = {}, label = name, name = name, inst = inst }
            byKey[key] = option
            options[#options + 1] = option
          end
          option.value[z] = true
          option.ids[#option.ids + 1] = z
        end
      end
    end
  end
  for _, option in ipairs(options) do
    if option.inst and byKey[option.name] then option.label = option.name .. " (" .. L["instance"] .. ")" end
  end
  table.sort(options, function(x, y)
    local kx, ky = W.SortKey(x.label), W.SortKey(y.label)
    if kx ~= ky then return kx < ky end
    return x.ids[1] < y.ids[1]
  end)
  table.insert(options, 1, { label = L["All zones"] })
  table.insert(options, 2, { value = CURRENT, label = L["Current zone"] })
  return options
end

-- Die Auswahl, die zur Zone passt, in der der Spieler steht, und deren Name. Erst über die Karte
-- des Clients, sonst über den Zonennamen (Instanzen haben keine Karte in den Daten).
local function currentZone(options)
  local mapID
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and ns.clean(id) or nil
  end
  local name = GetRealZoneText and ns.clean(GetRealZoneText())
  if type(name) ~= "string" or name == "" then name = nil end
  local inside = false
  if IsInInstance then inside = ns.clean((IsInInstance())) and true or false end
  local byName
  for _, o in ipairs(options) do
    if o.ids and o.inst == inside then
      if mapID and not inside then
        for _, z in ipairs(o.ids) do
          if ns.MapForZone(z) == mapID then return o, o.name end
        end
      end
      if name and o.name == name then byName = o end
    end
  end
  return byName, name
end

-- Das aktive Pet beherrscht den Rang, der Jäger hat ihn aber noch nicht gelernt. Nur für Ränge, die
-- man von Tieren abschaut: was der Tierausbilder lehrt, kann ein Pet nur vom Jäger haben.
local function petAhead(e)
  return e.a.source == "tame" and ns.Learnable(e.a) and not ns.IsKnown(e.r) and ns.PetKnows(e.r)
end
local PET_AHEAD = "|cffffa633%s|r"
-- Lernstand in der Kopfzeile nur als Ganzes umbrechen, nicht „hast | du“ (#87): geschützte Leerzeichen (U+00A0)
local function nobreak(s) return (s:gsub(" ", "\194\160")) end

local function metaText(e)
  local a, r = e.a, e.r
  local parts = {}
  if r.level and r.level > 0 and a.kind ~= "trait" then parts[#parts + 1] = (L["from pet level %d"]):format(r.level) end
  if r.tp then parts[#parts + 1] = (L["%d TP"]):format(r.tp) end
  if a.source == "tame" then
    -- ohne Lehrtier ist der Rang eine Aufgabe: ein Wort statt „0 Tiere“. „? unbekannt“: niemand kennt eins;
    -- im Entdeckermodus dazu, wie viele bekannt, aber selbst noch unentdeckt sind
    local n, open = #e.teachers, e.teachers.undiscovered or 0
    if n > 0 then parts[#parts + 1] = n == 1 and L["1 beast"] or (L["%d beasts"]):format(n) end
    if open > 0 then parts[#parts + 1] = (L["%d undiscovered"]):format(open) end
    if n == 0 and open == 0 then parts[#parts + 1] = L["? unknown"] end
  end
  return table.concat(parts, " · ")
end

local function familiesText(a)
  if a.kind == "trait" then return L["depends on the tamed beast"] end
  if ns.AppliesToAll(a) then return L["all families"] end
  local names = {}
  for _, id in ipairs(a.families) do names[#names + 1] = ns.FamilyName(id) end
  table.sort(names)
  return table.concat(names, ", ")
end

local function hintText(e)
  local a = e.a
  if petAhead(e) then
    return L["Your pet already knows this rank, you do not yet. Let it use the ability in combat until the game reports that you learned it. Don't release the pet before."]
  end
  if a.kind == "trait" then
    return (L["Your pet takes over the attack speed of the beast you tame. These beasts attack every %s s, the normal speed is %s s:"]):format(
      ns.Decimal(a.speed), ns.Decimal(2))
  end
  if a.source == "trainer" then return L["Learned from the pet trainer."] end
  if a.source == "unknown" then return L["No source says how this ability is learned."] end
  if #e.teachers == 0 and (e.teachers.undiscovered or 0) > 0 then
    return L["Not discovered yet – find a beast that teaches it."]
  end
  if #e.teachers == 0 then
    local hidden = e.teachers.hidden or 0
    if hidden > 0 then
      return (hidden == 1 and L["No confirmed beast for this rank. 1 uncertain or unproven beast is hidden; you can show it in the settings."]
        or L["No confirmed beast for this rank. %d uncertain or unproven beasts are hidden; you can show them in the settings."]):format(hidden)
    end
    return L["? Unknown – nobody has found a beast that teaches it yet."]
  end
  return L["Tameable beasts that know this rank, the easiest to reach first:"]
end

-- Stufe des Jägers; ohne Auskunft gilt jedes Tier als zähmbar
local function playerLevel()
  if not UnitLevel then return nil end
  local ok, level = pcall(UnitLevel, "player")
  level = ok and tonumber(ns.clean(level))
  return (level and level > 0) and level or nil
end

-- Stand eines Rangs aus Sicht des Jägers: "known" ist abgehakt, "available" kann er jetzt lernen
-- (ein Lehrtier bis zu seiner Stufe, oder beim Tierausbilder), sonst "unavailable". Die Lehrtiere
-- sind schon auf die gewählte Zone gekürzt, „verfügbar“ heißt dann: in dieser Zone.
-- Zähmen lässt sich ein Tier höchstens auf der eigenen Stufe. Das gilt auch für Angeborenes
-- (Angriffstempo); „bekannt“ wird es nie, weil es sich nicht lehren lässt.
local function status(e, level)
  local a, r = e.a, e.r
  if ns.Learnable(a) and ns.IsKnown(r) then return "known" end
  if a.source == "trainer" then
    return (not level or (r.level or 0) <= level) and "available" or "unavailable"
  end
  if a.source == "tame" then
    for _, t in ipairs(e.teachers) do
      if not level or (t.beast.min or 0) <= level then return "available" end
    end
  end
  return "unavailable"
end

-- parent: der Inhaltsbereich. Oben die Filterzeile, darunter links die Liste und rechts die Details.
function ns.BuildAbilities(parent)
  local abilities = orderedAbilities()
  local v = { entries = {}, show = { available = true, unavailable = true, known = true, innate = true, trainer = true } }
  local H = ns.CONTENT_H - FILTER_H
  local RIGHT_W = ns.CONTENT_W - LIST_W - GAP

  -- ---- linke Spalte: die Liste ----
  local list = W.Scroll(parent, LIST_W, H - COUNT_H)
  list:SetPoint("TOPLEFT", 0, -FILTER_H)
  W.Fill(list, 0, 0, 0, 0.25)
  local count = W.Text(parent, "GameFontDisableSmall")
  count:SetPoint("BOTTOMLEFT", 2, 0)

  -- ---- rechte Spalte: die Details ----
  local detail = W.Scroll(parent, RIGHT_W, H)
  detail:SetPoint("TOPRIGHT", 0, -FILTER_H)
  local dc, DW = detail.content, detail.contentWidth

  -- Die Kartenseite eines Tiers liegt an derselben Stelle und löst die Details ab, bis „Zurück“
  local beastPage = ns.BuildBeastPage(parent, RIGHT_W, H)
  beastPage:SetPoint("TOPRIGHT", 0, -FILTER_H)
  beastPage.onBack = function()
    beastPage:Hide()
    detail:Show()
  end

  local iconBtn = CreateFrame("Button", nil, dc)
  iconBtn:SetSize(44, 44)
  iconBtn:SetPoint("TOPLEFT")
  local icon = W.Icon(iconBtn, 44)
  icon:SetPoint("CENTER")
  -- Der Tooltip des Zaubers kommt vom Client und ist damit immer in dessen Sprache
  iconBtn:SetScript("OnEnter", function(self)
    if not v.selected then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. v.selected.r.id) then GameTooltip:Show() end
  end)
  iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local title = W.Text(dc, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, -3)
  -- die Kopfzeile darf umbrechen: mit allen Teilen ist sie im deutschen Client breiter als die Spalte (#87)
  local sub = W.Text(dc, "GameFontHighlight", true)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  local desc = W.Text(dc, "GameFontHighlight", true)
  local fams = W.Text(dc, "GameFontHighlightSmall", true)
  local hint = W.Text(dc, "GameFontDisable", true)

  -- Überschriften der Gruppen „unsicher“ und „unbelegt“ in der Liste der Lehrtiere
  local groupHeads = W.Pool(function() return W.Text(dc, "GameFontHighlightSmall", true) end)
  -- Bereiche „zähmbar auf deiner Stufe“ und „über deiner Stufe“, dazwischen eine Linie
  local sectionHeads = W.Pool(function() return W.Text(dc, "GameFontNormal", true) end)
  local rules = W.Pool(function()
    local t = dc:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.15)
    return t
  end)

  local beastRows = W.Pool(function()
    local b = CreateFrame("Button", nil, dc)
    b:SetSize(DW, BEAST_H)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.06)
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(8, 8)
    b.dot:SetPoint("TOPLEFT", 2, -6)
    b.star = b:CreateTexture(nil, "ARTWORK")
    b.star:SetSize(14, 14)
    b.star:SetPoint("TOPLEFT", 16, -2)
    b.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    b.level = W.Text(b, "GameFontHighlightSmall")
    b.level:SetPoint("TOPRIGHT", -4, -4)
    b.name = W.Text(b, "GameFontHighlight")
    b.where = W.Text(b, "GameFontDisableSmall")
    b.where:SetPoint("BOTTOMLEFT", 16, 4)
    b.where:SetPoint("BOTTOMRIGHT", -4, 4)
    b:SetScript("OnEnter", function(self)
      local t = self.teacher
      local beast = t.beast
      local cls = CLS_LABEL[beast.cls]
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.BeastName(t.id))
      GameTooltip:AddLine((L["Level %s"]):format(ns.LevelText(beast)) .. (cls and (" · " .. L[cls]) or "")
        .. " · " .. ns.FamilyName(ns.BeastFamily(t.id)), 1, 1, 1)
      GameTooltip:AddLine(zonesText(t.id, beast), 0.8, 0.8, 0.8, true)
      local c = EFFORT_COLOR[t.effort.level]
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine((L["Effort: %s"]):format(L[t.effort.level]), c[1], c[2], c[3])
      GameTooltip:AddLine(table.concat(t.effort.why, " · "), 0.8, 0.8, 0.8, true)
      if self.star:IsShown() then GameTooltip:AddLine(L["Recommended for this rank"], 1, 0.82, 0) end
      GameTooltip:AddLine(L["Click: show on the map"], 0.4, 0.8, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
      local e = v.selected
      local rank = ns.RankLabel(e.a, e.r)
      GameTooltip:Hide()
      detail:Hide()
      beastPage:Open(self.teacher, e.name .. (rank ~= "" and (" · " .. rank) or ""))
    end)
    return b
  end)

  local function place(fs, y, text)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -y)
    fs:SetWidth(DW)
    fs:SetText(text)
    fs:SetShown(text ~= "")
    if text == "" then return y end
    return y + fs:GetStringHeight() + 10
  end

  function v:RenderDetail()
    local e = self.selected
    if not e then return end
    local a, r = e.a, e.r
    icon:SetTexture(ns.AbilityIcon(a))
    title:SetText(e.name)
    local key = sourceKey(a)
    local parts = { "|cff" .. SOURCE_COLOR[key] .. L[SOURCE_LABEL[key]] .. "|r" }
    local rank = ns.RankLabel(a, r)
    if rank ~= "" then table.insert(parts, 1, rank) end
    local meta = metaText(e)
    if meta ~= "" then parts[#parts + 1] = meta end
    if ns.Learnable(a) and ns.IsKnown(r) then
      parts[#parts + 1] = "|cff9fd45f" .. nobreak(L["you have it"]) .. "|r"
    elseif petAhead(e) then
      -- kurz halten: der Hinweis darunter erklärt den Rest
      table.insert(parts, rank ~= "" and 2 or 1, PET_AHEAD:format(nobreak(L["you lack it"])))
    end
    sub:SetWidth(DW - 44 - 10)
    sub:SetText(table.concat(parts, " · "))

    -- unter Icon und Kopfzeile; bricht die Kopfzeile um, rückt alles darunter mit
    local y = math.max(56, 3 + title:GetStringHeight() + 6 + sub:GetStringHeight() + 10)
    y = place(desc, y, ns.Description(r))
    y = place(fams, y, (L["Learnable by: %s"]):format(familiesText(a)))
    y = place(hint, y + 4, hintText(e))

    -- Lehrtiere dieses Rangs in zwei Bereichen: oben, was der Jäger mit seiner Stufe schon zähmen kann,
    -- darunter durch eine Linie getrennt der Rest. In jedem Bereich bleibt die Reihenfolge von
    -- ns.Teachers (belegte zuerst, dann das leichteste); unsichere und unbelegte (nur wenn eingeschaltet)
    -- stehen unter eigener Zwischenüberschrift und tragen ein „?“ bzw. „!“ (ns.ConfMark). Den Stern bekommt das erste belegte
    -- Tier, das man schon zähmen kann.
    beastRows:Reset()
    groupHeads:Reset()
    sectionHeads:Reset()
    rules:Reset()
    local level = playerLevel()
    local sections = { {}, {} }
    for _, t in ipairs(e.teachers) do
      local now = not level or (t.beast.min or 0) <= level
      table.insert(sections[now and 1 or 2], t)
    end
    local starGiven = false
    for s, list in ipairs(sections) do
      if #list > 0 then
        if s == 2 and #sections[1] > 0 then
          local rule = rules:Get()
          rule:ClearAllPoints()
          rule:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -(y + 8))
          rule:SetSize(DW, 1)
          y = y + 12
        end
        local head = sectionHeads:Get()
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -(y + 6))
        head:SetWidth(DW)
        head:SetText((L[s == 1 and "Tameable at your level (%d)" or "Above your level (%d)"]):format(#list))
        y = y + head:GetStringHeight() + 12
        local group = ns.CONF_SURE
        for _, t in ipairs(list) do
          if t.conf ~= group then
            group = t.conf
            local sub = groupHeads:Get()
            sub:ClearAllPoints()
            sub:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -(y + 4))
            sub:SetWidth(DW)
            sub:SetText(L[CONF_HEAD[group]])
            y = y + sub:GetStringHeight() + 10
          end
          local row = beastRows:Get()
          row.teacher = t
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -y)
          local c = EFFORT_COLOR[t.effort.level]
          row.dot:SetColorTexture(c[1], c[2], c[3], 1)
          local star = not starGiven and s == 1 and t.conf == ns.CONF_SURE
          if star then starGiven = true end
          row.star:SetShown(star)
          row.name:ClearAllPoints()
          row.name:SetPoint("TOPLEFT", star and 34 or 16, -3)
          row.name:SetPoint("TOPRIGHT", row.level, "TOPLEFT", -8, 1)
          local cls = CLS_LABEL[t.beast.cls]
          row.name:SetText(ns.BeastName(t.id) .. ns.ConfMark(t.conf) .. (cls and ("  |cffffa633" .. L[cls] .. "|r") or ""))
          row.level:SetText((L["Level %s"]):format(ns.LevelText(t.beast)))
          row.where:SetText(zonesText(t.id, t.beast) .. " · " .. ns.FamilyName(ns.BeastFamily(t.id)))
          y = y + BEAST_H
        end
      end
    end
    -- Entdeckermodus: je weiterem, bekanntem Lehrtier eine Zeile „? unentdecktes Tier“, ohne Familie und Stufe
    local open = e.teachers.undiscovered or 0
    for i = 1, math.min(open, MAX_OPEN) do
      local line = groupHeads:Get()
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", dc, "TOPLEFT", 16, -(y + 4))
      line:SetWidth(DW - 16)
      line:SetText(i == MAX_OPEN and open > MAX_OPEN and (L["? and %d more undiscovered beasts"]):format(open - MAX_OPEN + 1)
        or L["? undiscovered beast"])
      y = y + line:GetStringHeight() + 8
    end
    detail:SetContentHeight(y + 8)
  end

  -- ---- Zeilen ----
  local function choose(e)
    v.selected = e
    for i = 1, v.rows.used do
      local row = v.rows.items[i]
      row.sel:SetShown(row.entry == e)
    end
    beastPage:Hide()
    detail:Show()
    detail:ScrollTo(0)
    v:RenderDetail()
  end

  v.rows = W.Pool(function()
    local b = CreateFrame("Button", nil, list.content)
    b:SetHeight(ROW_H)
    b.sel = W.Selection(b)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.06)
    -- Lernstand-Häkchen: ein eigener Knopf, damit der Klick nicht die Zeile wählt
    b.box = W.CheckBox(b)
    b.box.row = b
    b.box:SetPoint("LEFT", 6, 0)
    -- Abhaken von Hand nur mit der Einstellung „Manuelles Editieren“; sonst wählt ein Klick die Zeile.
    -- Der Tooltip erscheint in beiden Fällen: Das Kästchen hat keine Spaltenüberschrift.
    b.box:SetScript("OnClick", function(self)
      local e = self.row.entry
      if ns.db.ui.manualEdit then
        ns.SetKnown(e.r, not ns.IsKnown(e.r))
      else
        choose(e)
      end
    end)
    b.box:SetScript("OnEnter", function(self)
      local e = self.row.entry
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L["You have it"], 1, 1, 1)
      GameTooltip:AddLine(ns.IsKnown(e.r) and L["You have learned this rank."] or L["You have not learned this rank yet."], 1, 0.82, 0)
      GameTooltip:AddLine(L["The tick shows which ranks you can teach your pets. The addon sets it on its own from the Beast Training window and when the game reports that you learned the spell. A tick counts for this rank only."], 0.8, 0.8, 0.8, true)
      if ns.db.ui.manualEdit then
        GameTooltip:AddLine(L["Click to tick or untick it by hand."], 0.4, 0.8, 1, true)
      else
        GameTooltip:AddLine(L["To change it by hand, switch on “Manual editing” in the settings."], 0.4, 0.8, 1, true)
      end
      GameTooltip:Show()
    end)
    b.box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.icon = W.Icon(b, 30)
    b.icon:SetPoint("LEFT", 30, 0)
    b.name = W.Text(b, "GameFontNormal")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -1)
    b.rank = W.Text(b, "GameFontHighlightSmall")
    b.rank:SetPoint("BOTTOMLEFT", b.name, "BOTTOMRIGHT", 6, 0)
    b.meta = W.Text(b, "GameFontDisableSmall")
    b.meta:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 1)
    b:SetScript("OnClick", function(self) choose(self.entry) end)
    return b
  end)

  function v:RenderList()
    self.rows:Reset()
    local names = {}
    local n = 0
    for i, e in ipairs(self.entries) do
      local row = self.rows:Get()
      row.entry = e
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
      row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
      row.icon:SetTexture(ns.AbilityIcon(e.a))
      row.name:SetText(e.name)
      row.rank:SetText(ns.RankLabel(e.a, e.r))
      row.meta:SetText(metaText(e) .. (petAhead(e) and ("  " .. PET_AHEAD:format(L["your pet has it"])) or ""))
      row.sel:SetShown(e == self.selected)
      row.box:SetShown(ns.Learnable(e.a))
      row.box.check:SetShown(ns.IsKnown(e.r))
      if not names[e.a] then names[e.a] = true; n = n + 1 end
    end
    list:SetContentHeight(#self.entries * ROW_H)
    count:SetText((L["%d rank entries from %d abilities"]):format(#self.entries, n))
  end

  -- Gebaut wird nur, was zu sehen ist (#50): Im Hintergrund merkt sich die Ansicht nur, dass sie veraltet ist,
  -- und baut beim nächsten Öffnen einmal neu (rebuild, unten) – wie „Ausbildung“ und „Gebiet“
  local function whenVisible(fn)
    if parent:IsVisible() then fn() else v.stale = true end
  end

  -- Lernstand geändert (abgehakt oder vom Spiel erkannt): nur die Häkchen nachziehen, nicht scrollen
  ns.OnKnownChanged(function() whenVisible(function()
    -- blendet ein Status-Häkchen etwas aus, kann der Rang damit aus der Liste fallen oder dazukommen
    if not (v.show.available and v.show.unavailable and v.show.known) then
      v:ApplyFilter(true)
      return
    end
    for i = 1, v.rows.used do
      local row = v.rows.items[i]
      local e = row.entry
      row.box.check:SetShown(ns.IsKnown(e.r))
      row.meta:SetText(metaText(e) .. (petAhead(e) and ("  " .. PET_AHEAD:format(L["your pet has it"])) or ""))
    end
    if v.selected and detail:IsShown() then v:RenderDetail() end
  end) end)

  -- Der Client lädt Zaubertexte nach; kommt die Beschreibung der gewählten Zeile, neu zeichnen
  ns.On("SPELL_TEXT_UPDATE", function(spellID)
    if v.selected and v.selected.r.id == ns.clean(spellID) and parent:IsVisible() then v:RenderDetail() end
  end)

  -- ---- Filterzeile: links die Mehrfachauswahl, rechts Zone und Familie ----
  local empty = W.Text(parent, "GameFontDisable", true)
  empty:SetPoint("TOP", list, "TOP", 0, -40)
  empty:SetWidth(LIST_W - 40)
  empty:SetJustifyH("CENTER")
  empty:SetText(L["Nothing matches this selection. Try another filter, family or zone."])
  empty:Hide()

  -- Baut die Liste für die gewählten Filter neu. Die gewählte Zeile bleibt, wenn es sie noch gibt.
  -- keepScroll: die Liste bleibt, wo sie ist, und eine offene Kartenseite bleibt offen.
  function v:ApplyFilter(keepScroll)
    local old = self.selected
    local level = playerLevel()
    local keep
    -- eine neue Fähigkeit aus der Erhebung (ns.MergeSurveyAbilities, etwa gleich nach dem Zähmen) gleich
    -- mitnehmen, nicht erst nach /reload (#17); neue Ränge vorhandener Fähigkeiten kommen über a.ranks ohnehin mit
    if #abilities ~= #D.abilities then abilities = orderedAbilities() end
    self.entries = {}
    for _, e in ipairs(buildEntries(abilities, self.fam, self.zone)) do
      -- „angeboren“ ist eine eigene Achse: es blendet das Angriffstempo aus oder lässt es zu,
      -- ob es dann erscheint, entscheidet wie bei allem anderen der Status. Ebenso „Tierausbilder“:
      -- ohne Haken fällt weg, wofür man kein Tier suchen und zähmen muss
      if self.show[status(e, level)] and (self.show.innate or ns.Learnable(e.a))
        and (self.show.trainer or e.a.source ~= "trainer") then
        self.entries[#self.entries + 1] = e
        if old and e.a == old.a and e.r == old.r then keep = e end
      end
    end
    self.selected = keep
    self:RenderList()
    if not keepScroll then list:ScrollTo(0) end
    empty:SetShown(#self.entries == 0)
    if keep and keepScroll then
      if detail:IsShown() then self:RenderDetail() end
    elseif keep or self.entries[1] then
      choose(keep or self.entries[1])
    else
      beastPage:Hide()
      detail:Hide()
    end
  end

  -- Was gewählt ist, steht je Charakter in den gespeicherten Daten; ob es beim nächsten Start
  -- wieder gilt, entscheidet die Einstellung „Filter merken“
  if not ns.db.ui.keepFilters then ns.char.filters = { show = {} } end
  local saved = ns.char.filters

  -- alle drei Auswahlen gleich breit, die beiden rechten zusammen so breit wie die rechte Spalte
  local DD_W = (RIGHT_W - DD_GAP) / 2
  local FILTERS = {
    { header = L["Status"] },
    { key = "available", label = L["you lack it, in reach"], tip = L["Not ticked yet, and you can learn it now: a beast up to your level teaches it, or the pet trainer does."] },
    { key = "unavailable", label = L["you lack it, out of reach"], tip = L["Not ticked yet, and out of reach for now: every beast that teaches it is above your level, or no source is known."] },
    { key = "known", label = L["you have it"], tip = L["Ranks you have: ticked because you learned them."] },
    { header = L["Source"] },
    { key = "innate", label = L["innate"], tip = L["What a beast brings along when tamed and can never be taught, like its attack speed. Untick to hide it; whether it shows also depends on “you lack it, in reach” and “you lack it, out of reach”."] },
    { key = "trainer", label = L["Pet trainer"], tip = L["Abilities you learn from the pet trainer, without finding and taming a beast. Untick to hide them; whether they show also depends on “you lack it, in reach”, “you lack it, out of reach” and “you have it”."] },
  }
  local filterDD = W.MultiDropdown(parent, nil, L["Show"], FILTERS, function(key, on)
    v.show[key] = on
    if on then saved.show[key] = nil else saved.show[key] = false end
    v:ApplyFilter()
  end)
  filterDD:SetPoint("TOPLEFT")
  -- mit einer neuen Stufe werden weitere Tiere zähmbar; der Client nennt sie erst kurz danach
  ns.On("PLAYER_LEVEL_UP", function()
    ns.After(0.5, function() whenVisible(function() v:ApplyFilter(true) end) end)
  end)

  -- „Aktuelle Zone“ folgt dem Spieler: die Zone wird bei jedem Zonenwechsel neu bestimmt
  local zones = zoneOptions()
  local zoneDD
  -- true, wenn die Liste dabei neu gebaut wurde
  local function followZone(keepScroll)
    local option, name = currentZone(zones)
    zoneDD.label:SetText(L["Current zone"] .. (name and (": " .. name) or ""))
    local set = option and option.value or NO_ZONE
    if v.zone == set then return false end
    v.zone = set
    v:ApplyFilter(keepScroll)
    return true
  end
  -- Die Auswahl neu bauen, wenn Lehrtiere dazukommen (Zähmung, Erhebung) oder man die Zone wechselt (#24): Sonst
  -- fehlt eine Zone, in der beim Aufbau noch kein Lehrtier stand, und „Aktuelle Zone“ filtert bis /reload ins
  -- Leere. Eine fest gewählte Zone wird über ihre IDs in der neuen Auswahl wiedergefunden.
  local function refreshZones()
    zones = zoneOptions()
    local fixed = not v.follow and type(v.zone) == "table" and next(v.zone)
    zoneDD:SetOptions(zones)
    if not fixed then return end
    for _, o in ipairs(zones) do
      if o.ids and o.value[fixed] then
        v.zone = o.value
        zoneDD:SetValue(o.value)
        return
      end
    end
  end
  -- gemerkt wird eine der Zonen-IDs der Auswahl: die Menge selbst lässt sich nicht speichern
  local function selectZone(value)
    saved.zone = type(value) == "table" and (next(value)) or value
    v.follow = value == CURRENT
    if v.follow then
      v.zone = nil
      followZone()
    else
      v.zone = value
      v:ApplyFilter()
    end
  end
  zoneDD = W.Dropdown(parent, DD_W, zones, selectZone)
  local followPet  -- weiter unten bei der Familienauswahl gefüllt
  local function zoneChanged()
    refreshZones()
    if v.follow then followZone() end
    if v.followPet then followPet() end   -- nach dem Einloggen ist das Pet erst jetzt bekannt
  end
  ns.On("ZONE_CHANGED_NEW_AREA", function() whenVisible(zoneChanged) end)
  ns.On("PLAYER_ENTERING_WORLD", function() whenVisible(zoneChanged) end)
  -- „Aktuelle Familie“ folgt dem aktiven Pet. Ohne Pet gilt kein Familienfilter.
  local famDD
  -- noBuild: nur Beschriftung und Familie bestimmen, die Liste baut der Aufrufer
  followPet = function(noBuild)
    local id, name = ns.PetFamily()
    famDD.label:SetText(L["Current family"] .. ": " .. (name or L["no pet"]))
    if v.fam == id then return end
    v.fam = id
    if not noBuild then v:ApplyFilter() end
  end
  local function selectFam(value)
    saved.fam = value
    v.followPet = value == CURRENT
    if v.followPet then
      v.fam = false   -- damit followPet() die Liste auf jeden Fall neu baut, auch ohne Pet
      followPet()
    else
      v.fam = value
      v:ApplyFilter()
    end
  end
  famDD = W.Dropdown(parent, DD_W, familyOptions(), selectFam)
  famDD:SetPoint("TOPRIGHT")
  zoneDD:SetPoint("RIGHT", famDD, "LEFT", -DD_GAP, 0)
  ns.On("UNIT_PET", function(unit)
    if v.followPet and ns.clean(unit) == "player" then whenVisible(followPet) end
  end)

  -- Der eine Weg zum Neubauen: Zonenauswahl, Familie und Liste (#24: vorher nur die Liste, mit veralteter Zone)
  local function rebuild()
    refreshZones()
    if v.followPet then followPet(true) end
    if not (v.follow and followZone(true)) then v:ApplyFilter(true) end
  end
  -- Neue Zähmung (auch fremde, alle 5 s), neue Fähigkeit aus der Erhebung oder Angaben in den Einstellungen
  -- ein- oder ausgeschaltet
  ns.OnShowConfChanged(function() whenVisible(rebuild) end)
  -- beim Öffnen des Fensters und beim Wechsel auf den Reiter einmal nachziehen, was im Hintergrund liegen blieb
  parent:HookScript("OnShow", function()
    if not v.stale then return end
    v.stale = false
    ns.SafeCall("abilities", rebuild)
  end)

  -- Stand der letzten Sitzung. Eine Zone oder Familie, die es in den Daten nicht mehr gibt,
  -- bleibt bei „Alle“.
  for _, o in ipairs(FILTERS) do
    if o.key and saved.show[o.key] == false then
      v.show[o.key] = false
      filterDD:SetChecked(o.key, false)
    end
  end
  local zone, fam = saved.zone, saved.fam
  saved.zone, saved.fam = nil, nil
  if zone == CURRENT then
    zoneDD:SetValue(CURRENT)
    selectZone(CURRENT)
  elseif zone then
    for _, o in ipairs(zones) do
      if o.ids and o.value[zone] then
        zoneDD:SetValue(o.value)
        selectZone(o.value)
        break
      end
    end
  end
  if fam == CURRENT or (fam and ns.FamilyIds()[fam]) then
    famDD:SetValue(fam)
    selectFam(fam)
  end

  v.filterDD, v.zoneDD, v.famDD = filterDD, zoneDD, famDD
  v:ApplyFilter()
  return v
end
