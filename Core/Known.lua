-- Forever Hunter Pets · Lernstand: welche Ränge schon gelernt sind. Gespeichert je Charakter unter
-- der Zauber-ID des Rangs. Ränge gelten einzeln: Rang 3 schließt Rang 2 nicht ein.
--
-- Zwei Quellen, der Wert merkt sich die Herkunft:
--   "t"  stand im Fenster „Wildtierausbildung“ oder kam mit der Meldung „Ihr habt einen neuen
--        Zauber erlernt“ – das kennt der Jäger und kann es lehren
--   "m"  von Hand abgehakt
-- Automatisch kommt nur dazu, entfernt wird nichts: das Ausbildungsfenster zeigt immer nur, was
-- die Familie des gerade aktiven Pets lernen kann.
--
-- Was das aktive Pet kann, ist keine Quelle: Ein frisch gezähmtes Tier bringt seinen Rang mit, der
-- Jäger lernt ihn aber erst, wenn es ihn im Kampf oft genug eingesetzt hat. Bis Version 0.2.0 trug
-- das Addon solche Ränge als "p" ein – zu früh: wer sich darauf verließ, ließ das Tier zu früh frei.
local _, ns = ...
local L = ns.L
local D = ns.Data

local listeners = {}
function ns.OnKnownChanged(fn) listeners[#listeners + 1] = fn end
local function changed()
  for _, fn in ipairs(listeners) do ns.SafeCall("known", fn) end
end

function ns.IsKnown(r)
  return ns.char ~= nil and ns.char.known[r.id] ~= nil
end

-- Haken von Hand setzen oder entfernen
function ns.SetKnown(r, on)
  if on then ns.char.known[r.id] = ns.char.known[r.id] or "m" else ns.char.known[r.id] = nil end
  changed()
end

function ns.KnownCount()
  local n = 0
  for _ in pairs(ns.char.known) do n = n + 1 end
  return n
end

-- Nimmt erkannte Ränge auf und meldet die neuen im Chat. found = { { a = , r = }, … }
local RANKING = { m = 1, t = 2 }
local function absorb(found, source)
  local known, fresh = ns.char.known, {}
  for _, f in ipairs(found) do
    local old = known[f.r.id]
    if not old then
      local rank = ns.RankLabel(f.a, f.r)
      fresh[#fresh + 1] = ns.AbilityName(f.a) .. (rank ~= "" and (" (" .. rank .. ")") or "")
    end
    if not old or RANKING[source] > (RANKING[old] or 0) then known[f.r.id] = source end
  end
  if #fresh > 0 then
    table.sort(fresh)
    ns.Print((#fresh == 1 and L["1 rank added to your learned list: %s"] or L["%d ranks added to your learned list: %s"])
      :format(#fresh == 1 and table.concat(fresh) or #fresh, table.concat(fresh, ", ")))
    changed()
  end
end

-- ---- Das aktive Pet: nur zur Anzeige, nie als Lernstand ----
-- IsSpellKnown(id, true) sagt je Rang, ob das Pet ihn gerade beherrscht.
function ns.PetKnows(r)
  if not (IsSpellKnown and UnitExists) then return false end
  local ok, exists = pcall(UnitExists, "pet")
  if not (ok and ns.clean(exists)) then return false end
  local ok2, has = pcall(IsSpellKnown, r.id, true)
  return ok2 and ns.clean(has) and true or false
end

-- Alte "p"-Einträge (bis 0.2.0) sind von echten nicht zu unterscheiden und fliegen raus; was der
-- Jäger wirklich kennt, steht beim nächsten Öffnen der Wildtierausbildung wieder da.
ns.On("PLAYER_LOGIN", function()
  if not ns.char then return end
  for id, source in pairs(ns.char.known) do
    if source == "p" then ns.char.known[id] = nil end
  end
end)

-- Der höchste Rang je Fähigkeit, den das aktive Pet beherrscht: { [Fähigkeit] = Rang }, nil ohne Pet.
-- IsSpellKnown meldet nur den aktiven Rang; wie im Spielfenster gelten die niedrigeren damit als erlernt.
function ns.PetRanks()
  if not (IsSpellKnown and UnitExists) then return nil end
  local ok, exists = pcall(UnitExists, "pet")
  if not (ok and ns.clean(exists)) then return nil end
  local ranks = {}
  for _, a in ipairs(D.abilities) do
    if ns.Learnable(a) then
      for _, r in ipairs(a.ranks) do
        local ok2, has = pcall(IsSpellKnown, r.id, true)
        if ok2 and ns.clean(has) and r.rank > (ranks[a] or 0) then ranks[a] = r.rank end
      end
    end
  end
  return ranks
end

-- ---- Quelle 1: das Fenster „Wildtierausbildung“ ----
-- Forever zeigt es als Trainer-Fenster ohne NPC. Jede Zeile nennt Name, Status, Icon, Pet-Stufe und
-- Rang („Beißen | used | 132278 | 16 | Rang 3“), aber keine Zauber-ID – zugeordnet wird über den Namen.
-- Rang zu einer Zauber-ID (nur, was man lernen kann)
local byId, byName
ns.OnAbilitiesChanged(function() byId, byName = nil, nil end)
local function rankById(id)
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

local function abilityByName(name)
  if not byName then
    byName = {}
    for _, a in ipairs(D.abilities) do
      if ns.Learnable(a) then
        -- Namen in den Daten nur, soweit erhoben: aus einem deutschen Client gibt es keinen englischen
        for _, name in ipairs({ a.de or false, a.en or false, ns.AbilityName(a) }) do
          if name then byName[name] = a end
        end
      end
    end
  end
  return byName[name]
end

local function isHunter()
  if not UnitClass then return true end
  local ok, _, class = pcall(UnitClass, "player")
  return not ok or ns.clean(class) == "HUNTER"
end

local function trainerOpen()
  if not (GetNumTrainerServices and GetTrainerServiceInfo and isHunter()) then return false end
  return not (IsTradeskillTrainer and ns.clean(IsTradeskillTrainer()))
end

-- Steht ein NPC dahinter, ist es der Tierausbilder in der Stadt, sonst die eigene Wildtierausbildung
local function atNpc()
  local ok, npc = pcall(UnitExists, "npc")
  return ok and ns.clean(npc) and true or false
end

-- Auch der Jägerlehrer ist ein Trainer mit NPC (#16). Tierausbilder ist eine Liste nur, wenn eine Zeile einen
-- Rang trägt, den die mitgelieferten Daten vom Tierausbilder kennen – unabhängig von Sprache und NPC.
-- Gemerkt je Zeilenzahl: TRAINER_UPDATE kommt oft, die Tooltip-Abfragen nur, wenn sich die Liste ändert.
local petTrainer = { n = -1 }
local function isPetTrainer()
  local ok, n = pcall(GetNumTrainerServices)
  n = ok and tonumber(ns.clean(n)) or 0
  if n ~= petTrainer.n then
    petTrainer.n, petTrainer.yes = n, false
    for i = 1, math.min(n, 200) do
      local id = ns.TrainerServiceId and ns.TrainerServiceId(i)
      if id and ns.IsDataTrainerRank(id) then petTrainer.yes = true; break end
    end
  end
  return petTrainer.yes
end

-- Rang einer Zeile über Name und Rangtext; kurz nach dem Öffnen fehlt der Rangtext noch, dann entscheidet
-- die Pet-Stufe des Rangs. Nur noch Rückfall, wenn der Tooltip keine Zauber-ID nennt.
local function rankByText(name, level, rankText)
  local a = type(name) == "string" and abilityByName(name)
  if not a then return nil end
  local rank = type(rankText) == "string" and tonumber(rankText:match("%d+"))
  for _, r in ipairs(a.ranks) do
    if (rank and r.rank == rank) or (not rank and level and r.level == level) then return { a = a, r = r } end
  end
  return nil
end

-- Rang der Zeile i: über die Zauber-ID aus dem Tooltip der Zeile – eindeutig, unabhängig von Name, Rangtext
-- und Sprache (16.10.2026). ids sind die IDs, die die Erhebung beim selben Lesen schon erfragt hat.
local function rankOfRow(i, ids, name, level, rankText)
  local id = (ids and ids[i]) or (ns.TrainerServiceId and ns.TrainerServiceId(i))
  return (id and rankById(id)) or rankByText(name, level, rankText)
end

-- Wildtierausbildung: jede Zeile ist ein Rang, den der Jäger kennt, gleich mit welchem Status.
-- Die Liste des Tierausbilders in der Stadt ist dagegen sein Angebot und bleibt außen vor; was man
-- dort lernt, meldet die Systemnachricht (siehe unten).
local function readTrainer()
  if not trainerOpen() then return end
  -- Erhebung (Core/Survey.lua) liest beide Listen, der Lernstand nur die Wildtierausbildung
  local npc = atNpc()
  ns.trainerIds = nil
  if npc and not isPetTrainer() then return end   -- Jägerlehrer: nichts erheben
  if ns.SurveyTrainer then ns.SafeCall("survey", ns.SurveyTrainer, npc) end
  if npc then return end
  local ids = ns.trainerIds
  local ok, n = pcall(GetNumTrainerServices)
  n = ok and tonumber(ns.clean(n)) or 0
  local found = {}
  for i = 1, n do
    local ok2, name, status, _, level, rankText = pcall(GetTrainerServiceInfo, i)
    name, status, level, rankText = ns.clean(name), ns.clean(status), ns.clean(level), ns.clean(rankText)
    if ok2 and (status == "available" or status == "unavailable" or status == "used") then
      local hit = rankOfRow(i, ids, name, level, rankText)
      if hit then found[#found + 1] = hit end
    end
  end
  absorb(found, "t")
end

-- Ist die eigene Wildtierausbildung gerade offen?
function ns.BeastTrainingOpen()
  if not trainerOpen() or atNpc() then return false end
  local ok, n = pcall(GetNumTrainerServices)
  return ok and (tonumber(ns.clean(n)) or 0) > 0
end

-- Zeile eines Rangs in der offenen Wildtierausbildung: Index und Status, oder nil
function ns.TrainerIndex(a, r)
  if not trainerOpen() or atNpc() then return nil end
  local ok, n = pcall(GetNumTrainerServices)
  n = ok and tonumber(ns.clean(n)) or 0
  for i = 1, n do
    local ok2, name, status, _, level, rankText = pcall(GetTrainerServiceInfo, i)
    name, status, level, rankText = ns.clean(name), ns.clean(status), ns.clean(level), ns.clean(rankText)
    local hit = ok2 and rankOfRow(i, nil, name, level, rankText)
    if hit and hit.r == r then return i, status end
  end
  return nil
end

-- Der Filter „Bereits bekannt“ ist im Spiel standardmäßig aus, dann fehlen diese Zeilen in der Liste.
-- Für einen Augenblick einschalten, lesen, wieder zurückstellen.
local busy = false
local function readTrainerAll()
  if busy or not trainerOpen() then return end
  if InCombatLockdown and InCombatLockdown() then return end
  -- Tierausbilder: nur für die Erhebung, so gelesen, wie seine Filter stehen
  if atNpc() then
    readTrainer()
    return
  end
  local usedShown = true
  if GetTrainerServiceTypeFilter then
    local ok, v = pcall(GetTrainerServiceTypeFilter, "used")
    usedShown = not ok or ns.clean(v) ~= false
  end
  if usedShown or not SetTrainerServiceTypeFilter then
    readTrainer()
    return
  end
  busy = true
  pcall(SetTrainerServiceTypeFilter, "used", true)
  ns.After(0.3, function()
    ns.SafeCall("trainer", readTrainer)
    pcall(SetTrainerServiceTypeFilter, "used", false)
    busy = false
  end)
end

function ns.After(delay, fn)
  if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

-- Direkt bei TRAINER_SHOW ist die Liste noch unvollständig, deshalb mit etwas Abstand lesen
-- ---- Gewählten Rang nach dem Öffnen der Wildtierausbildung anmelden ----
-- Lehren darf nur das Blizzard-Fenster selbst: BuyTrainerService ist für Addons gesperrt
-- (ADDON_ACTION_FORBIDDEN, im Spiel geprüft am 12.10.2026). Der Knopf „Wildtierausbildung öffnen“
-- merkt sich die gewählte Zeile, und nach dem Öffnen meldet das Addon sie über die API an.
-- Das Fenster zeigt diese Auswahl derzeit nicht an: Es führt seine Markierung in einem eigenen Feld
-- (ClassTrainerFrame.selectedService). Dieses Feld darf das Addon nicht setzen – dann gilt das
-- Fenster als „verunreinigt“ und sein eigener Knopf „Ausbilden“ wird gesperrt (ebenfalls geprüft).
-- Der API-Aufruf schadet nicht und greift, sobald das Fenster die Auswahl von dort liest.
local pendingSelect
local function clock() return GetTime and GetTime() or 0 end

function ns.NoteTrainerSelection(e)
  pendingSelect = (e and e.state == "ok") and { a = e.a, r = e.r, at = clock() } or nil
end

local function applySelection()
  local p = pendingSelect
  pendingSelect = nil
  if not p or clock() - p.at > 5 or not ns.BeastTrainingOpen() or not SelectTrainerService then return end
  local index = ns.TrainerIndex(p.a, p.r)
  if index then pcall(SelectTrainerService, index) end
end

ns.On("TRAINER_SHOW", function()
  petTrainer.n = -1   -- ein anderer Trainer, neu prüfen
  ns.After(0.4, function() ns.SafeCall("trainer", readTrainerAll) end)
  -- erst nach dem Lesen: das schaltet kurz den Filter um und verschiebt dabei die Zeilen
  ns.After(1.0, function() ns.SafeCall("select", applySelection) end)
end)

ns.On("TRAINER_UPDATE", function()
  if not busy then readTrainer() end
end)

-- ---- Quelle 2: die Systemnachricht „Ihr habt einen neuen Zauber erlernt: [Große Ausdauer].“ ----
-- Sie kommt beim Lernen selbst und trägt den Zauber als Link. Passt dessen ID zu einem Rang der
-- Daten, ist er eindeutig; sonst entscheidet der Name im Link (siehe ranksFromPet).
-- Passt die Nachricht auf einen der „erlernt“-Texte des Clients? Verglichen wird, was im Text
-- vor und nach dem Platzhalter %s steht. Kennt der Client die Texte nicht, zählt jede Nachricht.
local LEARN_TEXTS = { "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S" }
local function isLearnMessage(msg)
  local any = false
  for _, key in ipairs(LEARN_TEXTS) do
    local text = _G[key]
    if type(text) == "string" then
      any = true
      local before, after = text:match("^(.-)%%s(.*)$")
      if before and msg:sub(1, #before) == before and (after == "" or msg:sub(-#after) == after) then return true end
    end
  end
  return not any
end

-- Protokoll der letzten Lernmeldungen in den gespeicherten Daten (ForeverHunterPetsDB.learnLog):
-- was ankam und was daraus wurde. So lässt sich nachlesen, warum ein Rang nicht abgehakt wurde.
local function logLearn(how, text, result)
  if not ns.db then return end
  local log = ns.db.learnLog or {}
  ns.db.learnLog = log
  local combat = InCombatLockdown and InCombatLockdown() and " Kampf" or ""
  log[#log + 1] = ("%s %s%s | %s | %s"):format(date and date("%d.%m. %H:%M:%S") or "?", how, combat,
    tostring(text):gsub("|", "/"), result)
  while #log > 20 do table.remove(log, 1) end
end

-- Die ID im Link ist nicht die des Rangs aus den Daten: Der Jäger lernt einen eigenen Zauber
-- (im Spiel gesehen am 14.10.2026: Link 26185, Sturmangriff Rang 3 des Pets ist 26178). Es bleibt
-- der Name im Link, „[Sturmangriff]“ ohne Rang. Gemeint ist der Rang, den das aktive Pet schon
-- kann und der Jäger noch nicht – genau der Fall, in dem man einem gezähmten Tier etwas abschaut.
-- Kann das Pet keinen offenen Rang (etwa beim Tierausbilder in der Stadt), bleibt die Meldung ohne
-- Folge; den Rang bringt dann das nächste Öffnen der Wildtierausbildung.
local function ranksFromPet(a)
  local found = {}
  for _, r in ipairs(a.ranks) do
    if not ns.IsKnown(r) and ns.PetKnows(r) then found[#found + 1] = { a = a, r = r } end
  end
  return found
end

ns.On("CHAT_MSG_SYSTEM", function(raw)
  if not ns.char or not isHunter() then return end
  local msg = ns.clean(raw)
  if type(msg) ~= "string" then
    -- geheimer Wert (Kampf, Instanz): nicht lesbar. Nur zählen, das Protokoll bliebe sonst nicht lange
    if ns.db then ns.db.learnUnreadable = (ns.db.learnUnreadable or 0) + 1 end
    return
  end
  if not msg:find("|Hspell:", 1, true) or not isLearnMessage(msg) then return end
  local found, how = {}, "Name"
  for id, name in msg:gmatch("|Hspell:(%d+)[^|]*|h%[(.-)%]|h") do
    local a = abilityByName(name)
    local hit = rankById(tonumber(id))
    -- die ID zählt nur, wenn sie zur genannten Fähigkeit gehört: die Zauber des Jägers haben eigene
    -- IDs, und eine davon könnte zufällig die eines anderen Rangs in den Daten sein
    if hit and hit.a == a then
      found[#found + 1], how = hit, "ID"
    elseif a then
      for _, f in ipairs(ranksFromPet(a)) do found[#found + 1] = f end
    end
  end
  logLearn("Chat", msg, #found > 0 and ("erkannt über " .. how .. ": " .. found[1].r.id) or "kein Rang erkannt")
  if #found > 0 then absorb(found, "t") end
end)

-- Pet gerufen, gewechselt oder etwas dazugelernt: die Ansichten zeigen, was das Pet kann, und zeichnen
-- neu. Mehrere Ereignisse in Folge ergeben einen Durchlauf.
local pending = false
local function redrawSoon()
  if pending or not isHunter() then return end
  pending = true
  ns.After(1, function()
    pending = false
    changed()
  end)
end
ns.On("UNIT_PET", function(unit) if ns.clean(unit) == "player" then redrawSoon() end end)
ns.On("SPELLS_CHANGED", redrawSoon)
ns.On("PLAYER_ENTERING_WORLD", redrawSoon)
