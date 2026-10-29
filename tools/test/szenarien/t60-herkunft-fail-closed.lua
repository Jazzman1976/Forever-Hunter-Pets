-- #60: Herkunft „fail closed“ – alte Kürzel nach viaLegacy, ohne Herkunft zählt nichts
ForeverHunterPetsDB = {
  obs = { "30;5;17253;;1792000000;aaaaaaa1", "30;5;17253;;1792000001;aaaaaaa2" },
  sights = { "30;5;0;3;deDE;Waldspinne;1792000002;aaaaaaa3" },
  locIn = { [30] = { [1429] = { aaaaaaa4 = "0A", ["-"] = "0B" } } },
  via = { aaaaaaa2 = "bbbbbbb1" },
}
FireEvent("ADDON_LOADED", "Forever-Hunter-Pets")
FireEvent("PLAYER_LOGIN")
for _, m in ipairs(PRINTED) do if m:find("Error") or m:find("Fehler") then print(m) end end
local lg = NS.db.viaLegacy
ok(type(lg) == "table", "viaLegacy angelegt")
ok(lg.aaaaaaa1 and lg.aaaaaaa3 and lg.aaaaaaa4, "alte Kürzel ohne Herkunft markiert (Zähmung, Sichtung, Zelle)")
ok(not lg.aaaaaaa2, "Kürzel mit Herkunft nicht markiert")
ok(lg["-"] == nil, "Altmelder - nicht markiert")
-- Markierung läuft nur einmal
NS.db.obs[#NS.db.obs + 1] = "30;5;17253;;1792000003;ccccccc1"
FireEvent("PLAYER_LOGIN")
ok(not NS.db.viaLegacy.ccccccc1, "Markierung läuft nicht erneut")
local V = NS.ViaDistinct
NS.db.via = { d1 = "eeeeeee1", d2 = "eeeeeee1", d3 = "eeeeeee1", d4 = "eeeeeee2" }
ok(not V({ d1 = true, d2 = true, d3 = true }), "ein Absender genügt nicht")
ok(V({ d1 = true, d2 = true, d4 = true }), "zwei Absender genügen")
ok(not V({ d1 = true, d2 = true, neu = true }), "Kürzel ohne Herkunft zählt nicht mehr (#60)")
ok(V({ d1 = true, d2 = true, aaaaaaa1 = true }), "Kürzel aus viaLegacy zählt")
NS.db.via = "kaputt"
ok(not V({ x = true, y = true, z = true }), "kaputter Speicher zählt nicht")
