-- #171: Status-Wörter „Noch nie gesehen“ und „Tier studiert“; der Tier-Tooltip bekommt bei „Noch nie gesehen“
-- keine Status-Zeile, im Komplettmodus nie eine.
local NPC, MAP = 2323, 1439
local L = NS.L
ForeverHunterPetsCharDB = { discover = true, modeChosen = true }
Login({})
ok(NS.StatusWord("unknown") == L["never seen"], "unknown: " .. NS.StatusWord("unknown"))
ok(NS.StatusWord("track") == L["tracked"], "track: " .. NS.StatusWord("track"))
ok(NS.StatusWord("found") == L["beast found"], "found: " .. NS.StatusWord("found"))
ok(NS.StatusWord("known") == L["beast studied"], "known: " .. NS.StatusWord("known"))
ok(NS.BeastStatus(NPC, MAP) == "unknown" and NS.StatusText(NPC, MAP) == nil, "noch nie gesehen: keine Status-Zeile")

-- Fährte, dann gezähmt: „Tier studiert“
NS.db.seenIn = { [NPC] = tostring(MAP) }
NS.char.seenIn = { [NPC] = tostring(MAP) }
ok(NS.StatusText(NPC, MAP) == L["tracked"], "Fährte")
NS.db.obs = { ("%d;14;;;1792000010;"):format(NPC) }
NS.ObservationsChanged()
ok(NS.StatusText(NPC, MAP) == L["beast studied"], "gezähmt: " .. tostring(NS.StatusText(NPC, MAP)))

-- Komplettmodus: kein Status
NS.char.discover = false
ok(NS.StatusText(NPC, MAP) == nil, "Komplettmodus: keine Status-Zeile")

-- deutsche Texte stehen in Locales/deDE.lua
local de = NS.Locales.deDE
ok(de["never seen"] == "Noch nie gesehen" and de["beast studied"] == "Tier studiert", "deutsch: Noch nie gesehen, Tier studiert")
ok(de["abilities known"] == nil and de["? undiscovered beast"] == nil, "alte Schlüssel entfernt")
ok(de["hidden beast"] == "verborgenes Tier", "deutsch: verborgenes Tier")
