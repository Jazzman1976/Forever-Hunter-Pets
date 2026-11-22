-- Forever Hunter Pets · Start: Sprache, gespeicherte Daten, Ereignisse, Slash-Befehl
local ADDON, ns = ...
ns.ADDON = ADDON

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or "?"

-- ---- Sprache: der Schlüssel ist der englische Text, Locales/*.lua übersetzen ----
local strings = (ns.Locales or {})[GetLocale and GetLocale() or "enUS"] or {}
ns.L = setmetatable({}, { __index = function(_, k) return strings[k] or k end })
local L = ns.L

-- ---- Schwellen für fremde Meldungen (#103) ----
-- Was andere Spieler melden, gilt ab FOREIGN_SURE verschiedenen Meldern als belegt, ab FOREIGN_UNSURE als unsicher
-- (nur Lehrtier-Paare; gezeigt nur mit „Unsichere Angaben zeigen“). Die Melder müssen dabei über mindestens zwei
-- verschiedene Absender gekommen sein (#15, ns.ViaDistinct in Core/Comm.lua). Die Zahlen stehen nur hier und in
-- tools/build-data.mjs; sie werden angehoben, wenn mehr Spieler das Addon nutzen.
ns.FOREIGN_SURE = 3     -- bis 17.10.2026: 10 (#1)
ns.FOREIGN_UNSURE = 2   -- seit #103; vorher genügte ein einziger Melder

-- ---- Helfer ----
-- In Kampf und Instanzen liefert die API „geheime Werte“. Nur issecretvalue prüft das gefahrlos:
-- schon der Vergleich eines geheimen Werts kann einen Fehler werfen.
local issecret = _G.issecretvalue
function ns.clean(v)
  if issecret and issecret(v) then return nil end
  return v
end

-- Im Kampf? (#71) Jede Kampfprüfung läuft hierüber. Ist der Wert geheim, gilt das als Kampf: Dann bleibt liegen,
-- was im Kampf nicht gelesen oder angefasst werden darf. Nur die API-Probe (Core/Probe.lua) fragt roh.
function ns.InCombat()
  if not InCombatLockdown then return false end
  local v = InCombatLockdown()
  if issecret and issecret(v) then return true end
  return v and true or false
end

-- In Kampf oder Instanz? Dann ruhen Teilen, Sichtung und Fundorte am Tooltip (#67, vorher je eine Kopie): geheime
-- Werte, und Addon-Nachrichten sind dort gesperrt. Ein geheimer Wert gilt wie beim Kampf als „drin“. Der Tooltip
-- prüft zusätzlich ns.Possessing (Core/Places.lua).
function ns.Quiet()
  if ns.InCombat() then return true end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    if ok and ((issecret and issecret(inside)) or inside) then return true end
  end
  return false
end

function ns.Print(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff9fd45fForever Hunter Pets|r: " .. tostring(msg)) end
end

-- Fehler je Stelle einmal melden – in der Beta soll eine geänderte API nicht das ganze Addon kippen
local reported = {}
function ns.ReportError(where, err)
  if reported[where] then return end
  reported[where] = true
  ns.Print("|cffff7359" .. (L["Error in %s:"]):format(where) .. "|r " .. tostring(err))
end

-- Jeder Fehler geht auch an den Verlauf des Teilens (ns.NoteError, #160), der ihn zählt – der Chat zeigt ihn nur einmal
local function failed(where, err)
  if ns.NoteError then pcall(ns.NoteError, where, err) end
  ns.ReportError(where, err)
end

function ns.SafeCall(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then failed(where, err) end
  return ok
end

-- Etwas später ausführen; ohne C_Timer sofort (#69: von Core/Known.lua hierher, alle Dateien nutzen es)
function ns.After(delay, fn)
  if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

-- Bei vollem Speicher (#61): die ersten n fremden Einträge einer Liste entfernen, die nach Eingang geordnet ist
-- (ForeverHunterPetsDB.obs, .sights). Eigene und unlesbare bleiben. Liefert die Zahl der entfernten.
function ns.DropOldestForeign(list, parse, n)
  local keep, dropped = {}, 0
  for _, s in ipairs(list) do
    local o = dropped < n and parse(s)
    if o and not o.own then dropped = dropped + 1 else keep[#keep + 1] = s end
  end
  for i = 1, math.max(#list, #keep) do list[i] = keep[i] end
  return dropped
end

local function applyDefaults(db, def)
  for k, v in pairs(def) do
    if type(v) == "table" then
      if type(db[k]) ~= "table" then db[k] = {} end
      applyDefaults(db[k], v)
    elseif db[k] == nil then
      db[k] = v
    end
  end
end

-- ---- Ereignisse ----
local ev = CreateFrame("Frame")
local handlers = {}
function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    -- ein Ereignis, das dieser Client nicht kennt, wirft beim Registrieren
    if not pcall(ev.RegisterEvent, ev, event) then return false end
  end
  table.insert(handlers[event], fn)
  return true
end
ev:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then failed(event, err) end
  end
end)

-- ---- Gespeicherte Daten ----
-- je Konto: Fensterposition, Knopf an der Minikarte (an/aus und sein Winkel am Ring in Grad),
-- ob die Filter der Ansicht „Fähigkeiten“ die Sitzung überdauern, ob Tier-Tooltips ergänzt werden (mit Leerzeile
-- davor, danach), ob Lehrtiere aus unsicheren oder unbelegten Quellen erscheinen und ob Beobachtungen
-- beim Zähmen mit anderen Spielern geteilt werden; den Lernstand von Hand ändern (manualEdit) ist standardmäßig aus;
-- Stufe und EP-Leiste am Pet-Rahmen (petFrame mit petFrameLevel und petFrameXP, #120)
local DEFAULTS = { ui = { minimap = true, minimapAngle = 215, keepFilters = true, tooltip = true, tooltipGapBefore = true, tooltipGapAfter = false,
  showUncertain = false, showUnproven = false, share = true, manualEdit = false, tooltipShowKnown = true,
  petFrame = true, petFrameLevel = true, petFrameXP = true } }
-- je Charakter: Lernstand { [Fähigkeit] = { Ränge } } und die zuletzt gewählten Filter
-- (show: abgewählte Häkchen = false; zone, fam: ID, "current" oder nichts für „Alle“)
local CHAR_DEFAULTS = { known = {}, filters = { show = {} } }

-- Protokoll einer Probe oder des Selbsttests speichern (ForeverHunterPetsDB.probe), mit Zeitstempel: Es soll
-- nach /reload aus der Datei lesbar sein, aber nicht ewig liegen bleiben (#68)
local PROBE_KEEP = 24 * 60 * 60
local PROBE_INST_KEEP = 14 * 24 * 60 * 60
function ns.SaveProbe(log)
  if not ns.db then return end
  ns.db.probe, ns.db.probeAt = log, time()
end

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ForeverHunterPetsDB = ForeverHunterPetsDB or {}
  ForeverHunterPetsCharDB = ForeverHunterPetsCharDB or {}
  applyDefaults(ForeverHunterPetsDB, DEFAULTS)
  applyDefaults(ForeverHunterPetsCharDB, CHAR_DEFAULTS)
  ns.db, ns.char = ForeverHunterPetsDB, ForeverHunterPetsCharDB
  -- Protokolle abgeschlossener Proben (Lehren, Vormarkieren) nicht weiter mitschleppen
  ns.db.teachProbe, ns.db.selectProbe, ns.db.selectMethod = nil, nil, nil
  -- Protokoll der letzten Probe bzw. des Selbsttests nur einen Tag aufheben (#68); ohne Zeitstempel ist es
  -- von vor diesem Stand und kommt auch weg
  if not (ns.db.probeAt and time() - ns.db.probeAt < PROBE_KEEP) then ns.db.probe, ns.db.probeAt = nil, nil end
  -- Läufe der Instanz-Probe (#223, Core/Probe.lua) 14 Tage aufheben: gemessen wird über mehrere Abende
  if type(ns.db.probeInst) == "table" then
    local keep = {}
    for _, run in ipairs(ns.db.probeInst) do
      if type(run) == "table" and type(run.at) == "number" and time() - run.at < PROBE_INST_KEEP then keep[#keep + 1] = run end
    end
    ns.db.probeInst = #keep > 0 and keep or nil
  elseif ns.db.probeInst ~= nil then
    ns.db.probeInst = nil
  end
  -- Schalter „Fundorte anderer Spieler“ gibt es nicht mehr (16.10.2026)
  ns.db.ui.showForeignCells = nil
end)

-- Beim Einloggen sagen, was geladen wurde und wie man das Fenster öffnet
ns.On("PLAYER_LOGIN", function()
  ns.Print("v" .. ns.version .. " · " .. ns.CountsText() .. " · " .. (L["Open with %s"]):format("|cffffd100/fhp|r"))
end)

-- ---- Slash-Befehl und Addon-Menü an der Minikarte ----
SLASH_FOREVERHUNTERPETS1 = "/fhp"
SlashCmdList.FOREVERHUNTERPETS = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "" then
    ns.SafeCall("window", ns.Toggle)
  elseif cmd == "api" then
    -- /fhp api instanz [neu] (#223): Instanz-Probe, „neu“ leert vorher die Liste der Läufe
    local sub, opt = (msg or ""):lower():match("^%s*%S+%s+(%S+)%s*(%S*)")
    if sub == "instanz" or sub == "instance" then
      ns.SafeCall("api", ns.ProbeInstance, opt == "neu" or opt == "new")
    else
      ns.SafeCall("api", ns.ProbeApi)
    end
  elseif cmd == "karte" or cmd == "map" then
    ns.SafeCall("map", ns.ProbeMap)
  elseif cmd == "zaehmen" or cmd == "zähmen" or cmd == "tame" then
    ns.SafeCall("tame", ns.ProbeTame)
  elseif cmd == "besitzer" or cmd == "owner" then
    ns.SafeCall("owner", ns.ProbeOwner)
  elseif cmd == "teilen" or cmd == "share" then
    if (msg or ""):lower():match("^%s*%S+%s+test") then
      ns.SafeCall("share", ns.ShareTest)
    else
      ns.SafeCall("share", ns.ShareStatus)
    end
  elseif cmd == "suchen" or cmd == "search" then
    ns.SafeCall("share", ns.ShareSearch)
  elseif cmd == "erhebung" or cmd == "survey" then
    ns.SafeCall("survey", ns.SurveyStatus)
  elseif cmd == "gebiet" or cmd == "area" then
    ns.SafeCall("area", ns.DiscoverStatus)
  elseif cmd == "start" then
    -- Startansicht zur Wahl des Modus (#42, für Spieler seit #63): Schließen ändert einen schon gewählten Modus nicht
    ns.SafeCall("mode", ns.ShowModeDialog)
  elseif cmd == "modus" or cmd == "mode" then
    ns.SafeCall("mode", ns.ModeCommand)   -- Modus wechseln (#179)
  elseif cmd == "tour" then
    ns.SafeCall("tour", ns.TourCommand)   -- Tour des Entdeckermodus noch einmal (#178)
  elseif cmd == "zonen" or cmd == "zones" then
    ns.SafeCall("zones", ns.ZoneReport)
  else
    ns.Print(L["Commands: /fhp (open or close), /fhp area (progress in this zone), /fhp search (greet other hunters), /fhp share (sharing status), /fhp mode (switch mode), /fhp start (choose the mode in the start view), /fhp tour (show the tour again)"])
  end
end

function ForeverHunterPets_OnCompartmentClick()
  ns.SafeCall("window", ns.Toggle)
end
