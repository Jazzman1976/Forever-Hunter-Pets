-- Forever Hunter Pets · Entdecken: was man selbst gefunden hat, je Tier und Zone (Meilenstein M2, Inkrement E1).
-- Konzept: docs/konzept/konzept.md (5 Die zwei Modi, 6 Status eines Tiers)
--
-- Status eines Tiers je NPC-ID und je Zone – jede Zone ist ein eigenes Jagdrevier:
--   „unknown“  unentdeckt
--   „track“    Fährte aufgenommen: in dieser Zone gesichtet (Ziel, Maus, Plakette)
--   „found“    gefunden: in dieser Zone aus etwa 10 m gesehen (eigene Fundort-Zelle)
--   „known“    bekannt: in dieser Zone gefunden und alle Fähigkeiten bekannt (eigene Zähmung)
-- Was ein Tier lehrt, ist Wissen über die NPC-ID und gilt in allen Zonen. Ein Tier gehört nur zu Zonen, in
-- denen es einen echten Fundort hat (Daten oder Zelle) – eine Sichtung über eine Zonengrenze hinweg zählt dort
-- nicht. Gezählt wird bei Bedarf, nichts im Hintergrund.
--
-- Funde zählen je Charakter, auf Wunsch die des ganzen Kontos (#43); gesammelt und geteilt wird weiter
-- kontoweit. Neu gespeichert wird nur seenIn: je eigener Sichtung und Zähmung die Karte, auf der der Spieler
-- stand, ForeverHunterPetsDB.seenIn[npc] = "1431,1429" – lokal, nicht geteilt – und dasselbe je Charakter in
-- ForeverHunterPetsCharDB.seenIn.
local _, ns = ...
local D = ns.Data

-- ---- Wessen Funde zählen (#43) ----
-- Im Entdeckermodus die des Charakters (ForeverHunterPetsCharDB: seenIn, loc), mit der Unteroption „Funde meiner
-- anderen Charaktere zeigen“ (ns.char.shareFinds) die des Kontos; im Komplettmodus immer die des Kontos. Alle
-- Lesestellen für Fährten, eigene Zellen (Core/Places.lua) und eigene Zähmungen gehen über diese Weiche.
local function accountFinds()
  return not ns.Discovering() or (ns.char ~= nil and ns.char.shareFinds == true)
end
function ns.Finds()
  if accountFinds() then return ns.db end
  return ns.char
end

-- Zählt die Zähmung als eigener Fund? Je Charakter nur die mit dessen Kürzel (Kürzel leer: noch nicht
-- zugeordnet, Core/Comm.lua ordnet sie beim Einloggen zu).
function ns.OwnTame(o)
  if not o.own then return false end
  return accountFinds() or o.rep == "" or o.rep == ns.MyRep()
end

-- ---- seenIn ----
local function noteIn(store, npc, m)
  store.seenIn = store.seenIn or {}
  local list = store.seenIn[npc]
  if not list then
    store.seenIn[npc] = m
    return true
  end
  for x in list:gmatch("%d+") do
    if x == m then return false end
  end
  store.seenIn[npc] = list .. "," .. m
  return true
end

-- Für das Konto und für den Charakter; true, wenn die Zone für das Konto neu dazukam
function ns.NoteSeenIn(npc, map)
  if not (ns.db and npc and map) then return false end
  local m = tostring(map)
  if ns.char then noteIn(ns.char, npc, m) end
  return noteIn(ns.db, npc, m)
end

local function seenIn(npc, map)
  local finds = ns.Finds()
  local list = finds and finds.seenIn and finds.seenIn[npc]
  if not list then return false end
  local m = tostring(map)
  for x in list:gmatch("%d+") do
    if x == m then return true end
  end
  return false
end

-- Selbst gezähmt in dieser Zone: Die Zähmung notiert die Zone (seenIn), und „Wildtier zähmen“ reicht nur etwa
-- 30 m – wer zähmt, war dem Tier nah. Das gilt als Fundort, auch wenn eine ältere Zähmung keine Zelle speicherte
-- (vor dem 16.10.2026 nur aus 10 m; Junger Fleischreißer).
local function tamedIn(npc, map)
  if not seenIn(npc, map) then return false end
  for _, o in ipairs(ns.ObservationsOf(npc)) do
    if ns.OwnTame(o) then return true end
  end
  return false
end

-- Zonen, in denen man das Tier selbst gezähmt hat { [map] = true }
function ns.TamedZones(npc)
  local out = {}
  local finds = ns.Finds()
  local list = finds and finds.seenIn and finds.seenIn[npc]
  for x in (list or ""):gmatch("%d+") do
    local map = tonumber(x)
    if tamedIn(npc, map) then out[map] = true end
  end
  return out
end

-- ---- Wer lebt wo ----
-- Lebt das Tier in dieser Zone? Nur mit echtem Fundort: in den Daten, als Zelle (eigene oder fremde) oder durch
-- eine eigene Zähmung dort
function ns.LivesIn(npc, map)
  return (ns.ZoneCounts(npc, true)[map] or 0) > 0 or tamedIn(npc, map)
end

-- Hat das Tier nirgends einen Fundort? Dann zählt seine Fährte in den Zonen, in denen man es gesehen hat
-- (Nutzer, 16.10.2026: sonst blieben Tiere, die man nur von weitem sah, unsichtbar). Sobald es irgendwo einen
-- Fundort hat, gilt wieder nur „wo es lebt“ – eine Fährte über eine Zonengrenze hinweg verschwindet dann.
local function nowhere(npc)
  return next(ns.ZoneCounts(npc, true)) == nil and next(ns.TamedZones(npc)) == nil
end
local function trackOnly(npc, map)
  return seenIn(npc, map) and nowhere(npc)
end

-- Alle Tiere einer Zone: aus den Daten und aus Zellen. { [npc] = true }
function ns.BeastsIn(map)
  local out = {}
  for npc, zones in pairs(D.coords) do
    if zones[map] then out[npc] = true end
  end
  for _, foreign in ipairs({ "loc", "locIn" }) do
    for npc, maps in pairs((ns.db and ns.db[foreign]) or {}) do
      if maps[map] and maps[map] ~= "" then out[npc] = true end
    end
  end
  for npc in pairs((ns.Finds() or {}).seenIn or {}) do
    if not out[npc] and (tamedIn(npc, map) or trackOnly(npc, map)) then out[npc] = true end
  end
  return out
end

-- Zonen, in denen es überhaupt Tiere gibt (Daten und Zellen), sortiert nach Namen
function ns.DiscoverZones()
  local set = {}
  for _, zones in pairs(D.coords) do
    for map in pairs(zones) do set[map] = true end
  end
  for _, key in ipairs({ "loc", "locIn" }) do
    for _, maps in pairs((ns.db and ns.db[key]) or {}) do
      for map, cells in pairs(maps) do if cells ~= "" then set[map] = true end end
    end
  end
  for npc, list in pairs((ns.Finds() or {}).seenIn or {}) do
    for map in pairs(ns.TamedZones(npc)) do set[map] = true end
    if nowhere(npc) then
      for x in list:gmatch("%d+") do set[tonumber(x)] = true end
    end
  end
  local out = {}
  for map in pairs(set) do out[#out + 1] = map end
  table.sort(out, function(x, y) return ns.ZoneName(x) < ns.ZoneName(y) end)
  return out
end

-- ---- Eigene Funde ----
local function ownCells(npc, map)
  local finds = ns.Finds()
  local cells = finds and finds.loc and finds.loc[npc] and finds.loc[npc][map]
  return cells and #cells / 2 or 0
end

local function ownTamed(npc)
  for _, o in ipairs(ns.ObservationsOf(npc)) do
    if ns.OwnTame(o) then return true end
  end
  return false
end

-- Status in einer Zone (siehe oben)
function ns.BeastStatus(npc, map)
  if not ns.LivesIn(npc, map) then
    return trackOnly(npc, map) and "track" or "unknown"
  end
  if ownCells(npc, map) > 0 or tamedIn(npc, map) then
    return ownTamed(npc) and "known" or "found"
  end
  if seenIn(npc, map) then return "track" end
  return "unknown"
end

-- ---- Name einer Fährte ----
-- Von weitem (über etwa 28 m) speichert die Sichtung nichts, die Fährte aber schon. Damit so ein Tier nicht
-- „Unbekanntes Tier (#833)“ heißt, merkt sich das Addon Name und Familie dazu: lokal, nicht geteilt,
-- ForeverHunterPetsDB.trackNames[npc] = „Familie;Name“ in Client-Sprache. Die eigene Sichtung geht vor; sobald
-- es eine gibt, fällt der Eintrag weg. Eine fremde verdrängt ihn nicht (#47).
function ns.NoteTrackName(npc, fam, name)
  if not (ns.db and npc) then return end
  local names = ns.db.trackNames
  if ns.SeenName and select(2, ns.SeenName(npc)) then
    if names then names[npc] = nil end
    return
  end
  if type(name) ~= "string" or name == "" or name:find("[;|]") or #name > 60 then return end
  ns.db.trackNames = names or {}
  ns.db.trackNames[npc] = (tonumber(fam) or 0) .. ";" .. name
end

-- Name und Familie aus trackNames, oder nil
function ns.TrackName(npc)
  local v = ns.db and ns.db.trackNames and ns.db.trackNames[npc]
  if type(v) ~= "string" then return nil end
  local fam, name = v:match("^(%d+);(.+)$")
  fam = tonumber(fam)
  return name, fam ~= 0 and fam or nil
end

-- ---- Fährte aufnehmen (E7) ----
-- Aufgerufen von der Sichtung, vom Tooltip und von der Witterung, je nachdem, wer zuerst dran ist. Eine eigene
-- Meldung „eben aufgenommen“ gibt es nicht mehr: Der Status heißt selbst „Fährte aufgenommen“ (17.10.2026).
function ns.NoteTrack(npc, map)
  ns.NoteSeenIn(npc, map)
end

-- ---- Texte, überall gleich (Reiter „Gebiet“, Tier-Tooltip, Witterung) ----
-- Status-Tags des Entdeckermodus (Nutzer, 17.10.2026): „Fährte aufgenommen“, „Tier gefunden“, „Fähigkeiten
-- bekannt“ – Jäger-Sprache, ohne Icon. Im Komplettmodus gibt es keinen Status: Dort zählt nicht, was der Spieler
-- selbst gesehen hat, sondern was überhaupt bekannt ist (docs/konzept/entscheidungen.md).
local STATUS_WORD = { track = "tracked", found = "beast found", known = "abilities known" }
function ns.StatusWord(st)
  return STATUS_WORD[st] and ns.L[STATUS_WORD[st]] or nil
end
-- Tag des Tiers in dieser Zone; nil im Komplettmodus, bei unentdeckt oder ohne Fundort in der Zone
function ns.StatusText(npc, map)
  if not ns.Discovering() then return nil end
  return ns.StatusWord(ns.BeastStatus(npc, map))
end

-- „? unklar“, „lehrt nichts“ oder „lehrt“ mit den Icons der Fähigkeiten, ohne Rang (Wunsch des Nutzers: so
-- passt die Zeile auch bei mehreren Fähigkeiten; Namen und Ränge stehen im Tooltip der Zeile im Reiter)
function ns.TeachText(npc)
  local L = ns.L
  local info = ns.TeachInfo(npc, ns.Discovering())
  if not info then return L["? unclear"] end
  if #info == 0 then return L["teaches nothing"] end
  local parts = {}
  for _, e in ipairs(info) do
    parts[#parts + 1] = ("|T%s:14:14|t"):format(ns.AbilityIcon(e.a))
  end
  return (L["teaches %s"]):format(table.concat(parts, " "))
end

-- ---- Was ein Tier lehrt ----
-- Rang zu einer Zauber-ID für alles, was man von Tieren lernt, auch Angriffstempo
local bySpell
ns.OnAbilitiesChanged(function() bySpell = nil end)
local function spellIndex()
  if bySpell then return bySpell end
  bySpell = {}
  for _, a in ipairs(D.abilities) do
    if a.source == "tame" then
      for _, r in ipairs(a.ranks) do
        if r.id > 0 then bySpell[r.id] = { a = a, r = r } end
      end
    end
  end
  return bySpell
end

local function addSeen(out, have, a, r)
  if not have[r] then
    have[r] = true
    out[#out + 1] = { a = a, r = r }
  end
end

-- Was eine Zähmung zeigte: Ränge aus dem Zauberbuch, dazu ein Tempo ohne bekannten Zauber
local function fromObservation(o, out, have)
  local idx = spellIndex()
  for id in pairs(o.spells) do
    local x = idx[id]
    if x then addSeen(out, have, x.a, x.r) end
  end
  if o.speed then
    for _, a in ipairs(D.abilities) do
      if a.kind == "trait" and a.ranks[1].id < 0 and a.speed and math.abs(o.speed - a.speed) < 0.05 then
        addSeen(out, have, a, a.ranks[1])
      end
    end
  end
end

-- Was das Tier lehrt: nil = unklar (keine Zähmung, keine Angabe); sonst { { a, r }, … }, leer = lehrt nichts.
-- discover = true: nur eigene Zähmungen (Entdeckermodus). Sonst auch Daten und fremde Zähmungen.
function ns.TeachInfo(npc, discover)
  local out, have, clear = {}, {}, false
  for _, o in ipairs(ns.ObservationsOf(npc)) do
    if not discover or ns.OwnTame(o) then
      clear = true
      fromObservation(o, out, have)
    end
  end
  if not discover then
    -- nur, was die Einstellungen zeigen; Widerlegtes nie
    for _, e in ipairs(ns.AllBeastTeaches(npc) or {}) do
      if ns.ShowConf(e.conf) then
        clear = true
        addSeen(out, have, e.a, e.r)
      end
    end
  end
  if not clear then return nil end
  table.sort(out, function(x, y)
    local nx, ny = ns.AbilityName(x.a), ns.AbilityName(y.a)
    if nx ~= ny then return nx < ny end
    return (x.r.rank or 0) < (y.r.rank or 0)
  end)
  return out
end

-- ---- Fortschritt einer Zone ----
-- { beasts, beastsKnown, track, found, known, teachers, teachersKnown, ranks, ranksFound, cells, points }
-- Y aus allem, was bekannt ist (Daten, Zellen, Zähmungen, Fährten). Ränge: nur die, die ein Lehrtier der Zone
-- lehrt; Tierausbilder und Ränge ohne Lehrtier zählen nicht. Den Fortschritt treibt nur „Fähigkeiten bekannt“
-- (Nutzer, 17.10.2026): Fährte und Fund bewegen ihn nicht.
--   Entdeckermodus: X aus eigenen Funden – beastsKnown = selbst gezähmt, teachersKnown und ranksFound selbst
--                   identifiziert.
--   Komplettmodus:  X aus allen Daten – beastsKnown = irgendwer weiß, was es lehrt (Daten oder Zähmung);
--                   Lehrtiere und Ränge sind damit alle bekannt (X = Y).
-- track, found und known zählen die Status je Tier (für /fhp gebiet), points alle Fundorte der Zone.
function ns.ZoneProgress(map)
  local discover = ns.Discovering()
  local p = { beasts = 0, beastsKnown = 0, track = 0, found = 0, known = 0, teachers = 0, teachersKnown = 0,
    ranks = 0, ranksFound = 0, cells = 0, points = 0 }
  local teaches = {}   -- npc → { r = true } aus den Daten, dazu aus Zähmungen (unten)
  local abilityOf, order = {}, {}   -- Rang → Fähigkeit und Platz in den Daten, für die Kacheln (#19)
  for i, a in ipairs(D.abilities) do
    for _, x in ipairs(a.ranks) do abilityOf[x], order[x] = a, i end
    if a.source == "tame" then
      for _, t in ipairs(a.teach) do
        local r
        for _, x in ipairs(a.ranks) do if x.rank == t[2] then r = x end end
        if r and (t[3] or 1) < ns.CONF_REFUTED then
          teaches[t[1]] = teaches[t[1]] or {}
          teaches[t[1]][r] = true
        end
      end
    end
  end
  local ranksAll, ranksFound = {}, {}
  -- Zähmungen (eigene und geteilte) zeigen Lehrtiere auch bei Tieren, die (noch) nicht in den Daten stehen
  for npc in pairs(ns.BeastsIn(map)) do
    for _, o in ipairs(ns.ObservationsOf(npc)) do
      local out = {}
      fromObservation(o, out, {})
      for _, e in ipairs(out) do
        if e.a.source == "tame" then
          teaches[npc] = teaches[npc] or {}
          teaches[npc][e.r] = true
        end
      end
    end
  end
  -- Kacheln im Reiter „Gebiet“ (#19): je Lehrtier und je Rang, ob man es kennt. Feste Reihenfolge (NPC-ID,
  -- Fähigkeit und Rang), damit eine Kachel beim Entdecken an ihrem Platz bleibt und sich nur umdreht.
  p.teacherList, p.rankList = {}, {}
  local teachersOf = {}
  for npc in pairs(ns.BeastsIn(map)) do
    p.beasts = p.beasts + 1
    local st = ns.BeastStatus(npc, map)
    if p[st] then p[st] = p[st] + 1 end
    if discover then
      if st == "known" then p.beastsKnown = p.beastsKnown + 1 end
    elseif ns.TeachInfo(npc, false) then
      p.beastsKnown = p.beastsKnown + 1
    end
    p.cells = p.cells + ownCells(npc, map)
    p.points = p.points + (ns.ZoneCounts(npc, true)[map] or 0)
    if teaches[npc] then
      p.teachers = p.teachers + 1
      local known = not discover or st == "known"
      if known then p.teachersKnown = p.teachersKnown + 1 end
      p.teacherList[#p.teacherList + 1] = { npc = npc, known = known }
      for r in pairs(teaches[npc]) do
        ranksAll[r] = true
        -- erkannte Lehrtiere je Rang: Ziel für den Klick auf eine Rang-Kachel, wenn ns.Teachers keins nennt
        if known then
          teachersOf[r] = teachersOf[r] or {}
          table.insert(teachersOf[r], npc)
        end
        if not discover then
          ranksFound[r] = true
        elseif st == "known" then
          -- selbst identifiziert: eine eigene Zähmung zeigte diesen Rang
          for _, e in ipairs(ns.TeachInfo(npc, true) or {}) do
            if e.r == r then ranksFound[r] = true end
          end
        end
      end
    end
  end
  for _ in pairs(ranksAll) do p.ranks = p.ranks + 1 end
  for _ in pairs(ranksFound) do p.ranksFound = p.ranksFound + 1 end
  for r in pairs(ranksAll) do
    local npcs = teachersOf[r] or {}
    table.sort(npcs)
    p.rankList[#p.rankList + 1] = { a = abilityOf[r], r = r, found = ranksFound[r] == true, npcs = npcs }
  end
  table.sort(p.teacherList, function(x, y) return x.npc < y.npc end)
  table.sort(p.rankList, function(x, y)
    local ox, oy = order[x.r] or 0, order[y.r] or 0
    if ox ~= oy then return ox < oy end
    return (x.r.rank or 0) < (y.r.rank or 0)
  end)
  return p
end

-- /fhp gebiet: Fortschritt der aktuellen Zone im Chat (Entwicklerwerkzeug, nur deutsch)
function ns.DiscoverStatus()
  local map = ns.CellHere and ns.CellHere()
  if not map then ns.Print("Keine Karte für den Standort."); return end
  local p = ns.ZoneProgress(map)
  ns.Print(("%s (%s): Tiere %d von %d bekannt (%d Fährten, %d gefunden, %d bekannt) · Lehrtiere %d von %d · "
    .. "Ränge %d von %d · %d eigene Zellen"):format(ns.ZoneName(map), ns.Discovering() and "Entdecker" or "Komplett",
    p.beastsKnown, p.beasts, p.track, p.found, p.known, p.teachersKnown, p.teachers, p.ranksFound, p.ranks, p.cells))
  local owner = ns.db and ns.db.discoverOwner
  ns.Print(("Funde: %s · dieser Charakter %s · bisherige Funde %s"):format(
    ns.Finds() == ns.db and "Konto" or "Charakter", ns.MyRep() or "?",
    owner == nil and "noch nicht übernommen" or owner == "" and "gab es keine"
      or ("übernommen von %s%s"):format(owner, owner == ns.MyRep() and " (dieser Charakter)" or "")))
end

-- ---- Bisherige Funde übernehmen (#43) ----
-- Fährten und Zellen bis 0.10.0 liegen nur im Konto, ohne Charakter. Sie gehen einmal an den Hauptcharakter:
-- den mit den meisten eigenen Sichtungen und Zähmungen (die tragen das Kürzel), bei Gleichstand das kleinere
-- Kürzel. Jeder Charakter prüft das beim Einloggen; wer nicht der Hauptcharakter ist, fängt bei null an, bis
-- sich der Hauptcharakter einloggt. Danach steht in ForeverHunterPetsDB.discoverOwner sein Kürzel („“: es gab
-- nichts zu übernehmen). Nicht ganz genau: Was ein anderer Charakter nach dem Update und vor diesem Einloggen
-- fand, steht auch im Konto und geht mit.
local function mergeList(a, b)   -- „1431,1429“ + „1429,1411“
  if not a then return b end
  for x in b:gmatch("%d+") do
    local have = false
    for y in a:gmatch("%d+") do if x == y then have = true; break end end
    if not have then a = a .. "," .. x end
  end
  return a
end

local function mergeCells(a, b)   -- „xyxy…“, jede Zelle einmal
  a = a or ""
  for i = 1, #b - 1, 2 do
    local cell, have = b:sub(i, i + 1), false
    for j = 1, #a - 1, 2 do if a:sub(j, j + 1) == cell then have = true; break end end
    if not have then a = a .. cell end
  end
  return a
end

local function takeOver()
  local db, char, me = ns.db, ns.char, ns.MyRep()
  if not (db and char and me) or db.discoverOwner ~= nil then return end
  if not (next(db.seenIn or {}) or next(db.loc or {})) then
    db.discoverOwner = ""
    return
  end
  local score = { [me] = 0 }
  for rep in pairs(db.myReps or {}) do score[rep] = 0 end
  for _, kind in ipairs({ { db.sights, ns.ParseSighting }, { db.obs, ns.ParseObservation } }) do
    for _, s in ipairs(kind[1] or {}) do
      local o = kind[2](s)
      if o and score[o.rep] then score[o.rep] = score[o.rep] + 1 end
    end
  end
  local best
  for rep, n in pairs(score) do
    if not best or n > score[best] or (n == score[best] and rep < best) then best = rep end
  end
  if best ~= me then return end
  char.seenIn = char.seenIn or {}
  for npc, list in pairs(db.seenIn or {}) do char.seenIn[npc] = mergeList(char.seenIn[npc], list) end
  char.loc = char.loc or {}
  for npc, maps in pairs(db.loc or {}) do
    char.loc[npc] = char.loc[npc] or {}
    for map, cells in pairs(maps) do char.loc[npc][map] = mergeCells(char.loc[npc][map], cells) end
  end
  db.discoverOwner = me
end
ns.On("PLAYER_LOGIN", function() ns.SafeCall("discover", takeOver) end)

-- Die Probe „Kampf“ (E1) ist ausgewertet: Ein Kampf bringt nichts Zusätzliches, siehe
-- docs/technik/api-befunde.md. Ihre Reste in den SavedVariables werden gelöscht.
ns.On("ADDON_LOADED", function() if ns.db then ns.db.combatProbe = nil end end)

-- ---- Modus je Charakter (E2) ----
-- Komplettmodus (alles) oder Entdeckermodus (nur eigene Funde). Gewählt im Startdialog (UI/ModeDialog.lua)
-- oder in den Einstellungen; bis zur Wahl zeigt das Addon nichts, was spoilern könnte. modeChosen ist ein
-- eigenes Feld, weil die Einstellung beim Registrieren ihren Standard in discover schreiben könnte.
function ns.ModeChosen() return ns.char ~= nil and ns.char.modeChosen == true end
function ns.Discovering() return ns.ModeChosen() and ns.char.discover == true end

local modeListeners = {}
function ns.OnModeChanged(fn) modeListeners[#modeListeners + 1] = fn end
function ns.ModeChanged()
  for _, fn in ipairs(modeListeners) do ns.SafeCall("mode", fn) end
  if ns.ShowConfChanged then ns.ShowConfChanged() end   -- Ansichten neu aufbauen
end

function ns.SetMode(discover)
  if not ns.char then return end
  ns.char.discover = discover and true or false
  ns.char.modeChosen = true
  ns.ModeChanged()
end
