-- Forever Hunter Pets · Start: Sprache, gespeicherte Daten, Ereignisse, Slash-Befehl
local ADDON, ns = ...
ns.ADDON = ADDON

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(ADDON, "Version")) or "?"

-- ---- Sprache: der Schlüssel ist der englische Text, Locales/*.lua übersetzen ----
local strings = (ns.Locales or {})[GetLocale and GetLocale() or "enUS"] or {}
ns.L = setmetatable({}, { __index = function(_, k) return strings[k] or k end })
local L = ns.L

-- ---- Helfer ----
-- In Kampf und Instanzen liefert die API „geheime Werte“. Nur issecretvalue prüft das gefahrlos:
-- schon der Vergleich eines geheimen Werts kann einen Fehler werfen.
local issecret = _G.issecretvalue
function ns.clean(v)
  if issecret and issecret(v) then return nil end
  return v
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

function ns.SafeCall(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then ns.ReportError(where, err) end
  return ok
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
    if not ok then ns.ReportError(event, err) end
  end
end)

-- ---- Gespeicherte Daten ----
-- je Konto: Fensterposition, Knopf an der Minikarte (an/aus und sein Winkel am Ring in Grad),
-- ob die Filter der Ansicht „Fähigkeiten“ die Sitzung überdauern, ob Tier-Tooltips ergänzt werden (mit Leerzeile
-- davor, danach), ob Lehrtiere aus unsicheren oder unbelegten Quellen erscheinen und ob Beobachtungen
-- beim Zähmen mit anderen Spielern geteilt werden; den Lernstand von Hand ändern (manualEdit) ist standardmäßig aus
local DEFAULTS = { ui = { minimap = true, minimapAngle = 215, keepFilters = true, tooltip = true, tooltipGapBefore = true, tooltipGapAfter = false,
  showUncertain = false, showUnproven = false, share = true, manualEdit = false, tooltipShowKnown = true } }
-- je Charakter: Lernstand { [Fähigkeit] = { Ränge } } und die zuletzt gewählten Filter
-- (show: abgewählte Häkchen = false; zone, fam: ID, "current" oder nichts für „Alle“)
local CHAR_DEFAULTS = { known = {}, filters = { show = {} } }

ns.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ForeverHunterPetsDB = ForeverHunterPetsDB or {}
  ForeverHunterPetsCharDB = ForeverHunterPetsCharDB or {}
  applyDefaults(ForeverHunterPetsDB, DEFAULTS)
  applyDefaults(ForeverHunterPetsCharDB, CHAR_DEFAULTS)
  ns.db, ns.char = ForeverHunterPetsDB, ForeverHunterPetsCharDB
  -- Protokolle abgeschlossener Proben (Lehren, Vormarkieren) nicht weiter mitschleppen
  ns.db.teachProbe, ns.db.selectProbe, ns.db.selectMethod = nil, nil, nil
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
    ns.SafeCall("api", ns.ProbeApi)
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
  elseif cmd == "erhebung" or cmd == "survey" then
    ns.SafeCall("survey", ns.SurveyStatus)
  elseif cmd == "gebiet" or cmd == "area" then
    ns.SafeCall("area", ns.DiscoverStatus)
  elseif cmd == "start" then
    -- Startdialog zum Testen (Entwicklerwerkzeug, #42): Schließen ändert einen schon gewählten Modus nicht
    ns.SafeCall("mode", ns.ShowModeDialog)
  elseif cmd == "zonen" or cmd == "zones" then
    ns.SafeCall("zones", ns.ZoneReport)
  else
    ns.Print(L["Commands: /fhp (open or close), /fhp zones (zones without a map), /fhp api (API probe), /fhp map (map probe), /fhp tame (taming probe), /fhp owner (owner probe), /fhp share (sharing status), /fhp survey (survey status), /fhp area (progress in this zone)"])
  end
end

function ForeverHunterPets_OnCompartmentClick()
  ns.SafeCall("window", ns.Toggle)
end
