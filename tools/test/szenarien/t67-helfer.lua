-- #67: Doppelte Helfer zusammengeführt. ns.Quiet (vorher je eine Kopie in Comm, Sightings, Tooltip), ns.NpcFromGuid
-- (auch im Tooltip), ns.RankById (auch für die geteilten Lesungen), W.Border (Hauptfenster, Startansicht).
-- lädt: UI/Widgets.lua

Login({})

-- ns.Quiet: Kampf oder Instanz
ok(NS.Quiet() == false, "draußen, ohne Kampf: nicht still")
local rawCombat, rawInstance = InCombatLockdown, IsInInstance
InCombatLockdown = function() return true end
ok(NS.Quiet() == true, "im Kampf: still")
InCombatLockdown = rawCombat
IsInInstance = function() return true end
ok(NS.Quiet() == true, "in einer Instanz: still")
IsInInstance = function() return "geheim" end
SECRETS["geheim"] = true
ok(NS.Quiet() == true, "geheimer Wert der Instanz: still, wie beim Kampf")
SECRETS["geheim"] = nil
IsInInstance = function() error("kaputt") end
ok(pcall(NS.Quiet), "Fehler in IsInInstance reißt nichts mit")
IsInInstance = rawInstance

-- ns.NpcFromGuid: nur Kreaturen, nichts Geheimes
ok(NS.NpcFromGuid("Creature-0-5250-0-12-525-0000ABCDEF") == 525, "NPC-ID aus einer Kreatur-GUID")
ok(NS.NpcFromGuid("Player-1234-0ABCDEF0") == nil, "Spieler: nil")
ok(NS.NpcFromGuid("Pet-0-5250-0-12-525-0000ABCDEF") == nil, "Pet: nil")
local secretGuid = "Creature-0-1-0-1-999-0000000001"
SECRETS[secretGuid] = true
ok(NS.NpcFromGuid(secretGuid) == nil, "geheime GUID: nil")
SECRETS[secretGuid] = nil

-- ns.RankById: Rang einer lernbaren Fähigkeit, nichts für Unbekanntes
local any
for _, a in ipairs(NS.Data.abilities) do
  if NS.Learnable(a) and a.ranks[1] and a.ranks[1].id > 0 then any = { a = a, r = a.ranks[1] }; break end
end
local hit = any and NS.RankById(any.r.id)
ok(hit and hit.a == any.a and hit.r == any.r, "ns.RankById findet Fähigkeit und Rang")
ok(NS.RankById(-12345) == nil, "unbekannte ID: nil")

-- W.Border: vier Linien am Rahmen, ohne Fehler
local made = 0
local f = CreateFrame()
f.CreateTexture = function() made = made + 1; return CreateFrame() end
ok(pcall(NS.W.Border, f) and made == 4, "W.Border legt vier Linien an")
