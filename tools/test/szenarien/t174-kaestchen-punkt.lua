-- #174: Das Kästchen hat neben dem Haken einen Punkt (Reiter „Gebiet“, Entdeckermodus: „Tier gefunden“), anfangs
-- versteckt; „Fähigkeiten“ nutzt ihn nicht. Karte und Kästchen nehmen dieselbe Scheibe (W.DISK).
-- lädt: UI/Widgets.lua UI/MapCanvas.lua
Login({})
local W = NS.W
ok(W.DISK == "Interface\\CharacterFrame\\TempPortraitAlphaMask", "Scheibe: " .. tostring(W.DISK))
local box = W.CheckBox(CreateFrame())
ok(box.dot ~= nil and box.check ~= nil, "Kästchen hat Punkt und Haken")
ok(not box.dot:IsShown(), "Punkt anfangs versteckt")

-- deutsche Wörter für den Tooltip am Zähler „Tiere“
local de = NS.Locales.deDE
ok(de["no box"] == "kein Kästchen" and de["empty box"] == "leeres Kästchen" and de["dot"] == "Punkt"
  and de["tick"] == "Haken", "deutsch: kein Kästchen, leeres Kästchen, Punkt, Haken")
