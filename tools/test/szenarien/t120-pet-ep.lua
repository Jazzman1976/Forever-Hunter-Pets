-- #120: EP-Leiste und Stufe am Pet-Rahmen. Füllstand, Tooltip, Höchststufe, kein Pet, geheime Werte, Einstellungen.
-- lädt: UI/PetXP.lua

-- Pet-Rahmen des Clients und die API rund ums Pet
PetFrame, PetFrameManaBar = CreateFrame(), CreateFrame()
local hasPet, petLevel, hunterLevel, cur, max = true, 17, 20, 1234, 3300
function UnitExists(unit) return unit == "pet" and hasPet end
function UnitLevel(unit)
  if unit == "pet" then return hasPet and petLevel or 0 end
  return hunterLevel
end
function GetPetExperience() return cur, max end
GameTooltip = CreateFrame()

Login()
local bar, badge = NS.PetXPFrames()
ok(bar ~= nil and badge ~= nil, "Leiste und Kreis beim Einloggen erzeugt")
ok(NS.db.ui.petFrame == true and NS.db.ui.petFrameLevel == true and NS.db.ui.petFrameXP == true,
  "alle drei Einstellungen standardmäßig an")

-- normaler Stand
FireEvent("UNIT_PET_EXPERIENCE", "player")
ok(bar.shown == true and math.abs(bar.value - 1234 / 3300) < 1e-9, "Leiste sichtbar, Füllstand 1234/3300")
ok(badge.shown == true and badge.text.text == "17", "Kreis zeigt Stufe 17")
local tip = NS.PetXPTooltip(NS.PetXPState())
ok(tip[1] == "Stufe 17 – 1234 / 3300 EP (37 %)", "Tooltip Zeile 1: " .. tostring(tip[1]))
ok(tip[2] == "Noch 2066 EP bis Stufe 18", "Tooltip Zeile 2: " .. tostring(tip[2]))

-- Tausenderpunkte, wenn der Client sie liefert
function BreakUpLargeNumbers(n) return (tostring(n):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
tip = NS.PetXPTooltip(NS.PetXPState())
ok(tip[1] == "Stufe 17 – 1.234 / 3.300 EP (37 %)", "Tooltip mit Tausenderpunkten: " .. tostring(tip[1]))
BreakUpLargeNumbers = nil

-- Höchststufe: Pet hat die Stufe des Jägers
petLevel = 20
FireEvent("UNIT_LEVEL", "pet")
ok(bar.shown == true and bar.value == 1, "Höchststufe (Stufe des Jägers): Leiste voll")
tip = NS.PetXPTooltip(NS.PetXPState())
ok(#tip == 1 and tip[1] == "Stufe 20 – Max", "Höchststufe: Tooltip „Max“ statt EP")
-- Höchststufe: Client meldet 0 nötige EP
petLevel, max = 17, 0
FireEvent("UNIT_PET_EXPERIENCE", "player")
ok(bar.value == 1 and NS.PetXPTooltip(NS.PetXPState())[1] == "Stufe 17 – Max", "nötige EP 0: ebenfalls Max")
max = 3300

-- kein Pet
hasPet = false
FireEvent("UNIT_PET", "player")
ok(bar.shown == false and badge.shown == false, "kein Pet: Leiste und Kreis verborgen")
hasPet = true
FireEvent("UNIT_PET", "player")
ok(bar.shown == true and badge.shown == true, "Pet wieder da: beides sichtbar")

-- geheime Werte (Kampf, Instanz): kein Fehler, nichts Falsches
SECRETS[cur], SECRETS[max], SECRETS[petLevel] = true, true, true
FireEvent("UNIT_PET_EXPERIENCE", "player")
ok(bar.shown == false and badge.shown == false, "geheime Werte: nichts gezeigt, kein Fehler")
SECRETS = {}
FireEvent("UNIT_PET_EXPERIENCE", "player")
ok(bar.shown == true and badge.shown == true, "nach dem Kampf: wieder sichtbar")

-- Einstellungen
NS.db.ui.petFrameLevel = false
NS.UpdatePetXP()
ok(bar.shown == true and badge.shown == false, "„Aktuelle Stufe anzeigen“ aus: nur die Leiste")
NS.db.ui.petFrameLevel, NS.db.ui.petFrameXP = true, false
NS.UpdatePetXP()
ok(bar.shown == false and badge.shown == true, "„Erfahrungsleiste anzeigen“ aus: nur der Kreis")
NS.db.ui.petFrameXP, NS.db.ui.petFrame = true, false
NS.UpdatePetXP()
ok(bar.shown == false and badge.shown == false, "Hauptschalter aus: beides verborgen")
NS.db.ui.petFrame = true
NS.UpdatePetXP()
ok(bar.shown == true and badge.shown == true, "Hauptschalter wieder an: beides da")

-- ohne GetPetExperience (API fehlt) erzeugt ein neues Einloggen nichts und wirft nicht
GetPetExperience = nil
ok(NS.PetXPState() ~= nil and NS.PetXPState().cur == nil, "ohne GetPetExperience: Stufe ja, EP nein")
