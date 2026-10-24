-- Forever Hunter Pets · Beobachtungen im Spiel teilen. Addons kommen nicht ins Internet; die Daten
-- wandern als Addon-Nachrichten zwischen Spielern, die gleichzeitig online sind: über Gilde, Gruppe
-- und einen verborgenen Kanal. Abschaltbar in den Einstellungen („Beobachtungen teilen“).
--
-- Nachrichten (Prefix FHPets, höchstens 255 Byte):
--   O1;npc;stufe;zauberIDs;tempo;zeit;melder   eine Beobachtung, wie in ForeverHunterPetsDB.obs
--   S1;npc;stufe;einstufung;familie;sprache;name;zeit;melder[;tempo]
--                                              eine Sichtung, wie in ForeverHunterPetsDB.sights; gesendet
--                                              nur, was die mitgelieferten Daten nicht kennen
--   F1;npc;uiMapID;zellen;melder               neue eigene Fundort-Zellen (Core/Places.lua), gebündelt
--                                              höchstens alle 5 Minuten, bis zu 100 Zellen
--   H1;version;anzahl                          Gruß nach dem Einloggen; Antwort: einige Beobachtungen
--                                              per Flüstern an den, der gegrüßt hat
-- Der Melder ist ein Kürzel aus acht Hexziffern, gerechnet aus dem vollen Namen. Gespeichert werden nie
-- Namen, nur die Kürzel – sie zählen, wie viele verschiedene Spieler etwas gesehen haben.
--
-- Protokollregel (#12): Im Spiel laufen viele Versionen nebeneinander. Neue Felder kommen deshalb nur hinten
-- an eine Nachricht, und wer ein Feld am Ende nicht kennt, liest die Nachricht trotzdem und übergeht es.
-- Ein neues Kürzel (O2 …) nur, wenn sich ein vorhandenes Feld ändert; ältere Versionen lesen das dann nicht.
local _, ns = ...
local D = ns.Data

local PREFIX = "FHPets"
local CHANNEL = "FHPetsNet"
local INTERVAL = 2.0          -- Sekunden zwischen zwei Nachrichten (Blizzard drosselt bei etwa 1/s)
local MAX_QUEUE = 80
local REPLY_MAX = 20          -- Beobachtungen als Antwort auf einen Gruß
local CELL_REPLY = 10         -- Fundort-Bündel als Antwort auf einen Gruß
local PER_SENDER = 200        -- angenommene Beobachtungen je Absender und Sitzung
local MAX_STORED = 5000
local MIN_TIME = 1788220800   -- 01.09.2026: ältere Zeitstempel sind unplausibel
local MAX_REJECTS = 20        -- verschiedene verworfene Nachrichten, roh in ForeverHunterPetsDB.shareRejects
local REPLY_EVERY = 300       -- Sekunden: höchstens eine Antwort auf Grüße aus dem Kanal, und so weit zurück zählen (#52)

local queue, busy = {}, false
-- Zähler dieser Sitzung für /fhp teilen (M4, Plan Veröffentlichung V1): rein lokal, kein zusätzlicher Verkehr.
-- Je Art (O1 Zähmung, S1 Sichtung, F1 Zellen, H1 Gruß): gesendet, empfangen, davon neu gespeichert, und warum
-- verworfen. Liegt auch in ForeverHunterPetsDB.shareStats, damit ein Test nach /reload nachlesbar bleibt.
local KINDS = { "O1", "S1", "F1", "H1" }
local stats = { sent = {}, recv = {}, new = {}, dropped = {}, last = nil, since = nil, replied = 0, skipped = 0 }
local function count(t, k, n) t[k] = (t[k] or 0) + (n or 1) end
local perSender, greeted = {}, {}
local selfName, selfRep
local registered = false

-- ---- Melder-Kürzel ----
local function hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
  return ("%08x"):format(h)
end
ns.ReporterHash = hash

local function me()
  if selfName then return selfName, selfRep end
  local ok, name, realm = pcall(UnitFullName, "player")
  name, realm = ok and ns.clean(name), ok and ns.clean(realm)
  if type(name) ~= "string" then return nil end
  if type(realm) ~= "string" or realm == "" then
    local ok2, r = pcall(GetNormalizedRealmName)
    realm = ok2 and ns.clean(r) or ""
  end
  selfName = name .. "-" .. realm
  selfRep = hash(selfName)
  return selfName, selfRep
end

-- Kürzel eines Absenders, wie me() es für sich rechnet: „Vorname Nachname“ → „Vorname-Nachname“
local function senderRep(sender)
  return hash((sender:gsub(" ", "-")))
end

-- ---- Herkunft fremder Kürzel (#15) ----
-- Das Kürzel steht in der Nachricht und ist nicht an den Absender gebunden (Weitergereichtes trägt das des
-- ursprünglichen Melders). Deshalb merkt sich das Addon je fremdem Kürzel, über welche Absender es kam:
-- ForeverHunterPetsDB.via[melder] = „abs1abs2…“ (Kürzel der Absender, keine Namen). Kommt eine Meldung direkt,
-- ist der Absender das Kürzel selbst. Mehr als VIA_MAX Absender braucht die Regel nicht.
-- Regel: Fremde Melder zählen für „ab 3 Meldern“ nur, wenn sie zusammen über mindestens zwei verschiedene
-- Absender kamen – ein einzelner Absender genügt nie. Kürzel, die schon vor diesem Stand gespeichert waren,
-- stehen einmalig in ForeverHunterPetsDB.viaLegacy und gelten als „Herkunft unbekannt“: Sie zählen wie bisher.
-- Jedes andere Kürzel ohne Angabe zählt nicht, auch wenn via voll ist (#60). Dieselbe Regel steht in
-- tools/build-data.mjs.
local VIA_MAX, VIA_REPS, VIA_PRUNE = 4, 5000, 600
local viaCount, viaOf   -- Zahl der Kürzel in der Tabelle viaOf
local prunedAt

-- via voll (#61): Kürzel entfernen, die in keinem Speicher mehr vorkommen (verdrängt), höchstens alle VIA_PRUNE s.
-- Dasselbe für viaLegacy. Was danach keinen Platz findet, bleibt ohne Herkunft und zählt nicht (#60).
local function pruneVia(via)
  local now = GetTime()
  if prunedAt and now - prunedAt < VIA_PRUNE then return end
  prunedAt = now
  local present = {}
  for _, s in ipairs(ns.db.obs or {}) do
    local o = ns.ParseObservation(s)
    if o then present[o.rep] = true end
  end
  for _, s in ipairs(ns.db.sights or {}) do
    local o = ns.ParseSighting(s)
    if o then present[o.rep] = true end
  end
  for _, maps in pairs(ns.db.locIn or {}) do
    for _, byRep in pairs(maps) do
      for rep in pairs(byRep) do present[rep] = true end
    end
  end
  viaCount = 0
  for rep in pairs(via) do
    if present[rep] then viaCount = viaCount + 1 else via[rep] = nil end
  end
  for rep in pairs(type(ns.db.viaLegacy) == "table" and ns.db.viaLegacy or {}) do
    if not present[rep] then ns.db.viaLegacy[rep] = nil end
  end
end

local function noteVia(rep, sender)
  if type(rep) ~= "string" or not rep:find("^%x%x%x%x%x%x%x%x$") then return end
  local via = ns.db.via
  if type(via) ~= "table" then via = {}; ns.db.via = via end
  local have = via[rep]
  if type(have) ~= "string" then
    if viaOf ~= via then
      viaOf, viaCount = via, 0
      for _ in pairs(via) do viaCount = viaCount + 1 end
    end
    if viaCount >= VIA_REPS then pruneVia(via) end
    if viaCount >= VIA_REPS then return end
    have = ""
    viaCount = viaCount + 1
  end
  if #have >= VIA_MAX * 8 then return end
  local from = senderRep(sender)
  for i = 1, #have - 7, 8 do
    if have:sub(i, i + 7) == from then return end
  end
  via[rep] = have .. from
end

-- Kamen diese fremden Kürzel ({ [Kürzel] = true }) über mindestens zwei verschiedene Absender – oder ist bei
-- einem die Herkunft unbekannt (viaLegacy)? Dann zählen sie für die Schwelle. Kürzel ohne Angabe tragen nichts
-- bei; im Zweifel (kaputter Speicher) zählen sie nicht (#60).
function ns.ViaDistinct(reps)
  local via = ns.db and ns.db.via
  local legacy = ns.db and ns.db.viaLegacy
  if type(via) ~= "table" then via = {} end
  if type(legacy) ~= "table" then legacy = {} end
  local first
  for rep in pairs(reps) do
    if legacy[rep] then return true end
    local have = via[rep]
    if type(have) ~= "string" then have = "" end
    for i = 1, #have - 7, 8 do
      local from = have:sub(i, i + 7)
      if not first then first = from elseif from ~= first then return true end
    end
  end
  return false
end

-- Kürzel des eingeloggten Charakters; eigene Beobachtungen tragen es von Anfang an
function ns.MyRep()
  local _, rep = me()
  return rep
end

-- Die Kürzel aller eigenen Charaktere merkt sich das Konto (ForeverHunterPetsDB.myReps): Beobachtungen
-- damit sind eigene, auch wenn sie später über andere Spieler zurückkommen. Ältere eigene Einträge ohne
-- Kürzel (bis zum Teilen im Spiel) bekommen das des Charakters, mit dem man sich einloggt.
local function claimOwn()
  local rep = ns.MyRep()
  if not (rep and ns.db) then return end
  ns.db.myReps = ns.db.myReps or {}
  ns.db.myReps[rep] = true
  local changed = false
  for i, s in ipairs(ns.db.obs or {}) do
    if type(s) == "string" and s:sub(-1) == ";" then ns.db.obs[i] = s .. rep; changed = true end
  end
  if changed then ns.ObservationsChanged() end
end

-- Einmalig (#60): Fremde Kürzel, die schon gespeichert sind, aber keine Herkunft haben, stammen von vor #15 und
-- kommen nach viaLegacy. Danach gibt es die Tabelle, auch leer, und die Markierung läuft nie wieder.
local function markLegacy()
  if not ns.db or type(ns.db.viaLegacy) == "table" then return end
  local via = type(ns.db.via) == "table" and ns.db.via or {}
  local mine = ns.db.myReps or {}
  local legacy = {}
  local function note(rep)
    if type(rep) == "string" and #rep == 8 and not mine[rep] and via[rep] == nil then legacy[rep] = true end
  end
  for _, s in ipairs(ns.db.obs or {}) do
    local o = ns.ParseObservation(s)
    if o and not o.own then note(o.rep) end
  end
  for _, s in ipairs(ns.db.sights or {}) do
    local o = ns.ParseSighting and ns.ParseSighting(s)
    if o and not o.own then note(o.rep) end
  end
  for _, maps in pairs(ns.db.locIn or {}) do
    for _, byRep in pairs(type(maps) == "table" and maps or {}) do
      for rep in pairs(type(byRep) == "table" and byRep or {}) do note(rep) end
    end
  end
  ns.db.viaLegacy = legacy
end

local function enabled()
  return ns.db and ns.db.ui and ns.db.ui.share and true or false
end

-- In Kampf und Instanz bleibt alles liegen: geheime Werte, und Addon-Nachrichten sind dort gesperrt
local function quiet()
  if InCombatLockdown and ns.clean(InCombatLockdown()) then return true end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    if ok and ns.clean(inside) then return true end
  end
  return false
end

-- ---- Senden mit Drosselung ----
local function channelIndex()
  if not GetChannelName then return nil end
  local ok, id = pcall(GetChannelName, CHANNEL)
  id = ok and tonumber(ns.clean(id)) or 0
  return id > 0 and id or nil
end

local R = (Enum and Enum.SendAddonMessageResult) or {}
local THROTTLED = { [R.AddonMessageThrottle or 3] = true, [R.ChannelThrottle or 8] = true }

-- Liefert, ob die Nachricht erledigt ist (gesendet oder verworfen), und was der Client sagte
local function sendNow(msg, kind, target)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return true, "keine SendAddonMessage" end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, kind, target)
  if not ok then return true, "Fehler: " .. tostring(res) end   -- verwerfen, nicht endlos wiederholen
  res = ns.clean(res)
  if type(res) == "number" and THROTTLED[res] then return false, "gedrosselt (" .. res .. ")" end
  return true, "Ergebnis " .. tostring(res)
end

-- Ziel → GetTime() des letzten Flüsterns, für den Chat-Filter unten (#28). Abgesichert: Wirft etwas in pump, plant
-- es sich nicht neu ein, und die Warteschlange stünde für die ganze Sitzung – das Teilen darf daran nie hängen.
local whispered = {}
local function noteWhisper(target)
  whispered[target] = GetTime()
end

local pump
pump = function()
  if #queue == 0 then busy = false; return end
  busy = true
  if enabled() and not quiet() then
    local item = queue[1]
    local done, what = sendNow(item.msg, item.kind, item.target)
    if item.kind == "WHISPER" and item.target then pcall(noteWhisper, item.target) end
    if item.onSent then item.onSent(what) end
    if done and what:find("^Ergebnis") then count(stats.sent, item.msg:sub(1, 2)) end
    if done then table.remove(queue, 1) end
  end
  ns.After(INTERVAL, pump)
end

-- Eigenes zuerst (#52): Antworten auf Grüße (low) stehen hinten, eigene Meldungen kommen vor die erste Antwort.
-- Ist die Schlange voll, verdrängt eine eigene Meldung die letzte Antwort; eine Antwort wird dann gar nicht erst
-- eingereiht. Was so wegfällt, zählt als „Warteschlange voll“ (/fhp teilen).
local function enqueue(msg, kind, target, onSent, low)
  if #msg > 250 then return end
  local item = { msg = msg, kind = kind, target = target, onSent = onSent, low = low }
  if low then
    if #queue >= MAX_QUEUE then count(stats.dropped, "Warteschlange voll"); return end
    queue[#queue + 1] = item
  else
    if #queue >= MAX_QUEUE then
      local last
      for i = #queue, 1, -1 do
        if queue[i].low then last = i; break end
      end
      count(stats.dropped, "Warteschlange voll")
      if not last then return end
      table.remove(queue, last)
    end
    local at = #queue + 1
    for i, q in ipairs(queue) do
      if q.low then at = i; break end
    end
    table.insert(queue, at, item)
  end
  if not busy then pump() end
end

-- an alle Wege, die gerade offen sind
local function broadcast(msg)
  if IsInGuild and ns.clean(IsInGuild()) then enqueue(msg, "GUILD") end
  if IsInRaid and ns.clean(IsInRaid()) then enqueue(msg, "RAID")
  elseif IsInGroup and ns.clean(IsInGroup()) then enqueue(msg, "PARTY") end
  local ch = channelIndex()
  if ch then enqueue(msg, "CHANNEL", ch) end
end

-- eigene Beobachtungen tragen beim Versand das eigene Kürzel, fremde behalten ihres
local function outgoing(s)
  if type(s) ~= "string" then return nil end
  if s:sub(-1) == ";" then
    local _, rep = me()
    if not rep then return nil end
    return "O1;" .. s .. rep
  end
  return "O1;" .. s
end

function ns.ShareOwn(s)
  if not enabled() then return end
  local msg = outgoing(s)
  if msg then broadcast(msg) end
end

-- ---- Empfangen und prüfen ----
local validSpell
ns.OnAbilitiesChanged(function() validSpell = nil end)
local function spellOk(id)
  if not validSpell then
    validSpell = {}
    for _, a in ipairs(D.abilities) do
      for _, r in ipairs(a.ranks) do validSpell[r.id] = true end
    end
  end
  return validSpell[id]
end

-- Nur, was eine echte Zähmung ergeben kann: Stufe 1–63, bekannte Pet-Zauber, plausibles Tempo und
-- eine Zeit zwischen September 2026 und morgen. Liefert sonst false und den Grund – je Prüfung ein eigener,
-- damit /fhp teilen zeigt, was zuschlägt (#12: eigene Zähmungen, die andere zurückschicken, liefen als „ungültig“).
local function valid(s)
  local o = ns.ParseObservation(s)
  if not o then return false, "unlesbar" end
  local _, rep = me()
  if o.own or o.rep == rep then return false, "eigene" end   -- eigene, auch von Twinks, zurückgeschickt
  if #o.rep ~= 8 then return false, "Melder" end
  if o.level < 1 or o.level > 63 or o.npc < 1 or o.npc > 9999999 then return false, "Stufe oder NPC" end
  for id in pairs(o.spells) do
    -- ein Zauber, den hier noch niemand kennt: zählen, damit man es im Test sieht
    if not spellOk(id) then return false, "unbekannter Zauber" end
  end
  if o.speed and (o.speed < 0.5 or o.speed > 4) then return false, "Tempo" end
  local now = time and time() or 0
  if not o.time or o.time < MIN_TIME or (now > 0 and o.time > now + 86400) then return false, "Zeit unplausibel" end
  return true, nil, o
end

-- Liefern, ob neu gespeichert, sonst den Grund, und als drittes das Kürzel des Melders, sobald die Meldung
-- gültig ist (für die Herkunft, #15)
local function receiveObservation(body, sender)
  local s = body:sub(4)                    -- ohne „O1;“
  local ok, why, o = valid(s)
  if not ok then return false, why end
  perSender[sender] = (perSender[sender] or 0) + 1
  if perSender[sender] > PER_SENDER then return false, "Obergrenze je Absender" end
  -- voll: die ältesten fremden verdrängen, ein Zwanzigstel auf einmal (#61); nur ohne fremde bleibt es voll
  if ns.ObservationCount() >= MAX_STORED and ns.DropOldObservations(MAX_STORED / 20) == 0 then return false, "Speicher voll" end
  if not ns.AddObservation(s) then return false, "schon bekannt", o.rep end
  ns.receivedNew = (ns.receivedNew or 0) + 1
  if not ns.refreshPending then
    ns.refreshPending = true
    ns.After(5, function()
      ns.refreshPending = false
      ns.ObservationsChanged()
    end)
  end
  return true, nil, o.rep
end

-- ---- Fundort-Zellen (Core/Places.lua) ----
function ns.ShareCells(npc, map, cells)
  local _, rep = me()
  if enabled() and rep then broadcast(("F1;%d;%d;%s;%s"):format(npc, map, cells, rep)) end
end

-- Nur gültige Zellen bekannter Form, höchstens ein Bündel je Nachricht und PER_SENDER Nachrichten
local cellsPerSender = {}
local function receiveCells(body, sender)
  local _, myRep = me()
  local npc, map, cells, rep, rest = body:match("^F1;(%d+);(%d+);([%w]+);(%x+)(.*)$")
  npc, map = tonumber(npc), tonumber(map)
  if not (npc and map and rep) or (rest ~= "" and rest:sub(1, 1) ~= ";") then return false, "unlesbar" end
  if rep == myRep or (ns.db and ns.db.myReps and ns.db.myReps[rep]) then return false, "eigene" end
  if #rep ~= 8 then return false, "Melder" end
  if npc < 1 or npc > 9999999 or map < 1 or map > 100000 or #cells > ns.CELL_BUNDLE * 2 then return false, "Karte oder Größe" end
  if not ns.ValidCells(cells) then return false, "Zellen" end
  if ns.Blocked(npc, map) then return false, "nicht zähmbar" end   -- ältere Versionen anderer Spieler (#90)
  cellsPerSender[sender] = (cellsPerSender[sender] or 0) + 1
  if cellsPerSender[sender] > PER_SENDER then return false, "Obergrenze je Absender" end
  if (ns.AddCells(npc, map, cells, rep) or 0) == 0 then return false, "schon bekannt", rep end
  return true, nil, rep
end

-- ---- Sichtungen (Core/Sightings.lua) ----
function ns.ShareSighting(s)
  if enabled() and type(s) == "string" then broadcast("S1;" .. s) end
end

-- Nur, was ein Anvisieren ergeben kann: Stufe 1–63, Einstufung 0–4, eine Familie, eine bekannte
-- Client-Sprache, ein Name ohne Steuerzeichen und eine plausible Zeit
local sightPerSender = {}
local function receiveSighting(body, sender)
  local _, rep = me()
  local s = body:sub(4)                    -- ohne „S1;“
  local o = ns.ParseSighting(s)
  if not o then return false, "unlesbar" end
  if o.own or (rep and o.rep == rep) then return false, "eigene" end
  if #o.rep ~= 8 then return false, "Melder" end
  if o.level < 1 or o.level > 63 or o.cls > 4 or o.fam < 1 or o.fam > 1000 or o.npc > 9999999 then return false, "Stufe oder Werte" end
  if not ns.LOCALES[o.lang] or #o.name > 60 or o.name:find("%c") then return false, "Sprache oder Name" end
  if o.speed and (o.speed < 0.5 or o.speed > 5) then return false, "Tempo" end
  if ns.DEMON_FAMILY[o.fam] then return false, "keine Jäger-Familie" end   -- Dämonen älterer Versionen (#80)
  if ns.BlockedSighting(o.npc, o.level) then return false, "nicht zähmbar" end   -- Begleiter von NPCs (#90)
  local now = time and time() or 0
  if not o.time or o.time < MIN_TIME or (now > 0 and o.time > now + 86400) then return false, "Zeit unplausibel" end
  sightPerSender[sender] = (sightPerSender[sender] or 0) + 1
  if sightPerSender[sender] > PER_SENDER then return false, "Obergrenze je Absender" end
  if not ns.AddSighting(s) then return false, "schon bekannt", o.rep end
  return true, nil, o.rep
end

-- Auf einen Gruß ein paar Beobachtungen zurück: eigene zuerst, dann die neuesten; dazu bis zu
-- CELL_REPLY eigene Fundort-Bündel. Weitergeleitet wird nichts Fremdes außer Beobachtungen, und nichts, was
-- der Grüßende selbst gemeldet hat (#12). Sein Kürzel kommt aus dem Namen wie in me(): „Vorname Nachname“
-- → „Vorname-Nachname“. Twinks tragen ein anderes Kürzel, deren Zähmungen gehen weiter mit.
--
-- Damit die Antworten nicht mit der Zahl der Spieler wachsen (#52), gilt für Grüße aus dem Kanal (Gilde und Gruppe
-- immer): höchstens eine Antwort je REPLY_EVERY Sekunden, und auch dann nur mit Wahrscheinlichkeit 1/n, n = Zahl
-- der Grüße aus dem Kanal in den letzten REPLY_EVERY Sekunden. So antworten im Schnitt etwa gleich viele Spieler,
-- egal wie viele online sind. Wer nicht antwortet, verbraucht kein Budget und merkt sich den Grüßenden nicht.
local heardAt, lastReply = {}, nil   -- GetTime() der gehörten Grüße aus dem Kanal und der letzten Antwort darauf
local function noteGreeting()
  local now = GetTime()
  for i = #heardAt, 1, -1 do
    if now - heardAt[i] > REPLY_EVERY then table.remove(heardAt, i) end
  end
  heardAt[#heardAt + 1] = now
end

local function mayReply()
  local now = GetTime()
  if lastReply and now - lastReply < REPLY_EVERY then return false end
  if math.random() >= 1 / #heardAt then return false end
  lastReply = now
  return true
end

local function reply(sender, target, fromChannel)
  if fromChannel then noteGreeting() end
  if greeted[sender] then return end
  if fromChannel and not mayReply() then stats.skipped = stats.skipped + 1; return end
  greeted[sender] = true
  stats.replied = stats.replied + 1
  target = target or sender
  local theirs = hash((target:gsub(" ", "-")))
  local _, rep = me()
  if rep and ns.OwnCellBundles then
    for _, b in ipairs(ns.OwnCellBundles(CELL_REPLY)) do
      enqueue(("F1;%d;%d;%s;%s"):format(b.npc, b.map, b.cells, rep), "WHISPER", target, nil, true)
    end
  end
  local own, other = {}, {}
  for _, s in ipairs(ns.db.obs or {}) do
    if type(s) == "string" then
      local o = ns.ParseObservation(s)
      if o and o.own then own[#own + 1] = s elseif o and o.rep ~= theirs then other[#other + 1] = s end
    end
  end
  local n = 0
  for _, list in ipairs({ own, other }) do
    for i = #list, 1, -1 do
      if n >= REPLY_MAX then return end
      local msg = outgoing(list[i])
      if msg then enqueue(msg, "WHISPER", target, nil, true); n = n + 1 end
    end
  end
end

-- ---- Selbsttest (/fhp teilen test): ohne zweiten Spieler den echten Weg prüfen ----
-- Schickt über jeden offenen Weg eine Testnachricht „T1;kennung;weg;beobachtung“ an sich selbst. Der Client
-- gibt eigene Addon-Nachrichten in der Regel zurück; ankommen heißt: Warteschlange, Drosselung, Kanal
-- und Empfang funktionieren. Die Beobachtung darin wird wie eine fremde geprüft, aber nicht gespeichert.
local test
-- Alles landet auch in ForeverHunterPetsDB.probe, damit es nach /reload aus der Datei lesbar ist
local function testOut(text)
  if test then test.log[#test.log + 1] = text end
  ns.Print(text)
end

local function testDone()
  if not test then return end
  local reg = "?"
  if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
    local ok, r = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, PREFIX)
    reg = ok and tostring(ns.clean(r)) or "Fehler"
  end
  testOut(("Selbsttest: Prefix %s registriert: %s · eigener Name %s · Addon-Nachrichten mit unserem Prefix empfangen: %d")
    :format(PREFIX, reg, tostring((me())), #test.heard))
  for _, h in ipairs(test.heard) do testOut("  empfangen: " .. h) end
  for _, w in ipairs(test.ways) do
    local r = test.back[w]
    local sent = test.sent[w] and ("gesendet, " .. test.sent[w]) or "nicht gesendet (Warteschlange, Kampf oder Instanz?)"
    if r then
      testOut(("Selbsttest %s: %s, zurück nach %.1f s, Prüfung %s"):format(w, sent, r.after, r.ok and "bestanden" or "NICHT bestanden"))
    else
      testOut(("Selbsttest %s: %s, nicht zurückgekommen"):format(w, sent))
    end
  end
  if ns.db then ns.db.probe = test.log end
  test = nil
end

function ns.ShareTest()
  if not enabled() then ns.Print("Selbsttest: Teilen ist ausgeschaltet."); return end
  if quiet() then ns.Print("Selbsttest: im Kampf oder in einer Instanz wird nicht gesendet."); return end
  local name = me()
  if not name then ns.Print("Selbsttest: eigener Name nicht lesbar."); return end
  local id = ("%04x"):format(math.random(0, 65535))
  -- eine erfundene, aber gültige Beobachtung: Großer Fleischreißer, Stufe 17, Demoralisierendes Kreischen 1
  local sample = ("154;17;24423;2.0;%d;7e570001"):format(time and time() or MIN_TIME)
  test = { id = id, started = GetTime(), back = {}, ways = {}, sent = {}, heard = {}, log = {} }
  testOut("=== Selbsttest Teilen " .. (date and date("%Y-%m-%d %H:%M:%S") or "") .. " · Addon " .. ns.version .. " ===")
  local function way(label, kind, target)
    test.ways[#test.ways + 1] = label
    local t = test
    enqueue(("T1;%s;%s;%s"):format(id, label, sample), kind, target, function(what) t.sent[label] = what end)
  end
  if IsInGuild and ns.clean(IsInGuild()) then way("Gilde", "GUILD") end
  if IsInRaid and ns.clean(IsInRaid()) then way("Schlachtzug", "RAID")
  elseif IsInGroup and ns.clean(IsInGroup()) then way("Gruppe", "PARTY") end
  local ch = channelIndex()
  if ch then way("Kanal", "CHANNEL", ch) else ns.Print("Selbsttest: Kanal " .. CHANNEL .. " nicht beigetreten.") end
  way("Flüstern", "WHISPER", name)
  ns.Print(("Selbsttest läuft über %s; Ergebnis in etwa %d Sekunden."):format(table.concat(test.ways, ", "), #test.ways * 2 + 10))
  ns.After(#test.ways * INTERVAL + 10, testDone)
end

local function receiveTest(text)
  if not test then return end
  local id, label, s = text:match("^T1;(%x+);([^;]+);(.+)$")
  if id ~= test.id or test.back[label] then return end
  test.back[label] = { after = GetTime() - test.started, ok = valid(s) }
end

-- In Forever heißen Charaktere „Vorname Nachname“. Als Absender kommt „Grimmbart Hesingway“ (mit
-- Leerzeichen), UnitFullName liefert dagegen Vor- und Nachname getrennt, woraus hier „Grimmbart-Hesingway“
-- wird (Selbsttest 14.10.2026). Verglichen wird deshalb ohne Leerzeichen, Bindestriche und
-- Groß-/Kleinschreibung – immer der volle Name, nie der Vorname allein: den können andere auch tragen.
local function plain(s)
  return (s:gsub("[%s%-]", "")):lower()
end

local function isSelf(sender, name)
  return name ~= nil and plain(sender) == plain(name)
end

-- ---- Flüstern an Spieler, die offline gegangen sind (#28) ----
-- Die Antwort auf einen Gruß braucht wegen der Drosselung bis zu einer Minute. Geht der Grüßende vorher offline,
-- quittiert der Client jede weitere Nachricht mit „Momentan ist kein Spieler mit dem Namen '…' online.“ Deshalb:
-- Meldet der Client das oder „… ist jetzt offline“, fallen die wartenden Flüster-Nachrichten an ihn weg, und die
-- Meldung „kein Spieler …“ wird verschluckt – nur für Namen, an die das Addon in der letzten Minute geflüstert hat
-- oder für die noch etwas wartet. Die Muster kommen aus den Textvorlagen des Clients, damit jede Sprache greift.
-- Alles hier ist Beiwerk: Was beim Laden fehlschlägt (Textvorlage oder Filter-API fehlt oder sieht anders aus),
-- schaltet nur diesen Schutz ab, nie das Teilen. Deshalb läuft jeder Schritt beim Laden in pcall.
local WHISPER_MEMORY = 60   -- Sekunden
local function pattern(fmt)
  if type(fmt) ~= "string" or not fmt:find("%s", 1, true) then return nil end
  local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1"):gsub("%%%%s", "(.+)")
  return "^" .. p .. "$"
end
local okNF, NOT_FOUND = pcall(pattern, ERR_CHAT_PLAYER_NOT_FOUND_S)
local okWO, WENT_OFFLINE = pcall(pattern, ERR_FRIEND_OFFLINE_S)
if not okNF then NOT_FOUND = nil end
if not okWO then WENT_OFFLINE = nil end

-- Name aus einer Systemmeldung, ohne Spieler-Link und Farbe
local function nameIn(msg, pat)
  if not pat then return nil end
  local name = msg:match(pat)
  if not name then return nil end
  return (name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1"))
end

-- Hat das Addon gerade etwas an diesen Namen geflüstert oder wartet noch etwas?
local function addonWhispers(name)
  local key, now = plain(name), GetTime()
  for target, at in pairs(whispered) do
    if now - at > WHISPER_MEMORY then
      whispered[target] = nil
    elseif plain(target) == key then
      return true
    end
  end
  for _, item in ipairs(queue) do
    if item.kind == "WHISPER" and item.target and plain(item.target) == key then return true end
  end
  return false
end

local function dropWhispers(name)
  local key, n = plain(name), 0
  for i = #queue, 1, -1 do
    local item = queue[i]
    if item.kind == "WHISPER" and item.target and plain(item.target) == key then
      table.remove(queue, i)
      n = n + 1
    end
  end
  if n > 0 then count(stats.dropped, "Flüstern an Offline-Spieler", n) end
end

ns.On("CHAT_MSG_SYSTEM", function(raw)
  local msg = ns.clean(raw)
  if type(msg) ~= "string" then return end   -- geheimer Wert (Kampf, Instanz): nichts tun
  local name = nameIn(msg, NOT_FOUND) or nameIn(msg, WENT_OFFLINE)
  if name then dropWhispers(name) end
end)

-- Der Filter läuft für jedes Chatfenster einzeln; er räumt deshalb nichts ab, er entscheidet nur.
local function hideNotFound(_, _, raw, ...)
  local ok, hide = pcall(function()
    local msg = ns.clean(raw)
    if type(msg) ~= "string" then return false end
    local name = nameIn(msg, NOT_FOUND)
    return name ~= nil and addonWhispers(name)
  end)
  if ok and hide then return true end
  return false, raw, ...
end
pcall(function()
  local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  if addFilter and NOT_FOUND then addFilter("CHAT_MSG_SYSTEM", hideNotFound) end
end)

-- Verworfene Nachrichten mit einem echten Fehlergrund roh aufheben, die letzten MAX_REJECTS über alle
-- Sitzungen (#12): nach /reload aus den SavedVariables lesbar. Ohne Absendernamen, wie überall nur Kürzel.
-- Dieselbe Nachricht mit demselben Grund steht nur einmal da: n zählt die Empfänge, at ist der letzte, und sie
-- rückt ans Ende (#107). Ältere Einträge ohne n gelten als einer.
local EXPECTED = { ["eigene"] = true, ["schon bekannt"] = true, ["Obergrenze je Absender"] = true, ["Speicher voll"] = true }
local function keepReject(text, why, kind)
  if not ns.db then return end
  local list = ns.db.shareRejects or {}
  ns.db.shareRejects = list
  local msg, n = text:sub(1, 255), 1
  why = tostring(why)
  for i = #list, 1, -1 do
    local e = list[i]
    if type(e) == "table" and e.msg == msg and e.why == why then
      n = n + (tonumber(e.n) or 1)
      table.remove(list, i)
    end
  end
  list[#list + 1] = { at = time and time() or 0, why = why, way = tostring(ns.clean(kind)), msg = msg, n = n }
  while #list > MAX_REJECTS do table.remove(list, 1) end
end

ns.On("CHAT_MSG_ADDON", function(prefix, text, kind, sender)
  if not enabled() then return end
  prefix, text, sender = ns.clean(prefix), ns.clean(text), ns.clean(sender)
  if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
  local name = me()
  if test and #test.heard < 20 then
    test.heard[#test.heard + 1] = ("%s von %s über %s: %s"):format(text:sub(1, 3), sender, tostring(ns.clean(kind)), text:sub(1, 40))
  end
  local own = isSelf(sender, name)
  if text:sub(1, 3) == "T1;" then
    if own then receiveTest(text) end
    return
  end
  if own then return end
  local key = plain(sender)
  local t = text:sub(1, 2)
  local ok, why, rep
  if text:sub(1, 3) == "O1;" then
    ok, why, rep = receiveObservation(text, key)
  elseif text:sub(1, 3) == "S1;" then
    ok, why, rep = receiveSighting(text, key)
  elseif text:sub(1, 3) == "F1;" then
    ok, why, rep = receiveCells(text, key)
  elseif text:sub(1, 3) == "H1;" then
    ok = true
    reply(key, sender, ns.clean(kind) == "CHANNEL")   -- zurückgeflüstert wird an den Namen, den der Client nannte
  else
    return
  end
  -- Herkunft vermerken, auch bei „schon bekannt“: genau dann bestätigt ein zweiter Absender (#15). Abgesichert –
  -- das Vermerken darf den Empfang nie stören.
  if rep and (ok or why == "schon bekannt") and ns.db then pcall(noteVia, rep, sender) end
  count(stats.recv, t)
  if ok then count(stats.new, t) else count(stats.dropped, t .. " " .. tostring(why)) end
  if not ok and not EXPECTED[why] then keepReject(text, why, kind) end
  stats.last = { at = time and time() or 0, t = t, way = tostring(ns.clean(kind)) }
  if ns.db then ns.db.shareStats = stats end
end)

-- ---- Kanal und Gruß ----
local function hideChannel()
  if not (ChatFrame_RemoveChannel and NUM_CHAT_WINDOWS) then return end
  for i = 1, NUM_CHAT_WINDOWS do
    local frame = _G["ChatFrame" .. i]
    if frame then pcall(ChatFrame_RemoveChannel, frame, CHANNEL) end
  end
end

local function join()
  if not enabled() or channelIndex() then hideChannel(); return end
  if JoinTemporaryChannel then pcall(JoinTemporaryChannel, CHANNEL) end
  ns.After(2, hideChannel)
end

local function leave()
  if channelIndex() and LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL) end
end

local function hello()
  if not enabled() then return end
  local msg = ("H1;%s;%d"):format(tostring(ns.version):gsub(";", ""), ns.ObservationCount())
  broadcast(msg)
end

local function start()
  if not registered and C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    registered = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  end
  if not enabled() then return end
  -- spät beitreten, damit Allgemein, Handel und Co. ihre gewohnten Nummern behalten
  ns.After(15, function() ns.SafeCall("share", join) end)
  ns.After(25, function() ns.SafeCall("share", hello) end)
end

ns.On("PLAYER_LOGIN", function()
  ns.SafeCall("share", claimOwn)
  ns.SafeCall("share", markLegacy)
  ns.SafeCall("share", start)
end)

-- Fremde Bestände: Zähmungen, Sichtungen und Zellen anderer Spieler, mit der Zahl der Melder
-- (ältere Zellen ohne Melder zählen bei den Meldern nicht mit)
local function foreignStock()
  local tames, sights, reps = 0, 0, {}
  for _, s in ipairs((ns.db and ns.db.obs) or {}) do
    local o = ns.ParseObservation(s)
    if o and not o.own then tames = tames + 1; reps[o.rep] = true end
  end
  for _, s in ipairs((ns.db and ns.db.sights) or {}) do
    local o = ns.ParseSighting(s)
    if o and not o.own then sights = sights + 1; reps[o.rep] = true end
  end
  local cells = ns.ForeignCellCount and ns.ForeignCellCount() or 0
  for _, maps in pairs((ns.db and ns.db.locIn) or {}) do
    for _, byRep in pairs(maps) do
      for rep in pairs(type(byRep) == "table" and byRep or {}) do
        if #rep == 8 then reps[rep] = true end
      end
    end
  end
  local n = 0
  for _ in pairs(reps) do n = n + 1 end
  return tames, sights, cells, n
end

local NAMES = { O1 = "Zähmungen", S1 = "Sichtungen", F1 = "Zellen-Bündel", H1 = "Grüße" }
local function perKind(t)
  local parts = {}
  for _, k in ipairs(KINDS) do parts[#parts + 1] = NAMES[k] .. " " .. (t[k] or 0) end
  return table.concat(parts, " · ")
end

-- /fhp teilen: kurzer Stand im Chat (Entwicklerwerkzeug, nur deutsch)
function ns.ShareStatus()
  local own = 0
  for _, s in ipairs((ns.db and ns.db.obs) or {}) do
    local o = ns.ParseObservation(s)
    if o and o.own then own = own + 1 end
  end
  local _, rep = me()
  ns.Print(("Teilen %s · eigene Beobachtungen %d · Kanal %s · Warteschlange %d · dein Kürzel %s")
    :format(enabled() and "an" or "aus", own, channelIndex() and ("Nr. " .. channelIndex()) or "nicht beigetreten",
      #queue, rep or "?"))
  local tames, sights, cells, nReps = foreignStock()
  ns.Print(("Fremd gespeichert: Zähmungen %d · Sichtungen %d · Fundort-Zellen %d · von %d Meldern")
    :format(tames, sights, cells, nReps))
  local via = 0
  for _ in pairs(type(ns.db and ns.db.via) == "table" and ns.db.via or {}) do via = via + 1 end
  ns.Print(("Herkunft bekannt für %d fremde Melder"):format(via))
  ns.Print("Diese Sitzung gesendet: " .. perKind(stats.sent))
  ns.Print("Empfangen: " .. perKind(stats.recv))
  ns.Print("Davon neu gespeichert: " .. perKind(stats.new))
  local why = {}
  for k, n in pairs(stats.dropped) do why[#why + 1] = k .. " " .. n end
  table.sort(why)
  if #why > 0 then ns.Print("Verworfen: " .. table.concat(why, " · ")) end
  ns.Print(("Antworten auf Grüße diese Sitzung: %d, ausgelassen: %d"):format(stats.replied, stats.skipped))
  local rejects = ns.db and ns.db.shareRejects
  if rejects and #rejects > 0 then
    local total = 0
    for _, e in ipairs(rejects) do total = total + (type(e) == "table" and tonumber(e.n) or 1) end
    ns.Print(("Verworfene Nachrichten roh aufgehoben: %d verschiedene, %d Empfänge (ForeverHunterPetsDB.shareRejects)")
      :format(#rejects, total))
  end
  if stats.last then
    local ago = (time and time() or 0) - stats.last.at
    ns.Print(("Zuletzt empfangen: %s über %s, vor %d s"):format(NAMES[stats.last.t] or stats.last.t, stats.last.way, ago))
  else
    ns.Print("Noch nichts von anderen Spielern empfangen.")
  end
end

-- Einstellung umgeschaltet
function ns.ShareChanged()
  if enabled() then
    start()
  else
    queue = {}
    leave()
  end
end
