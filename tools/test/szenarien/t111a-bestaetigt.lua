-- #111 Schritt A: Die Wildtierausbildung zählt erst, wenn zwei aufeinanderfolgende Öffnungen derselben Familie genau
-- dieselbe Liste zeigen. Das Fenster zeigt beim ersten Öffnen mitunter eine falsche Liste (Fähigkeiten fremder
-- Familien, 0 TP), die bis zum erneuten Öffnen stehen bleibt. Gelesen wird frühestens 1,0 s nach dem Öffnen, die
-- Auswahl des Knopfs kommt danach (1,6 s). Der Tierausbilder in der Stadt bleibt, wie er ist.

-- Wildtierausbildung im Mock: Zeilen { name, status, level, rankText, cost, id }
local rows = {}
function GetNumTrainerServices() return #rows end
function GetTrainerServiceInfo(i)
  local r = rows[i]
  if not r then return nil end
  return r.name, r.status, "icon", r.level, r.rankText
end
function GetTrainerServiceCost(i) return rows[i] and rows[i].cost end
function GetTrainerServiceTypeFilter() return true end
C_TooltipInfo = { GetTrainerService = function(i) return rows[i] and { id = rows[i].id } end }
local npcThere, famId, famName = false, 1, "Wolf"
function UnitExists(u) if u == "npc" then return npcThere end return u == "pet" end
function UnitCreatureFamily() return famName, famId end

-- Verzögerungen der Timer mitschreiben
local delays = {}
C_Timer.After = function(s, fn) delays[#delays + 1] = s; TIMERS[#TIMERS + 1] = fn end

local function row(name, rank, id, status, cost, level)
  return { name = name, rank = rank, rankText = "Rang " .. rank, id = id, status = status, cost = cost, level = level }
end
-- Wolf (Familie 1): Beißen R1 gelernt, R2 verfügbar für 3 TP (Aufpreis), Knurren R1 gelernt
local function wolf()
  return { row("Beißen", 1, 17253, "used", 0, 1), row("Beißen", 2, 17255, "available", 3, 8),
    row("Knurren", 1, 2649, "used", 0, 1) }
end
-- dieselbe Liste mit dem Fehler des Fensters: Klaue (Wölfe lernen sie nicht) für 0 TP
local function wolfBuggy()
  local l = wolf()
  l[#l + 1] = row("Klaue", 1, 16827, "available", 0, 1)
  return l
end
-- nach dem Lernen von Beißen R2
local function wolfLearned()
  return { row("Beißen", 1, 17253, "used", 1, 1), row("Beißen", 2, 17255, "used", 0, 8),
    row("Knurren", 1, 2649, "used", 0, 1) }
end
local function cat()
  return { row("Klaue", 1, 16827, "used", 0, 1), row("Klaue", 2, 16828, "available", 3, 8) }
end

local function open(list, fam, name)
  famId, famName = fam or 1, name or "Wolf"
  rows = list
  delays = {}
  FireEvent("TRAINER_SHOW")
  CLOCK = CLOCK + 2
  RunTimers()
end
local function update(list)
  rows = list
  CLOCK = CLOCK + 2
  FireEvent("TRAINER_UPDATE")
end
local function survey() return NS.db.survey end
local function printed(pattern)
  for _, p in ipairs(PRINTED) do if p:find(pattern) then return p end end
end

Login({})

-- Lesen erst nach 1,0 s, Auswahl danach
rows = wolfBuggy()
delays = {}
FireEvent("TRAINER_SHOW")
local hasRead, hasSelect = false, false
for _, d in ipairs(delays) do
  if d == 1.0 then hasRead = true end
  if d == 1.6 then hasSelect = true end
end
ok(hasRead and hasSelect, "Lesen nach 1,0 s, Auswahl nach 1,6 s")
CLOCK = CLOCK + 0.5
FireEvent("TRAINER_UPDATE")
ok(survey() == nil or survey().lastRead == nil, "TRAINER_UPDATE vor 1,0 s liest nicht")
CLOCK = CLOCK + 2
RunTimers()
ok(survey() and survey().lastRead and survey().lastRead.n == 4, "nach 1,0 s gelesen")

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

-- 2. Öffnung: richtig, weicht von der ersten ab
open(wolf())
ok(survey().lists[1] == nil, "zweite Öffnung weicht ab: noch keine Liste")

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

-- Tierausbilder in der Stadt: wie bisher sofort, keine Liste
npcThere = true
open({ row("Knurren", 2, 14916, "available", 500, 10) })
npcThere = false
local k = survey().ranks[14916]
ok(k and k.npc and k.gold == 500 and k.hunterLevel == 10, "Tierausbilder: Rang, Preis und Jägerstufe sofort")
ok(survey().lists[1].rows[14916] == nil and not (k and k.bw), "Tierausbilder: keine Liste, keine Wildtierausbildung")
