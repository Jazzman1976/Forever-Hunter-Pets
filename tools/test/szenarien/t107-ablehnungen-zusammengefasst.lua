-- #107: gleiche verworfene Nachrichten stehen einmal da, mit Zähler
local old = {}
for i = 1, 10 do old[i] = { at = 1, why = "unbekannter Zauber", way = "CHANNEL", msg = "O1;277882;5;1264478;;1792000000;aaaaaaa" .. (i % 2) } end
ForeverHunterPetsDB = { shareRejects = old, ui = { share = true } }
FireEvent("ADDON_LOADED", "Forever-Hunter-Pets")
FireEvent("PLAYER_LOGIN")
local A = "O1;277882;5;1264478;;1792000000;aaaaaaa1"
NOW = 1792500001
FireEvent("CHAT_MSG_ADDON", "FHPets", A, "CHANNEL", "Fremder Spieler")
local r = NS.db.shareRejects
ok(#r == 6, "gleiche alte Einträge zusammengefasst: " .. #r)
ok(r[#r].msg == A and r[#r].n == 6 and r[#r].at == NOW, "Zähler 6 (5 alte ohne n + 1), letzte Zeit, am Ende")
FireEvent("CHAT_MSG_ADDON", "FHPets", A, "WHISPER", "Anderer Spieler")
ok(#r == 6 and r[#r].n == 7, "nochmal: Zähler 7")
for i = 1, 25 do FireEvent("CHAT_MSG_ADDON", "FHPets", "O1;277882;5;1264478;;1792000000;bbbbbb" .. string.format("%02d", i), "CHANNEL", "X" .. i) end
ok(#r == 20, "höchstens 20 verschiedene")
ok(r[20].msg:sub(-2) == "25", "neueste am Ende")
PRINTED = {}
NS.ShareStatus()
local line
for _, m in ipairs(PRINTED) do if m:find("roh aufgehoben") then line = m end end
print(line)
ok(line and line:find("20 verschiedene, 20 Empfänge", 1, true), "/fhp teilen nennt Zahl und Summe")
