-- #105: Eine Zähmung gilt nur, wenn das Pet höchstens 10 s nach dem Ende des Kanals da ist; ohne Ende verfällt sie
-- 30 s nach Beginn; ein Abbruch speichert nichts.
Login({ ui = { share = true } })

local spell
for _, a in ipairs(NS.Data.abilities) do
  if a.source == "tame" and NS.Learnable(a) and not spell then spell = a.ranks[1].id end
end

-- Ziel, Pet und Zauberbuch
local target, hasPet = 990010, false
function UnitGUID(unit) return unit == "target" and ("Creature-0-0-0-0-%d-0000000001"):format(target) or nil end
function UnitLevel() return 12 end
function UnitExists(unit) return unit == "pet" and hasPet end
function UnitAttackSpeed() return 2.0 end
Enum = { SpellBookSpellBank = { Pet = 1 } }
C_SpellBook = {
  HasPetSpells = function() return hasPet and 1 or 0 end,
  GetSpellBookItemInfo = function() return { spellID = spell } end,
}

local function start(npc)
  target, hasPet = npc, false
  FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 1515)
end
local function stop() FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast", 1515) end
local function pet()
  hasPet = true
  FireEvent("UNIT_PET", "player")
end
local function stored(npc)
  for _, o in ipairs(NS.ObservationsOf(npc)) do if o.own then return true end end
  return false
end

-- Erfolg: Ende nach 20 s, Pet 0,1 s danach
CLOCK = 1000
start(990010)
CLOCK = 1020; stop()
CLOCK = 1020.1; pet()
ok(stored(990010), "Pet 0,1 s nach dem Ende: gespeichert")
RunTimers()

-- Pet erst 11 s nach dem Ende
CLOCK = 2000
start(990011)
CLOCK = 2020; stop()
CLOCK = 2031; pet()
ok(not stored(990011), "Pet 11 s nach dem Ende: nicht gespeichert")

-- Pet 9,9 s nach dem Ende, Kanal etwas länger (Beginn 31 s zurück): gespeichert
CLOCK = 3000
start(990012)
CLOCK = 3021; stop()
CLOCK = 3030.9; pet()
ok(stored(990012), "Pet 9,9 s nach dem Ende, 30,9 s nach Beginn: gespeichert")
RunTimers()

-- kein Ende: Pet nach 31 s
CLOCK = 4000
start(990013)
CLOCK = 4031; pet()
ok(not stored(990013), "ohne Ende, Pet 31 s nach Beginn: nicht gespeichert")

-- abgebrochen
CLOCK = 5000
start(990014)
CLOCK = 5005; FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "cast", 1515)
CLOCK = 5020; stop()
CLOCK = 5020.1; pet()
ok(not stored(990014), "unterbrochen: nicht gespeichert")

-- nach einem verfallenen Zähmen läuft das nächste normal
CLOCK = 6000
start(990015)
CLOCK = 6020; stop()
CLOCK = 6040; pet()
ok(not stored(990015), "verfallen")
CLOCK = 7000
start(990016)
CLOCK = 7020; stop()
CLOCK = 7020.1; pet()
ok(stored(990016), "nächstes Zähmen danach: gespeichert")
