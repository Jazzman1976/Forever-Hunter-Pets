-- #61: volles via räumt Kürzel ab, die in keinem Speicher mehr stehen
local function rep(i) return string.format("%08x", 0x10000000 + i) end
local obs, via = {}, {}
for i = 1, 5000 do obs[i] = "30;5;17253;;" .. (1792000000 + i) .. ";" .. rep(i) end
for i = 1, 5000 do via[rep(200000 + i)] = "abcdef01" end   -- 5000 Kürzel, die in keinem Speicher stehen
via[rep(3000)] = "abcdef01"; via[rep(200001)] = nil
ForeverHunterPetsDB = { obs = obs, via = via, viaLegacy = { [rep(200002)] = true, [rep(4000)] = true }, ui = { share = true } }
FireEvent("ADDON_LOADED", "Forever-Hunter-Pets")
FireEvent("PLAYER_LOGIN")
FireEvent("CHAT_MSG_ADDON", "FHPets", "O1;30;5;17253;;1792400000;" .. rep(999), "CHANNEL", "Fremder Spieler")
for _, m in ipairs(PRINTED) do if m:find("Error") or m:find("Fehler") then print(m) end end
ok(NS.ObservationCount() == 4751, "Zähmung über den Kanal trotz vollem Speicher gespeichert")
ok(NS.db.obs[4751]:find(rep(999), 1, true), "neue Zähmung hinten")
local n = 0; for _ in pairs(NS.db.via) do n = n + 1 end
ok(NS.db.via[rep(999)] ~= nil, "Herkunft der neuen Zähmung vermerkt")
ok(NS.db.via[rep(3000)] ~= nil, "Herkunft eines gespeicherten Melders bleibt")
ok(n == 2, "verdrängte bzw. nirgends gespeicherte Kürzel aus via entfernt: " .. n)
ok(not NS.db.viaLegacy[rep(200002)] and NS.db.viaLegacy[rep(4000)], "viaLegacy ebenso aufgeräumt")
NS.db.shareStats = nil
