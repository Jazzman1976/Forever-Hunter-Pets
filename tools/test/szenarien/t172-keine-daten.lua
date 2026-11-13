-- #172: „Keine Daten bekannt“ mit rotem X (ns.NoData) statt „? unbekannt“ bzw. „? unklar“, ohne „?“ davor.
-- Komplettmodus: Ein Tier ohne jede Angabe zeigt ns.NoData(), eines mit Lehre nicht.
-- Riesiger Waldschreiter (2323) lehrt nach den Stammdaten Ducken 2; 990172 steht nirgends.
local L = NS.L
ForeverHunterPetsCharDB = { discover = false, modeChosen = true }
Login({})
ok(not NS.Discovering(), "Komplettmodus")

local nd = NS.NoData()
ok(nd:find(L["No data known"], 1, true), "Text „Keine Daten bekannt“: " .. nd)
ok(nd:find("|T", 1, true) and nd:find("ReadyCheck-NotReady", 1, true), "mit rotem X als Textur")
ok(not nd:find("?", 1, true), "kein „?“")
ok(NS.NoData("x"):sub(-1) == "x", "eigener Text hinter dem X")

-- in der Zeile im Reiter „Gebiet“ kurz „Keine Daten“ (sonst schnitt sie ab), mit demselben X
ok(NS.TeachText(990172) == NS.NoData(L["No data"]), "Tier ohne jede Angabe, Zeile: " .. NS.TeachText(990172))
ok(not NS.TeachText(2323):find(L["No data"], 1, true), "Tier mit Lehre: kein „Keine Daten“")

-- deutsche Texte stehen in Locales/deDE.lua, die alten Schlüssel sind weg
local de = NS.Locales.deDE
ok(de["No data known"] == "Keine Daten bekannt" and de["No data"] == "Keine Daten", "deutsch: Keine Daten bekannt, kurz Keine Daten")
ok(de["? unknown"] == nil and de["? unclear"] == nil
  and de["? Unknown – nobody has found a beast that teaches it yet."] == nil, "alte Schlüssel entfernt")
