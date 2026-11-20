-- #71: Jede Kampfprüfung läuft über ns.InCombat(). Er liefert immer true oder false; ein geheimer Wert gilt als
-- Kampf, damit liegen bleibt, was im Kampf nicht gelesen werden darf. Ohne InCombatLockdown: kein Kampf.

Login({})
ok(NS.InCombat() == false, "außerhalb des Kampfs: false")

local raw = InCombatLockdown
InCombatLockdown = function() return true end
ok(NS.InCombat() == true, "im Kampf: true")

-- geheimer Wert: nie vergleichen, als Kampf werten
InCombatLockdown = function() return false end
SECRETS[false] = true
local okCall, res = pcall(NS.InCombat)
ok(okCall and res == true, "geheimer Wert: kein Fehler, gilt als Kampf")
SECRETS[false] = nil

-- Was der Client sonst liefert (nil), ist kein Kampf, aber immer ein Wahrheitswert
InCombatLockdown = function() return nil end
ok(NS.InCombat() == false, "nil vom Client: false")

InCombatLockdown = nil
ok(NS.InCombat() == false, "ohne InCombatLockdown: false")
InCombatLockdown = raw

-- Im Kampf liest die Erhebung das Zauberbuch nicht (vorher eigenes inCombat in Core/Survey.lua)
function UnitExists(unit) return unit == "pet" end
function UnitCreatureFamily() return "Eber", 5 end
Enum = { SpellBookSpellBank = { Pet = 1 } }
C_SpellBook = {
  HasPetSpells = function() return 1 end,
  GetSpellBookItemInfo = function() return { spellID = 17253, name = "Beißen", subName = "Rang 1" } end,
}
Login({})
InCombatLockdown = function() return true end
local okRead = pcall(NS.SurveyPetSpells, true)
ok(okRead, "Zauberbuch im Kampf: kein Fehler")
ok(not (NS.db.survey and NS.db.survey.petRead), "Zauberbuch im Kampf nicht gelesen")
InCombatLockdown = raw
NS.SurveyPetSpells(true)
ok(NS.db.survey and NS.db.survey.petRead and #NS.db.survey.petRead == 1, "Gegenprobe: außerhalb des Kampfs gelesen")
