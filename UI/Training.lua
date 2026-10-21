-- Forever Hunter Pets · Ansicht „Ausbildung“: der Lernstand als Liste, angelehnt an das Fenster
-- „Wildtierausbildung“. Farben wie dort: grün kann das Pet jetzt lernen, gelb fehlen ihm die
-- Trainingspunkte, rot braucht mehr Pet-Stufe, grau hat es schon erlernt oder erlaubt seine Familie
-- nicht. Die Mehrfachauswahl „Anzeigen“ blendet einzelne dieser Zustände aus.
local _, ns = ...
local L = ns.L
local W = ns.W
local D = ns.Data

local LIST_W, ROW_H, GAP, COUNT_H = 400, 24, 12, 18
local FILTER_H = 32   -- Kopfzeile: Auswahl 24 hoch, darunter 8 Abstand
local GREEN, GREY, WHITE, RED = { 0.25, 1, 0.25 }, { 0.5, 0.5, 0.5 }, { 1, 1, 1 }, { 1, 0.35, 0.3 }
local YELLOW = { 1, 0.85, 0.1 }

-- Zustand einer Zeile, in der Reihenfolge der Liste
local ORDER = { ok = 1, tp = 2, later = 3, has = 4, no = 5 }
local COLOR = { ok = GREEN, tp = YELLOW, later = RED, has = GREY, no = GREY }

local function petLevel()
  if not (UnitExists and UnitLevel) then return nil end
  local ok, exists = pcall(UnitExists, "pet")
  if not (ok and ns.clean(exists)) then return nil end
  local ok2, level = pcall(UnitLevel, "pet")
  level = ok2 and tonumber(ns.clean(level))
  return (level and level > 0) and level or nil
end

-- freie Trainingspunkte des aktiven Pets (gesamt minus verbraucht), oder nil
local function freePoints()
  if not (C_PetInfo and C_PetInfo.GetPetTrainingPoints) then return nil end
  local ok, total, spent = pcall(C_PetInfo.GetPetTrainingPoints)
  total, spent = ok and tonumber(ns.clean(total)), ok and tonumber(ns.clean(spent))
  if not (total and spent) then return nil end
  return total - spent
end

local function contains(list, value)
  for _, x in ipairs(list) do if x == value then return true end end
  return false
end

-- Was ein Rang dieses Pet kostet: Hat es schon einen niedrigeren Rang der Fähigkeit, zählt nur die
-- Differenz zu dessen Kosten (Beißen 4 kostet 10, mit Beißen 3 für 7 also 3). nil ohne Kostenangabe.
local function netCost(a, r, petRank)
  if not r.tp then return nil end
  local paid = 0
  if petRank and petRank > 0 then
    for _, x in ipairs(a.ranks) do
      if x.rank == petRank then paid = x.tp or 0 end
    end
  end
  return math.max(r.tp - paid, 0)
end

