-- #68: Der Selbsttest speichert keine Spielernamen in ForeverHunterPetsDB.probe, nur Kürzel; das Protokoll
-- einer Probe bleibt einen Tag liegen und räumt sich dann beim Laden selbst weg.

-- Selbsttest mit einer fremden und der eigenen Testnachricht
Login({ ui = { share = true } })
NS.ShareTest()
FireEvent("CHAT_MSG_ADDON", "FHPets", "O1;30;5;17253;;1792400000;abcdef01", "CHANNEL", "Fremder Spieler")
FireEvent("CHAT_MSG_ADDON", "FHPets", "T1;0000;Flüstern;x", "WHISPER", "Test-Realm")
for _ = 1, 20 do RunTimers() end
local probe = NS.db.probe
ok(type(probe) == "table" and #probe > 0, "Selbsttest hat ein Protokoll geschrieben")
local all = table.concat(probe, "\n")
ok(not all:find("Fremder", 1, true), "kein fremder Spielername im Protokoll")
ok(not all:find("Test-Realm", 1, true) and not all:find("Test Realm", 1, true), "eigener Name nicht im Protokoll")
ok(all:find("eigenes Kürzel %x+"), "statt dessen das eigene Kürzel")
ok(all:find("von %x%x%x%x%x%x%x%x über"), "empfangene Nachrichten mit Kürzel des Absenders")
ok(NS.db.probeAt == NOW, "Zeitpunkt des Protokolls gespeichert")

-- Beim Laden: älter als ein Tag weg, jünger bleibt, ohne Zeitpunkt weg
Login({ probe = { "alt" }, probeAt = NOW - 2 * 86400 })
ok(NS.db.probe == nil and NS.db.probeAt == nil, "Protokoll von vor 2 Tagen beim Laden gelöscht")
Login({ probe = { "frisch" }, probeAt = NOW - 3600 })
ok(NS.db.probe and NS.db.probe[1] == "frisch", "Protokoll von vor einer Stunde bleibt")
Login({ probe = { "ohne Zeit" } })
ok(NS.db.probe == nil, "Protokoll ohne Zeitpunkt (vor diesem Stand) gelöscht")
