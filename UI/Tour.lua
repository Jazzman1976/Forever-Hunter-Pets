-- Forever Hunter Pets · Tour beim ersten Öffnen im Entdeckermodus (#178, Epic #186).
-- Eine Sprechblase führt in sieben Schritten durch das Fenster; der Teil, um den es geht, bekommt einen hellen
-- Rahmen, und die Tour schaltet selbst auf den passenden Reiter. Sie kommt einmal je Account (ns.db.tourSeen,
-- schon beim Start gesetzt, damit sie nach Abbruch oder /reload nicht wiederkommt) und lässt sich jederzeit mit
-- dem X, mit ESC oder durch Schließen des Fensters abbrechen. /fhp tour zeigt sie erneut.
-- Was je Stufe als Nächstes zu tun ist, sagen Zeilen-Tooltip und Karte (#175); die Tour zeigt nur, wo es steht.
local _, ns = ...
local L = ns.L
local W = ns.W

local BW, PAD = 320, 14
local bubble, frameRing, step, prevView, hooked

-- Ziele liefern die Ansichten erst, wenn das Fenster gebaut ist; fehlt eins (etwa „Gebiet“ ohne bekannte Zone),
-- steht die Sprechblase in der Fenstermitte und nichts wird umrahmt
local function area(key) return function() return ns.frame.area.tour and ns.frame.area.tour[key] end end
local function tab(key) return function() return ns.frame.tabs and ns.frame.tabs[key] end end
local STEPS = {
  { view = "area", text = "In explorer mode you go hunting yourself. The addon reveals bit by bit what you find out about the beasts. This short tour shows you where to find what." },
  { view = "area", target = area("list"), side = "RIGHT", text = "Here are the beasts of the zone you are in. A beast you have never seen is a hidden beast. When you see it, you pick up its tracks. When you get close to it, you have found it. When you tame it, you have studied it." },
  { view = "area", target = area("box"), side = "RIGHT", text = "The checkbox shows how far you are: empty for tracks, a dot once you have found the beast, a tick once you have studied it. Hover over a beast to read what to do next." },
  { view = "area", target = area("map"), side = "LEFT", text = "The map shows where you have found the selected beast. Once you have studied it, it shows all known spawn points. If you don't know a spawn point yet, it tells you how to find one." },
  { view = "area", target = area("counters"), side = "LEFT", text = "Here you see your progress in this zone: how many beasts you have found and how many teaching beasts you have studied, and how many ranks you have discovered doing so." },
  { view = "abilities", target = tab("abilities"), side = "BELOW", text = "Here are all abilities and ranks. Which beasts teach them shows up here once you have studied the beasts." },
  { view = "training", target = tab("training"), side = "BELOW", text = "Here you see what your pet can learn, and you open the Beast Training. Happy hunting!" },
}
ns.TOUR_STEPS = #STEPS

-- heller Rahmen um das Ziel: vier Linien, damit das Ziel selbst sichtbar bleibt
local function ring()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("DIALOG")
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 0.82, 0, 1)
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(2)
      t:SetPoint(side .. "LEFT")
      t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(2)
      t:SetPoint("TOP" .. side)
      t:SetPoint("BOTTOM" .. side)
    end
  end
  f:Hide()
  return f
end

local function stop()
  if not step then return end
  step = nil
  frameRing:Hide()
  if bubble:IsShown() then bubble:Hide() end
  -- zurück zum Reiter von vorher, sofern das Fenster noch da ist
  if prevView and ns.frame and ns.frame.ShowView then ns.frame.ShowView(prevView) end
  prevView = nil
end

local show
local function create()
  local b = CreateFrame("Frame", "ForeverHunterPetsTour", UIParent)
  b:SetWidth(BW)
  b:SetFrameStrata("DIALOG")
  b:SetToplevel(true)
  b:SetClampedToScreen(true)
  b:EnableMouse(true)
  b:Hide()
  table.insert(UISpecialFrames, "ForeverHunterPetsTour")
  W.Fill(b, 0.10, 0.11, 0.14, 0.97, "BACKGROUND")
  -- Rand im Gold des Rahmens: Sprechblase und Ziel gehören sichtbar zusammen
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = b:CreateTexture(nil, "BORDER")
    t:SetColorTexture(1, 0.82, 0, 0.8)
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

  b.close = CreateFrame("Button", nil, b, "UIPanelCloseButton")
  b.close:SetPoint("TOPRIGHT", 0, 0)
  b.close:SetScript("OnClick", function() ns.SafeCall("tour", stop) end)

  b.text = W.Text(b, "GameFontHighlight", true)
  b.text:SetPoint("TOPLEFT", PAD, -PAD)
  b.text:SetWidth(BW - PAD * 2 - 20)
  b.count = W.Text(b, "GameFontDisableSmall")

  b.back = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
  b.back:SetSize(100, 22)
  b.back:SetPoint("BOTTOMLEFT", PAD, PAD)
  b.back:SetText(L["Back"])
  b.back:SetScript("OnClick", function() ns.SafeCall("tour", show, step - 1) end)
  b.next = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
  b.next:SetSize(100, 22)
  b.next:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  b.next:SetScript("OnClick", function()
    if step >= #STEPS then ns.SafeCall("tour", stop) else ns.SafeCall("tour", show, step + 1) end
  end)

  -- ESC blendet die Sprechblase aus: Das beendet die Tour
  b:SetScript("OnHide", function() ns.SafeCall("tour", stop) end)
  return b
end

-- zeigt Schritt i: Reiter umschalten, Ziel umrahmen, Sprechblase daneben
function show(i)
  if not (ns.frame and ns.frame:IsShown()) then stop(); return end
  step = i
  local s = STEPS[i]
  ns.frame.ShowView(s.view)
  bubble.text:SetText(L[s.text])
  bubble.count:SetText((L["Step %d of %d"]):format(i, #STEPS))
  bubble.count:ClearAllPoints()
  bubble.count:SetPoint("TOPLEFT", PAD, -PAD - bubble.text:GetStringHeight() - 8)
  bubble:SetHeight(PAD + bubble.text:GetStringHeight() + 8 + bubble.count:GetStringHeight() + 12 + 22 + PAD)
  bubble.back:SetShown(i > 1)
  bubble.next:SetText(i == #STEPS and L["Done"] or L["Next"])

  local target = s.target and s.target()
  bubble:ClearAllPoints()
  if target then
    frameRing:ClearAllPoints()
    frameRing:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
    frameRing:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
    frameRing:Show()
    if s.side == "RIGHT" then bubble:SetPoint("TOPLEFT", target, "TOPRIGHT", 14, 0)
    elseif s.side == "LEFT" then bubble:SetPoint("TOPRIGHT", target, "TOPLEFT", -14, 0)
    else bubble:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -10) end
  else
    frameRing:Hide()
    bubble:SetPoint("CENTER", ns.frame, "CENTER")
  end
  bubble:Show()
end

-- Startet die Tour (auch erneut, /fhp tour) bei offenem Fenster; merkt sich, dass sie gesehen wurde
function ns.StartTour()
  if not (ns.frame and ns.frame:IsShown()) then return end
  if not bubble then
    bubble, frameRing = create(), ring()
  end
  if not hooked then
    -- Schließen des Fensters bricht die Tour ab
    ns.frame:HookScript("OnHide", function() ns.SafeCall("tour", stop) end)
    hooked = true
  end
  ns.db.tourSeen = true
  if not step then prevView = ns.db.ui.view end
  show(1)
end

-- Beim Öffnen des Fensters (ns.Toggle): nur im Entdeckermodus und nur, wenn die Tour noch nie lief
function ns.MaybeTour()
  if ns.Discovering() and not ns.db.tourSeen then ns.StartTour() end
end

-- /fhp tour: die Tour noch einmal, nur im Entdeckermodus (sie erklärt ihn). Ohne gewählten Modus erst die
-- Startansicht; danach kommt die Tour von selbst, wenn sie noch nie lief.
function ns.TourCommand()
  if not ns.ModeChosen() then ns.Toggle(); return end
  if not ns.Discovering() then
    ns.Print(L["The tour explains explorer mode. Switch it on in the settings to take the tour."])
    return
  end
  if not (ns.frame and ns.frame:IsShown()) then ns.Toggle() end
  ns.StartTour()
end

-- für die Prüfung ohne Spiel: der aktuelle Schritt (nil = keine Tour) und Blättern wie mit den Knöpfen
function ns.TourStep() return step end
function ns.TourGo(i) if step then show(i) end end
function ns.TourStop() stop() end
