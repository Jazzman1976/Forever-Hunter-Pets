-- #124: Die Stammdaten dominieren. Ein eigener Treffer am Tooltip (ForeverHunterPetsDB.owned) sperrt ein Tier nicht
-- auf einer Karte, auf der die Stammdaten es führen; Tiere, die ein Spieler steuert, werden nie gemerkt; eine eigene
-- Zähmung hebt einen Treffer auf.

-- Besitzerzeile, Steuerung durch Spieler, Ort. ns.HasOwner liest den Zeilentyp schon beim Laden der Datei (vor dem
-- Szenario) und ist unverändert; hier steht es deshalb direkt für „Tooltip nennt einen Besitzer“.
Enum = { SpellBookSpellBank = { Pet = 1 } }
local owner, controlled, charmed = true, false, false
NS.HasOwner = function() return owner end
function UnitPlayerControlled() return controlled end
function UnitIsCharmed() return charmed end
function UnitName() return "Testtier" end
function UnitLevel() return 8 end

local LEO, DUN, ELSE = 1201, 1426, 1411   -- Schneeleopard, in den Stammdaten nur in Dun Morogh
Login({ ui = { share = true }, owned = {
  [LEO] = { name = "Schneeleopard", maps = { [DUN] = 1, [ELSE] = 1 } },
} })
local map = DUN
NS.CellHere = function() return map, "MN" end

ok(NS.Data.beasts[LEO] and NS.BeastInData(LEO, DUN), "Schneeleopard steht in den Stammdaten für Dun Morogh")
ok(not NS.BeastInData(LEO, ELSE), "… nicht für die andere Karte")

-- 1. Stammdaten vor lokaler Sperre
ok(not NS.Blocked(LEO, DUN), "alter Treffer in Dun Morogh sperrt nicht")
ok(NS.Blocked(LEO, ELSE), "alter Treffer auf einer Karte ohne Stammdaten sperrt weiter")
ok(NS.AddCells(LEO, DUN, "MN") > 0, "eigene Zelle in Dun Morogh wird angenommen")
ok(NS.AddCells(LEO, DUN, "MO", "abcdef01") > 0, "fremde Zelle in Dun Morogh wird angenommen")
ok(not NS.BlockedSighting(LEO, 8), "Sichtung des Schneeleoparden zählt")

-- NPC-Begleiter mit einer NPC aus den Stammdaten auf ihrer Karte: kein Treffer, keine Zellen weg
local n = 0
local guid = function(npc) n = n + 1; return ("Creature-0-0-0-0-%d-%010d"):format(npc, n) end
ok(NS.Excluded("mouseover", LEO, guid(LEO)), "die Einheit mit Besitzer selbst bekommt keine Zeilen")
ok(NS.db.loc[LEO] and NS.db.loc[LEO][DUN], "Zellen in Dun Morogh bleiben")
ok(NS.db.owned[LEO].maps[DUN] == 1, "kein neuer Zeitstempel für Dun Morogh")

-- 2. Tiere von Spielern werden nie gemerkt
local X1, X2, X3 = 990101, 990102, 990103   -- nicht in den Stammdaten
controlled, charmed = true, false
ok(NS.Excluded("mouseover", X1, guid(X1)), "vom Spieler gesteuert: keine Zeilen")
ok(not NS.db.owned[X1], "vom Spieler gesteuert: nicht gemerkt")
controlled, charmed = false, true
NS.Excluded("mouseover", X2, guid(X2))
ok(not NS.db.owned[X2], "bezaubert (Zähmstab): nicht gemerkt")
controlled, charmed = nil, false
NS.Excluded("mouseover", X2, guid(X2))
ok(not NS.db.owned[X2], "unklare Antwort: lieber nicht gemerkt")
controlled, charmed = false, false
ok(NS.Excluded("mouseover", X3, guid(X3)), "NPC-Begleiter: keine Zeilen")
ok(NS.db.owned[X3] and NS.db.owned[X3].maps[DUN], "NPC-Begleiter: gemerkt")
ok(NS.Blocked(X3, DUN), "NPC-Begleiter ohne Stammdaten: gesperrt")
owner = false
ok(not NS.Excluded("mouseover", 990104, guid(990104)), "wildes Tier ohne Besitzer: nicht ausgeschlossen")

-- 3. Eine eigene Zähmung hebt den Treffer auf dieser Karte auf
local target, hasPet = X3, false
function UnitGUID(unit) return unit == "target" and ("Creature-0-0-0-0-%d-0000000001"):format(target) or nil end
function UnitExists(unit) return unit == "pet" and hasPet end
function UnitAttackSpeed() return 2.0 end
C_SpellBook = {
  HasPetSpells = function() return hasPet and 1 or 0 end,
  GetSpellBookItemInfo = function() return { spellID = 2649 } end,
}
NS.db.owned[X3].maps[ELSE] = 1
CLOCK = 1000
FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 1515)
CLOCK = 1020; FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 1515)
CLOCK = 1020.1; hasPet = true; FireEvent("UNIT_PET", "player")
RunTimers()
local tamed = false
for _, o in ipairs(NS.ObservationsOf(X3)) do if o.own then tamed = true end end
ok(tamed, "Zähmung gespeichert")
ok(NS.db.owned[X3] and not NS.db.owned[X3].maps[DUN] and NS.db.owned[X3].maps[ELSE], "Treffer nur auf der Karte der Zähmung weg")
ok(not NS.Blocked(X3, DUN), "nach der Zähmung nicht mehr gesperrt")
ok(NS.db.loc[X3] and NS.db.loc[X3][DUN], "Zelle der Zähmung gespeichert")
NS.db.owned[X3].maps[ELSE] = nil
NS.db.owned[X3].maps[DUN] = 1
target, hasPet = X3, false
CLOCK = 2000
FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 1515)
CLOCK = 2020; FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 1515)
CLOCK = 2020.1; hasPet = true; FireEvent("UNIT_PET", "player")
ok(NS.db.owned[X3] == nil, "letzte Karte weg: Eintrag ganz entfernt")
