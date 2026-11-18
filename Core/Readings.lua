-- Forever Hunter Pets · Lesungen der Wildtierausbildung teilen (#111). Fremde Ränge (#103) kommen ohne Pet-Stufe und
-- TP herein; die zeigt nur die Wildtierausbildung. Aus jeder bestätigten eigenen Lesung (Core/Survey.lua: zwei
-- Öffnungen nacheinander mit derselben Liste) entsteht je Fähigkeit ein Stück: alle Ränge einer Fähigkeit aus dieser
-- Lesung, mit Status, angezeigten TP und Pet-Stufe. Die TP-Rechnung braucht nur Zeilen derselben Fähigkeit aus
-- derselben Lesung (#210), deshalb genügt ein Stück je Fähigkeit.
--
-- Ein Stück wird gesendet und angenommen nur, wenn (ns.CheckReading, für Sender und Empfänger dieselbe Prüfung):
--   - jeder Rang darin ein lernbarer Rang der Daten ist (auch fremde Ränge aus Zähmungen; keine Jägerzauber, kein Tempo),
--   - alle Ränge zu einer Fähigkeit gehören, die die Daten dieser Familie zuordnen oder die jede Familie lernt
--     (das erste Symptom des fehlerhaften Fensters: Fähigkeiten fremder Familien),
--   - nichts den bekannten TP und Pet-Stufen widerspricht (das zweite: 0 TP bei einem Rang, der etwas kostet).
-- Gesendet wird ein eigenes Stück nur, wenn es eine Lücke füllt (ein Rang ohne TP oder Pet-Stufe in den Daten).
-- Die Werte gelten erst in den Stammdaten, nach der Melder-Regel (tools/build-data.mjs); im Spiel ändert ein fremdes
-- Stück nichts.
--
-- Ablage ForeverHunterPetsDB.readings: Zeichenketten „familie;zeilen;zeit;melder“, zeilen = „id:s:tp:stufe,…“ mit
-- s = u (gelernt), a (verfügbar), n (nicht verfügbar). Je Melder, Familie und Fähigkeit nur das neueste Stück,
-- höchstens MAX_STORED; ist es voll, fallen die ältesten fremden weg. Nachricht: „L1;“ davor (Core/Comm.lua).
local _, ns = ...
local D = ns.Data

local MAX_RANKS, MAX_STORED, MAX_TP, MAX_LEVEL = 12, 500, 100, 63
local MIN_TIME = 1788220800   -- 01.09.2026, wie in Core/Comm.lua
local CODE = { used = "u", available = "a", unavailable = "n" }

-- Rang einer Zauber-ID in den Daten (nur Lernbares, also ohne Angriffstempo), wie in Core/Known.lua
local byId
ns.OnAbilitiesChanged(function() byId = nil end)
local function rankOf(id)
  if not byId then
    byId = {}
    for _, a in ipairs(D.abilities) do
      if ns.Learnable(a) then
        for _, r in ipairs(a.ranks) do byId[r.id] = { a = a, r = r } end
      end
    end
  end
  return byId[id]
end

local function familyMay(a, fam)
  if ns.AppliesToAll(a) then return true end
  for _, f in ipairs(a.families or {}) do
    if f == fam then return true end
  end
  return false
end

local function abilityKey(a) return tostring(a.en or a.de or (a.ranks[1] and a.ranks[1].id)) end

-- Prüft ein Stück einer Familie: rows = { { id, s, tp, lvl }, … }. Liefert die Fähigkeit, sonst nil und den Grund.
-- Aktueller Rang ist der höchste gelernte; darunter zeigt die Liste den vollen Preis, darüber den Aufpreis.
function ns.CheckReading(fam, rows)
  if #rows == 0 or #rows > MAX_RANKS then return nil, "Größe" end
  local a
  for _, x in ipairs(rows) do
    local hit = rankOf(x.id)
    if not hit then return nil, "unbekannter Rang" end
    if a and hit.a ~= a then return nil, "mehrere Fähigkeiten" end
    a = hit.a
  end
  if not familyMay(a, fam) then return nil, "fremde Familie" end
  local cur
  for _, x in ipairs(rows) do
    local r = rankOf(x.id).r
    if x.s == "u" and (not cur or r.rank > cur.rank) then cur = r end
  end
  for _, x in ipairs(rows) do
    local r = rankOf(x.id).r
    if r.level ~= nil and x.lvl ~= r.level then return nil, "widerspricht den Daten" end
    if r.tp ~= nil then
      local full
      if not cur or r.rank < cur.rank then full = x.tp
      elseif r.rank > cur.rank and cur.tp ~= nil then full = x.tp + cur.tp end
      if full ~= nil and full ~= r.tp then return nil, "widerspricht den Daten" end
    end
  end
  return a
end

-- Füllt das Stück eine Lücke der Daten?
local function fillsGap(rows)
  for _, x in ipairs(rows) do
    local r = rankOf(x.id).r
    if r.tp == nil or r.level == nil then return true end
  end
  return false
end

local function encode(rows)
  local parts = {}
  for _, x in ipairs(rows) do parts[#parts + 1] = ("%d:%s:%d:%d"):format(x.id, x.s, x.tp, x.lvl) end
  return table.concat(parts, ",")
end

-- „familie;zeilen;zeit;melder[;…]“ lesen; Felder am Ende, die diese Version nicht kennt, werden übergangen (#12)
function ns.ParseReading(s)
  if type(s) ~= "string" then return nil end
  local fam, list, t, rep, rest = s:match("^(%d+);([%d:%a,]+);(%d+);(%x+)(.*)$")
  fam, t = tonumber(fam), tonumber(t)
  if not (fam and list and t and rep) or (rest ~= "" and rest:sub(1, 1) ~= ";") then return nil end
  local rows = {}
  for item in list:gmatch("[^,]+") do
    local id, code, tp, lvl = item:match("^(%d+):([uan]):(%d+):(%d+)$")
    id, tp, lvl = tonumber(id), tonumber(tp), tonumber(lvl)
    if not (id and code and tp and lvl) then return nil end
    rows[#rows + 1] = { id = id, s = code, tp = tp, lvl = lvl }
    if #rows > MAX_RANKS then return nil end
  end
  local mine = ns.db and ns.db.myReps
  return { fam = fam, rows = rows, time = t, rep = rep, own = (mine and mine[rep]) and true or false }
end

-- Form: Familie, Zauber, Status, TP, Stufe, Zeit, Melder. Liefert das Stück oder nil und den Grund.
local function plausible(s)
  local o = ns.ParseReading(s)
  if not o then return nil, "unlesbar" end
  if #o.rep ~= 8 then return nil, "Melder" end
  if o.fam < 1 or o.fam > 1000 or (ns.DEMON_FAMILY and ns.DEMON_FAMILY[o.fam]) then return nil, "Familie" end
  for _, x in ipairs(o.rows) do
    if x.id < 1 or x.id > 9999999 or x.tp > MAX_TP or x.lvl < 1 or x.lvl > MAX_LEVEL then return nil, "Werte" end
  end
  local now = time and time() or 0
  if o.time < MIN_TIME or (now > 0 and o.time > now + 86400) then return nil, "Zeit unplausibel" end
  return o
end

local function store()
  if not ns.db then return nil end
  if type(ns.db.readings) ~= "table" then ns.db.readings = {} end
  return ns.db.readings
end

-- Ablegen: je Melder, Familie und Fähigkeit nur das neueste. Liefert true (neu), false (schon bekannt oder älter).
local function keep(o, a, s)
  local list = store()
  if not list then return false end
  local key = abilityKey(a)
  for i = #list, 1, -1 do
    local old = ns.ParseReading(list[i])
    local hit = old and old.rep == o.rep and old.fam == o.fam and old.rows[1] and rankOf(old.rows[1].id)
    if hit and abilityKey(hit.a) == key then
      if list[i] == s or old.time >= o.time then return false end
      table.remove(list, i)
    end
  end
  if #list >= MAX_STORED then
    for i = 1, #list do
      local old = ns.ParseReading(list[i])
      if not (old and old.own) then table.remove(list, i); break end
    end
    if #list >= MAX_STORED then return false end
  end
  list[#list + 1] = s
  return true
end

-- Empfang (Core/Comm.lua): Liefert neu gespeichert?, sonst den Grund, und das Kürzel des Melders, sobald gültig.
function ns.ReceiveReading(s)
  local o, why = plausible(s)
  if not o then return false, why end
  local myRep = ns.MyRep and ns.MyRep()
  if o.own or o.rep == myRep then return false, "eigene" end
  local a, why2 = ns.CheckReading(o.fam, o.rows)
  if not a then return false, why2, o.rep end
  if not keep(o, a, s) then return false, "schon bekannt", o.rep end
  return true, nil, o.rep
end

-- Eine bestätigte eigene Lesung (Core/Survey.lua): je Fähigkeit ein Stück, geprüft, nur mit Lücke; ablegen und
-- einmal je Sitzung über Gilde und Gruppe senden
local sentThisSession = {}
function ns.ReadingConfirmed(fam, reading)
  local rep = ns.MyRep and ns.MyRep()
  if not (rep and type(reading) == "table" and type(reading.rows) == "table") then return end
  local groups = {}
  for id, r in pairs(reading.rows) do
    local hit = rankOf(id)
    local code = CODE[r.status]
    if hit and code and type(r.cost) == "number" and type(r.level) == "number" then
      local key = abilityKey(hit.a)
      groups[key] = groups[key] or {}
      local g = groups[key]
      g[#g + 1] = { id = id, s = code, tp = r.cost, lvl = r.level, rank = hit.r.rank }
    end
  end
  for _, rows in pairs(groups) do
    table.sort(rows, function(x, y) return x.rank < y.rank end)
    local a = ns.CheckReading(fam, rows)
    if a and fillsGap(rows) then
      local s = ("%d;%s;%d;%s"):format(fam, encode(rows), reading.at or 0, rep)
      local o = ns.ParseReading(s)
      if o and keep(o, a, s) and not sentThisSession[s] then
        sentThisSession[s] = true
        if ns.ShareReading then ns.ShareReading(s) end
      end
    end
  end
end

-- Für die Antwort auf einen Gruß: bis zu n Stücke, eigene zuerst, dann die neuesten fremden; nichts vom Grüßenden
function ns.ReadingsToShare(n, theirs)
  local own, other = {}, {}
  for _, s in ipairs((ns.db and ns.db.readings) or {}) do
    local o = ns.ParseReading(s)
    if o and o.own then own[#own + 1] = s elseif o and o.rep ~= theirs then other[#other + 1] = s end
  end
  local out = {}
  for _, list in ipairs({ own, other }) do
    for i = #list, 1, -1 do
      if #out >= n then return out end
      out[#out + 1] = list[i]
    end
  end
  return out
end

-- Für /fhp teilen und die Herkunft (pruneVia): Zahl der fremden Stücke und ihre Melder
function ns.ForeignReadings()
  local n, reps = 0, {}
  for _, s in ipairs((ns.db and ns.db.readings) or {}) do
    local o = ns.ParseReading(s)
    if o and not o.own then n = n + 1; reps[o.rep] = true end
  end
  return n, reps
end
