-- #63: Die Hilfe nennt nur die Befehle für Spieler, dazu /fhp start; die Entwicklerbefehle laufen weiter, stehen aber
-- nicht mehr darin. Die Ausgaben von /fhp gebiet und /fhp teilen sind übersetzt (hier: deutscher Client), gespeichert
-- wird weiter wie bisher (Gründe unter „Verworfen“ deutsch, Arten und Wege als Kürzel).

SENT = {}
C_ChatInfo.SendAddonMessage = function(_, msg, kind, target)
  SENT[#SENT + 1] = { msg = msg, kind = kind, target = target }
  if kind == "YELL" then return 4 end
  return 0
end
function IsInGuild() return true end
local function run() for _ = 1, 60 do RunTimers() end end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end
local slash = SlashCmdList.FOREVERHUNTERPETS

-- ---- Hilfe ----
Login({ ui = { share = true } })
PRINTED = {}
slash("hilfe")
local help = printed("Befehle:")
ok(help ~= nil, "unbekannter Befehl zeigt die Hilfe")
help = help or ""
for _, cmd in ipairs({ "gebiet", "suchen", "teilen", "modus", "start", "tour" }) do
  ok(help:find("/fhp " .. cmd .. " ", 1, true), "Hilfe nennt /fhp " .. cmd)
end
for _, cmd in ipairs({ "zonen", "erhebung", "api", "karte", "zaehmen", "besitzer", "test" }) do
  ok(not help:find(cmd, 1, true), "Hilfe nennt den Entwicklerbefehl " .. cmd .. " nicht")
end
-- der englische Schlüssel ebenso
local enHelp
for k in pairs(NS.Locales.deDE) do if k:find("^Commands:") then enHelp = k end end
ok(enHelp and enHelp:find("/fhp start", 1, true) and not enHelp:find("survey", 1, true)
  and not enHelp:find("zones", 1, true) and not enHelp:find("probe", 1, true), "englische Hilfe: start, keine Entwicklerbefehle")

-- ---- Entwicklerbefehle laufen weiter ----
for _, cmd in ipairs({ "erhebung", "zonen" }) do
  ERRORS = {}
  slash(cmd)
  ok(#ERRORS == 0, "/fhp " .. cmd .. " läuft weiter")
end

-- ---- /fhp start ----
local shown = 0
local rawShow = NS.ShowModeDialog
NS.ShowModeDialog = function() shown = shown + 1 end
slash("start")
ok(shown == 1, "/fhp start öffnet die Startansicht")
NS.ShowModeDialog = rawShow

-- ---- /fhp teilen: übersetzt, mit Verworfenem aus Empfang und Senden ----
run()   -- Gruß beim Einloggen: YELL lehnt der Client ab (Ergebnis 4)
FireEvent("CHAT_MSG_ADDON", "FHPets", "O1;kaputt", "GUILD", "Fremder Spieler")
FireEvent("CHAT_MSG_ADDON", "FHPets", "S1;kaputt", "WHISPER", "Anderer Spieler")
PRINTED = {}
slash("teilen")
ok(printed("^.-Teilen an · eigene Beobachtungen"), "Kopfzeile übersetzt")
ok(printed("Rufen: aus %(Ergebnis 4%)"), "Rufen aus, mit Ergebnis des Clients")
local dropped = printed("Verworfen: ") or ""
ok(dropped:find("Zähmungen – unlesbar 1", 1, true), "Verworfen: Art und Grund übersetzt (Zähmungen – unlesbar)")
ok(dropped:find("Sichtungen – unlesbar 1", 1, true), "Verworfen: Sichtungen – unlesbar")
ok(dropped:find("Rufen vom Client abgelehnt (Ergebnis 4) 1", 1, true), "Verworfen: Weg und Ergebnis übersetzt")
ok(not dropped:find("O1", 1, true) and not dropped:find("YELL", 1, true), "keine Kürzel unter „Verworfen“")
ok(printed("Empfangen je Weg: Gilde 1 · Gruppe 0 · Schlachtzug 0 · Flüstern 1"), "Wege übersetzt")
ok(printed("Zuletzt empfangen: Sichtungen über Flüstern"), "zuletzt empfangen: Art und Weg übersetzt")
-- gespeichert bleibt es wie bisher
local log = NS.db.shareLog[#NS.db.shareLog]
ok(log.dropped["O1 unlesbar"] == 1 and log.dropped["YELL vom Client abgelehnt (Ergebnis 4)"] == 1,
  "Verlauf speichert die Gründe wie bisher")
ok(log.recvWay.GUILD == 1, "Verlauf speichert die Wege als Kürzel")
-- kein englischer Schlüssel blieb stehen
local english = { "Tames", "Sightings", "Guild", "Whisper", "Yell", "unreadable", "rejected", "result", "Sharing",
  "Received", "Discarded", "Stored from", "Last received", "Known origin" }
local leaked
for _, p in ipairs(PRINTED) do
  for _, w in ipairs(english) do if p:find(w, 1, true) then leaked = w end end
end
ok(leaked == nil, "keine englischen Wörter in /fhp teilen" .. (leaked and (": " .. leaked) or ""))

-- ---- /fhp gebiet ----
local rawCell = NS.CellHere
NS.CellHere = function() return nil end
PRINTED = {}
slash("gebiet")
ok(printed("Keine Karte für den Standort%."), "ohne Karte: übersetzter Hinweis")
NS.CellHere = function() return 1429 end
PRINTED = {}
ERRORS = {}
slash("gebiet")
ok(#ERRORS == 0, "/fhp gebiet ohne Fehler")
ok(printed("%(Komplett%): Tiere %d+ von %d+ bekannt") or printed("%(Entdecker%): Tiere %d+ von %d+ gefunden"),
  "Fortschritt übersetzt")
ok(printed("Funde: %S+ · dieser Charakter"), "Funde übersetzt")
NS.CellHere = rawCell
