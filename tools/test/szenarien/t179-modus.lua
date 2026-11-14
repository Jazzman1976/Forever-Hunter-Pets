-- #179: /fhp modus bzw. /fhp mode schaltet den Modus um. Aus dem Entdeckermodus erst nach Rückfrage, zurück sofort;
-- umgeschaltet wird über dieselbe Einstellung wie im Menü (Häkchen zieht mit), danach eine Chatzeile. Ohne
-- gewählten Modus öffnet der Befehl die Startansicht. Der Befehl steht in der Hilfe.
-- lädt: UI/Widgets.lua UI/ModeDialog.lua
local de = NS.Locales.deDE
local plainCreateFrame = CreateFrame
local dialog
function CreateFrame(kind, name, ...)
  local f = plainCreateFrame(kind, name, ...)
  if name == "ForeverHunterPetsModeDialog" then dialog = f end
  return f
end

ForeverHunterPetsCharDB = { discover = true, modeChosen = true }
Login({})

-- die Einstellung aus UI/Settings.lua: SetValue schreibt den Wert und ruft den Rückruf wie im Spiel
local setValues = {}
NS.modeSetting = { SetValue = function(_, v)
  setValues[#setValues + 1] = v
  NS.char.discover = v
  NS.char.modeChosen = true
  NS.ModeChanged()
end }
local changed = 0
NS.OnModeChanged(function() changed = changed + 1 end)

-- Entdeckermodus: erst die Rückfrage, nichts umgeschaltet
SlashCmdList.FOREVERHUNTERPETS("modus")
ok(POPUPS[#POPUPS] == "FOREVERHUNTERPETS_COMPLETE_MODE", "Rückfrage vor dem Komplettmodus")
ok(NS.Discovering() and #setValues == 0, "vor der Bestätigung bleibt der Entdeckermodus")
local popup = StaticPopupDialogs.FOREVERHUNTERPETS_COMPLETE_MODE
ok(popup.text == de["Switch to complete mode? Then you see everything that is known right away, including what you have not discovered yet."], "Rückfrage übersetzt")
ok(popup.button1 == "Wechseln" and popup.button2 == "Abbrechen", "Knöpfe Wechseln und Abbrechen")
ok(popup.hideOnEscape and popup.timeout == 0, "ESC bricht ab, kein Zeitlimit")

-- bestätigt: über die Einstellung in den Komplettmodus, Chatzeile, Ansichten neu
local printed = #PRINTED
popup.OnAccept()
ok(setValues[#setValues] == false, "über die Einstellung umgeschaltet")
ok(NS.ModeChosen() and not NS.Discovering(), "jetzt Komplettmodus")
ok(changed == 1, "Ansichten bauen neu auf (" .. changed .. ")")
ok(#PRINTED == printed + 1 and PRINTED[#PRINTED]:find("Du bist jetzt im Komplettmodus."), "Chatzeile Komplettmodus")

-- aus dem Komplettmodus sofort zurück, ohne Rückfrage (englischer Befehl)
local popups = #POPUPS
SlashCmdList.FOREVERHUNTERPETS("mode")
ok(#POPUPS == popups, "keine Rückfrage auf dem Weg in den Entdeckermodus")
ok(NS.Discovering(), "sofort Entdeckermodus")
ok(PRINTED[#PRINTED]:find("Du bist jetzt im Entdeckermodus."), "Chatzeile Entdeckermodus")

-- ohne Einstellung (alter Client): über ns.SetMode
NS.modeSetting = nil
SlashCmdList.FOREVERHUNTERPETS("modus")
StaticPopupDialogs.FOREVERHUNTERPETS_COMPLETE_MODE.OnAccept()
ok(NS.ModeChosen() and not NS.Discovering(), "ohne Einstellung: Komplettmodus über ns.SetMode")

-- ohne gewählten Modus: die Startansicht
NS.char.modeChosen, NS.char.discover = nil, nil
SlashCmdList.FOREVERHUNTERPETS("modus")
ok(dialog ~= nil and dialog:IsShown(), "ohne gewählten Modus öffnet sich die Startansicht")

-- Hilfe nennt den Befehl
SlashCmdList.FOREVERHUNTERPETS("hilfe")
ok(PRINTED[#PRINTED]:find("/fhp modus %(Modus wechseln%)"), "Hilfe nennt /fhp modus")
ok(PRINTED[#PRINTED]:find("/fhp tour %(Tour noch einmal ansehen%)"), "Hilfe nennt /fhp tour")
