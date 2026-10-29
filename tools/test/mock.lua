-- Forever Hunter Pets · nachgebildete WoW-API für die Prüfung ohne Spiel (tools/test/run.mjs)
-- Nur, was die Dateien aus Core/, Locales/ und Data/ beim Laden und in den Szenarien brauchen. Zeit, Uhr und
-- Timer stellt das Szenario selbst: NOW (time), CLOCK (GetTime), RunTimers().
NS = {}

-- Lua 5.3 (fengari) kennt %x nur für ganze Zahlen; das Addon hasht mit Zahlen bis 2^32
local fmt = string.format
string.format = function(f, ...)
  if f == "%08x" then
    local h = ...
    local hi, lo = math.floor(h / 65536), h % 65536
    return fmt("%04x%04x", hi, lo)
  end
  return fmt(f, ...)
end

-- Frames: nur Skripte und Ereignisse, alle anderen Methoden tun nichts
local frames = {}
local frameMT = { __index = function(t, k)
  return function(self, ...)
    if k == "SetScript" then local s, fn = ...; self.scripts[s] = fn end
    if k == "RegisterEvent" then local e = ...; self.events[e] = true end
  end end }
function CreateFrame() local f = setmetatable({ scripts = {}, events = {} }, frameMT); frames[#frames + 1] = f; return f end
function FireEvent(e, ...)
  for _, f in ipairs(frames) do
    if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end
  end
end

NOW = 1792500000
function time() return NOW end
CLOCK = 1000
function GetTime() return CLOCK end
TIMERS = {}
C_Timer = { After = function(s, fn) TIMERS[#TIMERS + 1] = fn end, NewTicker = function() return { Cancel = function() end } end }
function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do pcall(fn) end end

function GetLocale() return "deDE" end
function UnitFullName() return "Test", "Realm" end
function GetNormalizedRealmName() return "Realm" end
function InCombatLockdown() return false end
function IsInInstance() return false end
function strsplit(sep, s)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return table.unpack(out)
end
SlashCmdList = {}
PRINTED = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) PRINTED[#PRINTED + 1] = m end }
C_Spell = { GetSpellName = function(id) return "Zauber " .. id end, GetSpellSubtext = function() return nil end }
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return true end }

-- Fehler, die das Addon über ns.SafeCall meldet (run.mjs leitet ns.ReportError hierher)
ERRORS = {}

-- Prüfung: zählt für die Zusammenfassung, bricht das Szenario beim ersten Fehler ab
CHECKS = 0
function ok(cond, msg)
  if not cond then error("FEHLER: " .. msg, 2) end
  CHECKS = CHECKS + 1
  print("  ok  " .. msg)
end

-- Einloggen mit diesem Speicher (ForeverHunterPetsDB)
function Login(db)
  ForeverHunterPetsDB = db or {}
  FireEvent("ADDON_LOADED", "Forever-Hunter-Pets")
  FireEvent("PLAYER_LOGIN")
end
