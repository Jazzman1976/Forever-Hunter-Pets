-- #178: Tour beim ersten Öffnen im Entdeckermodus. Sie startet nur im Entdeckermodus und nur, wenn sie auf diesem
-- Account noch nie lief (ns.db.tourSeen, beim Start gesetzt); ein zweiter Charakter sieht sie nicht erneut.
-- Sie schaltet je Schritt den Reiter um, lässt sich mit X, ESC und durch Schließen des Fensters abbrechen und
-- kehrt dann zum Reiter von vorher zurück. /fhp tour zeigt sie erneut, im Komplettmodus nur einen Hinweis.
-- lädt: UI/Widgets.lua UI/Tour.lua
local de = NS.Locales.deDE
local translated = {}
for _, text in pairs(de) do translated[text] = true end

local plainCreateFrame = CreateFrame
local bubble
function CreateFrame(kind, name, ...)
  local f = plainCreateFrame(kind, name, ...)
  if name == "ForeverHunterPetsTour" then bubble = f end
  return f
end

ForeverHunterPetsCharDB = { discover = false, modeChosen = true }
Login({})
NS.db.ui.view = "abilities"

-- das Fenster, wie UI/Main.lua es der Tour bereitstellt
local views = {}
local frame = CreateFrame()
frame.ShowView = function(key) views[#views + 1] = key; NS.db.ui.view = key end
frame.tabs = { abilities = CreateFrame(), area = CreateFrame(), training = CreateFrame() }
frame.area = { tour = { list = CreateFrame(), box = CreateFrame(), map = CreateFrame(), counters = CreateFrame() } }
frame:Show()
NS.frame = frame
local toggled = 0
NS.Toggle = function() toggled = toggled + 1; frame:Show() end

-- Komplettmodus: keine Tour
NS.MaybeTour()
ok(NS.TourStep() == nil and not NS.db.tourSeen, "Komplettmodus: keine Tour, nichts gemerkt")

-- Entdeckermodus, noch nie gesehen: Tour ab Schritt 1, sofort gemerkt
NS.char.discover = true
NS.MaybeTour()
ok(NS.TourStep() == 1, "Entdeckermodus: Tour startet bei Schritt 1")
ok(NS.db.tourSeen == true, "tourSeen schon beim Start gesetzt (je Account)")
ok(bubble ~= nil and bubble:IsShown(), "Sprechblase sichtbar")
ok(table.concat(UISpecialFrames, ","):find("ForeverHunterPetsTour"), "ESC schließt die Sprechblase")
ok(views[#views] == "area", "Schritt 1 im Reiter „Gebiet“")
ok(translated[bubble.text.text], "Schritt 1 übersetzt")
ok(bubble.count.text == "Schritt 1 von " .. NS.TOUR_STEPS, "Schrittzähler: " .. tostring(bubble.count.text))
ok(NS.TOUR_STEPS == 7, "sieben Schritte")

-- vorwärts durch alle Schritte, je mit Übersetzung und passendem Reiter
local want = { "area", "area", "area", "area", "area", "abilities", "training" }
for i = 2, NS.TOUR_STEPS do
  bubble.next.scripts.OnClick()
  ok(NS.TourStep() == i, "Weiter zu Schritt " .. i)
  ok(views[#views] == want[i], "Schritt " .. i .. " im Reiter " .. want[i])
  ok(translated[bubble.text.text], "Schritt " .. i .. " übersetzt")
end
ok(bubble.next.text == "Fertig", "letzter Schritt: Fertig")
bubble.back.scripts.OnClick()
ok(NS.TourStep() == NS.TOUR_STEPS - 1, "Zurück")
ok(bubble.next.text == "Weiter", "wieder Weiter")
bubble.next.scripts.OnClick()
bubble.next.scripts.OnClick()
ok(NS.TourStep() == nil, "Fertig beendet die Tour")
ok(not bubble:IsShown(), "Sprechblase weg")
ok(NS.db.ui.view == "abilities", "zurück im Reiter von vorher (" .. tostring(NS.db.ui.view) .. ")")

-- schon gesehen: kommt nicht wieder, auch nicht auf einem anderen Charakter
NS.MaybeTour()
ok(NS.TourStep() == nil, "gesehen: keine Tour beim nächsten Öffnen")
NS.char = { discover = true, modeChosen = true }
NS.MaybeTour()
ok(NS.TourStep() == nil, "zweiter Charakter: keine Tour")

-- /fhp tour: erneut, auch bei geschlossenem Fenster
frame:Hide()
NS.TourCommand()
ok(toggled == 1, "/fhp tour öffnet das Fenster")
ok(NS.TourStep() == 1, "/fhp tour startet die Tour erneut")

-- Abbrechen mit X
bubble.close.scripts.OnClick()
ok(NS.TourStep() == nil, "X bricht ab")

-- Abbrechen mit ESC (blendet die Sprechblase aus)
NS.TourCommand()
NS.TourGo(3)
bubble:Hide()
bubble.scripts.OnHide()
ok(NS.TourStep() == nil, "ESC bricht ab")

-- Fenster geschlossen: Die Tour geht nicht weiter
NS.TourCommand()
frame:Hide()
NS.TourGo(2)
ok(NS.TourStep() == nil, "Fenster zu: Tour beendet")
frame:Show()

-- Komplettmodus: /fhp tour nur mit Hinweis
NS.char.discover = false
local printed = #PRINTED
NS.TourCommand()
ok(NS.TourStep() == nil, "Komplettmodus: /fhp tour startet nichts")
ok(#PRINTED == printed + 1 and PRINTED[#PRINTED]:find("Entdeckermodus"), "Komplettmodus: Hinweis im Chat")

-- ohne Ansicht „Gebiet“ (keine Zone bekannt): Sprechblase in der Fenstermitte, kein Fehler
NS.char.discover = true
frame.area = {}
NS.TourCommand()
NS.TourGo(2)
ok(NS.TourStep() == 2, "ohne Ziel weiter möglich")
NS.TourStop()
