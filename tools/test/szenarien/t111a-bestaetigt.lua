-- #111 Schritt A: Die Wildtierausbildung zählt erst, wenn zwei aufeinanderfolgende Öffnungen derselben Familie genau
-- dieselbe Liste zeigen; das schützt vor einer Lesung, während sich das Fenster aufbaut (nachgestellt als falsche
-- erste Liste mit Fähigkeiten fremder Familien und 0 TP). Gelesen wird frühestens 1,5 s nach dem Öffnen, die
-- Auswahl des Knopfs kommt danach (2,1 s). Die drei Filter des Fensters („Verfügbar“, „Nicht verfügbar“, „Bereits
-- bekannt“) dürfen in jeder Kombination aus sein: Das Addon blendet zum Lesen kurz alle ein, stellt jeden zurück, und
-- nur eine Lesung mit allen Filtern zählt. Der Tierausbilder in der Stadt bleibt, wie er ist.

-- Wildtierausbildung im Mock: Zeilen { name, status, level, rankText, cost, id }; ausgeblendete fehlen in der Liste
local rows = {}
local filters = { available = true, unavailable = true, used = true }
local showOnToggle = false
local toggles = 0   -- wie oft das Addon einen Filter umgeschaltet hat
local function visible()
  local out = {}
  for _, r in ipairs(rows) do
    if filters[r.status] then out[#out + 1] = r end
  end
  return out
end
function GetTrainerServiceTypeFilter(kind) return filters[kind] end
function SetTrainerServiceTypeFilter(kind, on)
  filters[kind] = on and true or false
  toggles = toggles + 1
  if showOnToggle then FireEvent("TRAINER_SHOW") end   -- falls der Client beim Umschalten neu „öffnet“
end
function GetNumTrainerServices() return #visible() end
function GetTrainerServiceInfo(i)
  local r = visible()[i]
  if not r then return nil end
  return r.name, r.status, "icon", r.level, r.rankText
end
function GetTrainerServiceCost(i) local r = visible()[i]; return r and r.cost end
C_TooltipInfo = { GetTrainerService = function(i) local r = visible()[i]; return r and { id = r.id } end }
local npcThere, famId, famName = false, 1, "Wolf"
function UnitExists(u) if u == "npc" then return npcThere end return u == "pet" end
function UnitCreatureFamily() return famName, famId end

-- Verzögerungen der Timer mitschreiben
local delays = {}
C_Timer.After = function(s, fn) delays[#delays + 1] = s; TIMERS[#TIMERS + 1] = fn end
local function runAll() for _ = 1, 5 do RunTimers() end end

local function row(name, rank, id, status, cost, level)
  return { name = name, rank = rank, rankText = "Rang " .. rank, id = id, status = status, cost = cost, level = level }
end
-- Wolf (Familie 1): Beißen R1 gelernt, R2 verfügbar für 3 TP (Aufpreis), Knurren R1 gelernt, R2 nicht verfügbar
local function wolf()
  return { row("Beißen", 1, 17253, "used", 0, 1), row("Beißen", 2, 17255, "available", 3, 8),
    row("Knurren", 1, 2649, "used", 0, 1), row("Knurren", 2, 14916, "unavailable", 0, 10) }
end
-- eine falsche Lesung: Klaue (Wölfe lernen sie nicht) für 0 TP
local function wolfBuggy()
  local l = wolf()
  l[#l + 1] = row("Klaue", 1, 16827, "available", 0, 1)
  return l
end
-- nach dem Lernen von Beißen R2
local function wolfLearned()
  return { row("Beißen", 1, 17253, "used", 1, 1), row("Beißen", 2, 17255, "used", 0, 8),
    row("Knurren", 1, 2649, "used", 0, 1), row("Knurren", 2, 14916, "unavailable", 0, 10) }
end
local function cat()
  return { row("Klaue", 1, 16827, "used", 0, 1), row("Klaue", 2, 16828, "available", 3, 8) }
end

local function open(list, fam, name)
  famId, famName = fam or 1, name or "Wolf"
  rows = list
  delays = {}
  CLOCK = CLOCK + 3   -- ein neues Öffnen kommt nie im selben Augenblick wie das Zurückstellen der Filter
  FireEvent("TRAINER_SHOW")
  CLOCK = CLOCK + 3
  runAll()
end
local function update(list)
  rows = list or rows
  CLOCK = CLOCK + 3
  FireEvent("TRAINER_UPDATE")
end
local function survey() return NS.db.survey end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

Login({})

-- Lesen erst nach 1,5 s, Auswahl nach 2,1 s
rows = wolfBuggy()
delays = {}
FireEvent("TRAINER_SHOW")
local hasRead, hasSelect = false, false
for _, d in ipairs(delays) do
  if d == 1.5 then hasRead = true end
  if d == 2.1 then hasSelect = true end
end
ok(hasRead and hasSelect, "Lesen nach 1,5 s, Auswahl nach 2,1 s")
CLOCK = CLOCK + 1.0
FireEvent("TRAINER_UPDATE")
ok(survey() == nil or survey().lastRead == nil, "TRAINER_UPDATE vor 1,5 s liest nicht")
CLOCK = CLOCK + 2
runAll()
ok(survey() and survey().lastRead and survey().lastRead.n == 5, "nach 1,5 s gelesen")

-- 1. Öffnung (eben): falsch. Nichts gilt.
ok(survey().lists[1] == nil, "falsche erste Öffnung: keine Liste")
ok(survey().ranks[16827] == nil, "Klaue aus der falschen Liste nicht in den Rängen")
ok(survey().ranks[17255] == nil, "auch die übrigen Zeilen erst nach der Bestätigung")
PRINTED = {}
NS.SurveyStatus()
ok(printed("wartet auf zweites gleiches Öffnen"), "/fhp erhebung zeigt, dass die Familie wartet")

-- mehrere TRAINER_UPDATE in derselben Öffnung bestätigen nichts
update(wolfBuggy())
update(wolfBuggy())
ok(survey().lists[1] == nil, "gleiche Lesungen in einer Öffnung bestätigen nichts")

-- 2. Öffnung: richtig, weicht von der ersten ab; /fhp erhebung nennt den Unterschied
open(wolf())
ok(survey().lists[1] == nil, "zweite Öffnung weicht ab: noch keine Liste")
PRINTED = {}
NS.SurveyStatus()
ok(printed("Wolf: letzte zwei Öffnungen unterscheiden sich in 1 Zeilen, etwa Klaue 1: available/0 Stufe 1 → fehlt"),
  "/fhp erhebung nennt den Unterschied zur vorigen Öffnung")

-- 3. Öffnung: richtig, gleich wie die zweite: bestätigt
open(wolf())
local l = survey().lists[1]
ok(l and l.rows[17253] == "used/0" and l.rows[17255] == "available/3" and l.rows[2649] == "used/0", "dritte Öffnung gleich der zweiten: bestätigt")
ok(l and l.rows[16827] == nil, "ohne Klaue")
local r2 = survey().ranks[17255]
ok(r2 and r2.bw and r2.petLevel == 8, "bestätigt: Pet-Stufe und Wildtierausbildung in den Rängen")
ok(survey().ranks[16827] == nil, "Klaue bleibt draußen")
PRINTED = {}
NS.SurveyStatus()
ok(not printed("wartet auf zweites"), "/fhp erhebung: nichts wartet mehr")

-- Lernen im offenen Fenster: es zählt der Stand am Ende der Öffnung
open(wolf())
update(wolfLearned())
ok(survey().lists[1].rows[17255] == "available/3", "nach dem Lernen gilt die neue Liste noch nicht")
-- andere Familie dazwischen stört nicht
open(cat(), 2, "Katze")
ok(survey().lists[2] == nil, "Katze einmal geöffnet: keine Liste")
open(wolfLearned())
ok(survey().lists[1].rows[17255] == "used/0" and survey().lists[1].rows[17253] == "used/1",
  "Wolf nach dem Lernen: gleich dem Stand am Ende der vorigen Öffnung, trotz Katze dazwischen")
open(cat(), 2, "Katze")
ok(survey().lists[2] and survey().lists[2].rows[16828] == "available/3", "Katze beim zweiten gleichen Öffnen bestätigt")

-- ---- Filter des Fensters ----
-- „Bereits bekannt“ ausgeblendet (der Fall des Maintainers): kurz eingeblendet gelesen, danach wieder aus; das Lesen
-- bei TRAINER_UPDATE mit ausgeblendetem Filter zählt nicht. Beim zweiten Öffnen bestätigt, mit den gelernten Zeilen.
filters.used = false
toggles = 0
open(wolf(), 3, "Spinne")
ok(toggles == 2, "noch nicht bestätigt: „Bereits bekannt“ kurz ein- und wieder ausgeschaltet")
ok(filters.used == false and filters.available and filters.unavailable, "Filter nach dem Lesen wie vorher")
update()
update()
open(wolf(), 3, "Spinne")
local sp = survey().lists[3]
ok(sp and sp.rows[17253] == "used/0" and sp.rows[2649] == "used/0", "„Bereits bekannt“ aus: bestätigt, mit den gelernten Zeilen")
ok(filters.used == false, "„Bereits bekannt“ bleibt aus")
-- Variante C: in dieser Sitzung bestätigt, dann kein Umschalten mehr; das Fenster bleibt ruhig
toggles = 0
open(wolf(), 3, "Spinne")
ok(toggles == 0, "Spinne schon bestätigt: kein Umschalten mehr")
ok(survey().lists[3].rows[17253] == "used/0", "die bestätigte Liste bleibt, die gefilterte zählt nicht")
-- eine andere, noch nicht bestätigte Familie schaltet weiter um
toggles = 0
open(wolf(), 5, "Eber")
ok(toggles == 2, "noch nicht bestätigte Familie: weiter umschalten")
filters.used = true

-- jede Kombination: was der Spieler ausblendet, bleibt danach ausgeblendet, und die Lesung ist vollständig
local combos = {
  { available = false }, { unavailable = false }, { used = false },
  { available = false, unavailable = false }, { available = false, used = false }, { unavailable = false, used = false },
  { available = false, unavailable = false, used = false },
}
for i, c in ipairs(combos) do
  filters.available, filters.unavailable, filters.used = c.available ~= false, c.unavailable ~= false, c.used ~= false
  local before = { filters.available, filters.unavailable, filters.used }
  local fam = 100 + i
  open(wolf(), fam, "Familie" .. fam)
  update()
  open(wolf(), fam, "Familie" .. fam)
  local x = survey().lists[fam]
  local n = 0
  for _ in pairs(x and x.rows or {}) do n = n + 1 end
  ok(n == 4, ("Filter-Kombination %d: vollständig bestätigt (%d Zeilen)"):format(i, n))
  ok(filters.available == before[1] and filters.unavailable == before[2] and filters.used == before[3],
    ("Filter-Kombination %d: jeder Filter wie vorher"):format(i))
end
filters.available, filters.unavailable, filters.used = true, true, true

-- Eine Lesung mit ausgeblendetem Filter zählt nie, auch nicht zweimal gleich
filters.used = false
rows = wolf()
famId, famName = 200, "Ohne Filter"
CLOCK = CLOCK + 3
FireEvent("TRAINER_UPDATE")
CLOCK = CLOCK + 3
FireEvent("TRAINER_UPDATE")
ok(survey().lists[200] == nil, "gefilterte Lesungen zählen nicht")
filters.used = true

-- Löst das Umschalten der Filter beim Client ein TRAINER_SHOW aus, ist das keine neue Öffnung
showOnToggle = true
filters.used = false
local k0 = NS.trainerOpening
open(wolf(), 4, "Bär")
ok(NS.trainerOpening == k0 + 1, "Umschalten der Filter zählt nicht als Öffnung: " .. (NS.trainerOpening - k0))
open(wolf(), 4, "Bär")
ok(survey().lists[4] ~= nil, "und die Lesung wird beim zweiten Öffnen bestätigt")
showOnToggle = false
filters.used = true

-- Tierausbilder in der Stadt: wie bisher sofort, keine Liste
npcThere = true
open({ row("Knurren", 2, 14916, "available", 500, 10) })
npcThere = false
local k = survey().ranks[14916]
ok(k and k.npc and k.gold == 500 and k.hunterLevel == 10, "Tierausbilder: Rang, Preis und Jägerstufe sofort")
ok(survey().lists[1].rows[14916] == "unavailable/0", "Tierausbilder: die Liste der Wildtierausbildung bleibt")