-- Gefärbt wird immer für das aktive Pet: seine Familie, seine Stufe und was es schon kann.
function ns.BuildTraining(parent)
  local v = { show = { ok = true, tp = true, later = true, has = true, no = true } }
  local H = ns.CONTENT_H

  -- Was abgewählt ist, steht je Charakter in den gespeicherten Daten. Ob es die Sitzung überdauert,
  -- hat die Ansicht „Fähigkeiten“ beim Aufbau schon entschieden (Einstellung „Filter merken“).
  ns.char.filters.training = ns.char.filters.training or {}
  local saved = ns.char.filters.training
  local FILTERS = {
    { header = L["Status"] },
    { key = "ok", label = L["learnable"], tip = L["Your pet can learn it right now: its family allows it, its level is high enough and it has the training points."] },
    { key = "tp", label = L["not enough TP"], tip = L["Family and pet level fit, but your pet has too few free training points. With a lower rank already learned, only the difference counts."] },
    { key = "later", label = L["pet level too low"], tip = L["Your pet needs a higher level for this rank."] },
    { key = "has", label = L["your pet has it"], tip = L["Ranks your active pet already has."] },
    { header = L["Family"] },
    { key = "no", label = L["for other families"], tip = L["Ranks you have, but the family of your active pet cannot learn."] },
  }
  local filterDD = W.MultiDropdown(parent, nil, L["Show"], FILTERS, function(key, on)
    v.show[key] = on
    if on then saved[key] = nil else saved[key] = false end
    v:Render()
  end)
  filterDD:SetPoint("TOPLEFT")
  for _, o in ipairs(FILTERS) do
    if o.key and saved[o.key] == false then
      v.show[o.key] = false
      filterDD:SetChecked(o.key, false)
    end
  end

  -- „Wildtierausbildung · Familie“ über der rechten Spalte, linksbündig mit dem Icon im Detailfeld
  local head = W.Text(parent, "GameFontNormal")
  head:SetPoint("LEFT", parent, "TOPLEFT", LIST_W + GAP, -12)
  local HEAD_H = FILTER_H

  local list = W.Scroll(parent, LIST_W, H - COUNT_H - HEAD_H)
  list:SetPoint("TOPLEFT", 0, -HEAD_H)
  W.Fill(list, 0, 0, 0, 0.25)
  local count = W.Text(parent, "GameFontDisableSmall")
  count:SetPoint("BOTTOMLEFT", 2, 0)
  local empty = W.Text(parent, "GameFontDisable", true)
  empty:SetPoint("TOP", list, "TOP", 0, -40)
  empty:SetWidth(LIST_W - 40)
  empty:SetJustifyH("CENTER")
  empty:SetText(L["Nothing learned yet. Open the Beast Training window or tick ranks in “Abilities” – they are listed here then."])

  -- Warum eine Zeile so gefärbt ist – für Tooltip und Detailfeld
  local function reason(e)
    if e.state == "ok" then return L["Your pet can learn this now"] end
    if e.state == "tp" then return (L["Not enough training points: costs %d, your pet has %d"]):format(e.cost, e.free) end
    if e.state == "later" then return (L["Needs pet level %d (your pet: %d)"]):format(e.r.level, v.level) end
    if e.state == "has" then return L["Your pet has it"] end
    if e.state == "no" then return (L["%s cannot learn this."]):format(ns.FamilyName(v.fam)) end
    return nil
  end

  -- ---- Detailfeld zur gewählten Zeile ----
  local DW = ns.CONTENT_W - LIST_W - GAP
  local detail = CreateFrame("Frame", nil, parent)
  -- unter der Kopfzeile, an derselben Stelle wie die Details in „Fähigkeiten“
  detail:SetSize(DW, H - HEAD_H)
  detail:SetPoint("TOPRIGHT", 0, -HEAD_H)
  local iconBtn = CreateFrame("Button", nil, detail)
  iconBtn:SetSize(44, 44)
  iconBtn:SetPoint("TOPLEFT")
  local icon = W.Icon(iconBtn, 44)
  icon:SetPoint("CENTER")
  iconBtn:SetScript("OnEnter", function(self)
    if not v.selected then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. v.selected.r.id) then GameTooltip:Show() end
  end)
  iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local title = W.Text(detail, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 10, -3)
  local status = W.Text(detail, "GameFontHighlight")
  status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  local needs = W.Text(detail, "GameFontHighlight", true)
  local cost = W.Text(detail, "GameFontHighlight", true)
  local desc = W.Text(detail, "GameFontHighlight", true)
  local who = W.Text(detail, "GameFontHighlightSmall", true)

  local function place(fs, y, text, color)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -y)
    fs:SetWidth(DW)
    fs:SetText(text)
    fs:SetTextColor(color[1], color[2], color[3])
    return y + fs:GetStringHeight() + 8
  end

  function v:RenderDetail()
    local e = self.selected
    detail:SetShown(e ~= nil)
    if not e then return end
    local a, r = e.a, e.r
    icon:SetTexture(ns.AbilityIcon(a))
    local rank = ns.RankLabel(a, r)
    title:SetText(e.name .. (rank ~= "" and (" · " .. rank) or ""))
    local c = COLOR[e.state] or WHITE
    status:SetText(reason(e) or "")
    status:SetTextColor(c[1], c[2], c[3])
    local y = 56
    y = place(needs, y, (L["Requires: pet level %d"]):format(r.level or 0), e.state == "later" and RED or WHITE)
    local costText = r.tp and ((r.tp == 1 and L["Cost: 1 training point"] or L["Cost: %d training points"]):format(r.tp))
      or L["Cost: unknown"]
    -- mit einem niedrigeren Rang zahlt das Pet nur die Differenz
    if e.cost and e.cost ~= r.tp and e.state ~= "has" then
      costText = costText .. " · " .. (L["%d for your pet, it already has a lower rank"]):format(e.cost)
    end
    if e.state == "tp" then costText = costText .. " · " .. (L["free: %d"]):format(e.free) end
    y = place(cost, y, costText, e.state == "tp" and YELLOW or WHITE)
    y = place(desc, y + 4, ns.Description(r), { 1, 0.82, 0 })
    local names = {}
    if ns.AppliesToAll(a) then
      names[1] = L["all families"]
    else
      for _, id in ipairs(a.families) do names[#names + 1] = ns.FamilyName(id) end
      table.sort(names)
    end
    y = place(who, y + 4, (L["Learnable by: %s"]):format(table.concat(names, ", ")), e.state == "no" and RED or WHITE)
    self.buttonY = y + 10
  end

  -- ---- Knopf „Wildtierausbildung öffnen“ ----
  -- Lehren kann nur das Spielfenster; dieser Knopf öffnet es. Einen Zauber darf ein Addon nur über
  -- einen „sicheren“ Knopf wirken. Hinge der in unserem Fenster, gälte das ganze Fenster im Kampf als
  -- geschützt und ließe sich dann nicht mehr öffnen oder schließen. Deshalb ist er ein eigenes
  -- Element am Bildschirm, das nur an die Stelle im Detailfeld gelegt wird. Im Kampf blendet ihn
  -- der Client selbst aus; angefasst wird er von hier aus nur außerhalb des Kampfs.
  local BEAST_TRAINING = 5149
  local holder, openBtn
  local function syncButton()
    if InCombatLockdown and InCombatLockdown() then return end
    local show = parent:IsVisible() and v.selected ~= nil and v.buttonY ~= nil and ns.PetFamily() ~= nil
    if not holder then
      if not show then return end
      holder = CreateFrame("Frame", nil, UIParent)
      holder:SetAllPoints(UIParent)
      holder:SetFrameStrata("DIALOG")
      if RegisterStateDriver then RegisterStateDriver(holder, "visibility", "[combat] hide; show") end
      openBtn = CreateFrame("Button", nil, holder, "SecureActionButtonTemplate,UIPanelButtonTemplate")
      openBtn:SetSize(240, 22)
      openBtn:SetText(L["Open Beast Training"])
      -- je nach Einstellung des Clients löst ein sicherer Knopf beim Drücken oder beim Loslassen aus
      openBtn:RegisterForClicks("AnyDown", "AnyUp")
      openBtn:SetAttribute("type", "spell")
      -- der Name, wie ihn der Client nennt (so in der Probe bestätigt); ohne ihn die ID
      local ok, info = pcall(C_Spell.GetSpellInfo, BEAST_TRAINING)
      info = ok and ns.clean(info)
      local spell = type(info) == "table" and ns.clean(info.name)
      openBtn:SetAttribute("spell", (type(spell) == "string" and spell ~= "") and spell or BEAST_TRAINING)
      openBtn:SetScript("PreClick", function() ns.NoteTrainerSelection(v.selected) end)
      openBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Open Beast Training"], 1, 1, 1)
        GameTooltip:AddLine(L["Opens the game's Beast Training window. Teaching is only possible there; pick the same rank in it."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
      end)
      openBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local left, top = detail:GetLeft(), detail:GetTop()
    if show and left and top then
      openBtn:ClearAllPoints()
      openBtn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top - v.buttonY)
      openBtn:Show()
    else
      openBtn:Hide()
      -- direkt nach dem Öffnen kennt der Client die Lage des Detailfelds noch nicht: gleich noch einmal
      if show and (v.retries or 0) < 5 then
        v.retries = (v.retries or 0) + 1
        ns.After(0.05, syncButton)
        return
      end
    end
    v.retries = 0
  end
  parent:SetScript("OnShow", syncButton)
  parent:SetScript("OnHide", syncButton)
  ns.OnFrameMoved = syncButton
  ns.OnFrameMoveStart = function()
    -- beim Verschieben des Fensters wandert der Knopf nicht mit; solange ausblenden
    if openBtn and not (InCombatLockdown and InCombatLockdown()) then openBtn:Hide() end
  end
  ns.On("PLAYER_REGEN_ENABLED", syncButton)   -- nach dem Kampf wieder an den aktuellen Stand anpassen

  local function choose(e)
    v.selected = e
    for i = 1, v.rows.used do
      local row = v.rows.items[i]
      row.sel:SetShown(row.entry == e)
    end
    v:RenderDetail()
    syncButton()
  end

  v.rows = W.Pool(function()
    local b = CreateFrame("Button", nil, list.content)
    b:SetHeight(ROW_H)
    b.sel = W.Selection(b)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.06)
    b.name = W.Text(b, "GameFontHighlight")
    b.name:SetPoint("LEFT", 8, 0)
    b.later = W.Text(b, "GameFontDisableSmall")
    b.later:SetPoint("LEFT", b.name, "RIGHT", 10, 0)
    b.tp = W.Text(b, "GameFontHighlightSmall")
    b.tp:SetPoint("RIGHT", -8, 0)
    b:SetScript("OnClick", function(self) choose(self.entry) end)
    b:SetScript("OnEnter", function(self)
      local e = self.entry
      local text = reason(e)
      if not text then return end
      local c = COLOR[e.state]
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.name:GetText(), 1, 1, 1)
      GameTooltip:AddLine(text, c[1], c[2], c[3], true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end)

  function v:Render()
    -- Familie des aktiven Pets; ohne Pet bleibt die Liste ungefärbt
    local fam = ns.PetFamily()
    local petRanks = fam and ns.PetRanks() or nil
    self.fam, self.level = fam, fam and petLevel() or nil
    local free = fam and freePoints() or nil

    local entries, total = {}, 0
    local n = { ok = 0, tp = 0, later = 0, has = 0, no = 0 }
    for _, a in ipairs(D.abilities) do
      if ns.Learnable(a) then
        local name = ns.AbilityName(a)
        local allowed = fam and (ns.AppliesToAll(a) or contains(a.families, fam))
        for _, r in ipairs(a.ranks) do
          if ns.IsKnown(r) then
            local state = nil
            if fam then
              if not allowed then
                state = "no"
              elseif petRanks and (petRanks[a] or 0) >= r.rank then
                state = "has"
              elseif self.level and r.level and r.level > self.level then
                state = "later"
              else
                state = "ok"
              end
            end
            local need = fam and allowed and netCost(a, r, petRanks and petRanks[a]) or nil
            -- ohne Kostenangabe oder ohne Auskunft über die Punkte bleibt es bei grün
            if state == "ok" and need and free and need > free then state = "tp" end
            total = total + 1
            if state then n[state] = n[state] + 1 end
            -- ohne Pet gibt es keinen Zustand, dann wirkt die Auswahl nicht
            if not state or self.show[state] then
              entries[#entries + 1] = { a = a, r = r, name = name, state = state, cost = need, free = free,
                key = W.SortKey(name) }
            end
          end
        end
      end
    end
    -- wie im Spiel: erst was das Pet lernen kann, dann der Rest; darin nach Name und Rang
    table.sort(entries, function(x, y)
      local ox, oy = ORDER[x.state] or 0, ORDER[y.state] or 0
      if ox ~= oy then return ox < oy end
      if x.key ~= y.key then return x.key < y.key end
      return x.r.rank < y.r.rank
    end)

    local old, keep = self.selected, nil
    self.rows:Reset()
    for i, e in ipairs(entries) do
      if old and e.r == old.r then keep = e end
      local row = self.rows:Get()
      row.entry = e
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
      row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
      local c = COLOR[e.state] or WHITE
      local rank = ns.RankLabel(e.a, e.r)
      row.name:SetText(e.name .. (rank ~= "" and (" (" .. rank .. ")") or ""))
      row.name:SetTextColor(c[1], c[2], c[3])
      row.later:SetText(e.state == "later" and (L["from pet level %d"]):format(e.r.level) or "")
      row.tp:SetText(e.r.tp and (L["%d TP"]):format(e.r.tp) or "")
      row.tp:SetTextColor(c[1], c[2], c[3])
    end
    list:SetContentHeight(#entries * ROW_H)
    empty:SetShown(#entries == 0)
    empty:SetText(total == 0
      and L["Nothing learned yet. Open the Beast Training window or tick ranks in “Abilities” – they are listed here then."]
      or L["Nothing to show with this selection."])

    head:SetText(L["Beast Training"] .. (fam and (" · " .. ns.FamilyName(fam)) or ""))
    local parts = { (total == 1 and L["1 rank you have"] or L["%d ranks you have"]):format(total) }
    if #entries ~= total then parts[#parts + 1] = (L["%d shown"]):format(#entries) end
    if fam then
      parts[#parts + 1] = (L["%d learnable, %d short of TP, %d later, %d your pet has, %d not learnable"]):format(
        n.ok, n.tp, n.later, n.has, n.no)
    else
      parts[#parts + 1] = L["call your pet"]
    end
    if free then parts[#parts + 1] = (L["training points: %d"]):format(free) end
    count:SetText(table.concat(parts, " · "))

    choose(keep or entries[1])
  end

  -- neu zeichnen, wenn sich Lernstand oder Pet ändern – aber nur, solange die Ansicht zu sehen ist
  local function refresh()
    if parent:IsVisible() then v:Render() end
  end
  ns.OnKnownChanged(refresh)
  ns.On("UNIT_PET", function(unit) if ns.clean(unit) == "player" then refresh() end end)
  ns.On("UNIT_PET_TRAINING_POINTS", refresh)
  ns.On("SPELLS_CHANGED", refresh)   -- das Pet hat etwas gelernt: der Rang wird grau
  ns.On("SPELL_TEXT_UPDATE", function(spellID)
    if v.selected and v.selected.r.id == ns.clean(spellID) and parent:IsVisible() then v:RenderDetail() end
  end)

  return v
end
