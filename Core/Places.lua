-- Forever Hunter Pets · Fundorte: wo ein Tier stand, als Zellen eines Rasters (Umbau eigene Daten, Inkrement 5).
-- Der Client nennt nur die Position des Spielers, nicht die des Tiers. Deshalb zählt sie nur, wenn das Tier
-- in etwa 10 m steht (CheckInteractDistance 3, sonst 2; im Spiel geprüft am 16.10.2026), und wird auf ein
-- Raster von 2 % der Karte gerundet (50 × 50 Zellen, je nach Zone etwa 60–100 m). Die Karte zeigt so
-- „hier ungefähr“; wandernde Tiere ergeben eine Kette von Zellen.
--
-- Ablage kontoweit: ForeverHunterPetsDB.loc[npc][uiMapID] = „xyxy…“ für eigene Zellen, je Zelle zwei Zeichen
-- aus ALPHA (Spalte, Zeile). Fremde tragen ihren Melder, damit der Import die Regel „ab 3 Meldern“ prüfen
-- kann (#2): locIn[npc][uiMapID][melder] = „xyxy…“; ältere Einträge ohne Melder (bis 0.8.0 ein String je
-- Karte) liegen unter OLD – sichtbar, sie zählen aber nicht. Nur neue Zellen zählen, höchstens MAX_CELLS je
-- Tier, Karte und Melder. Neue eigene Zellen werden gesammelt und höchstens alle 5 Minuten geteilt (Core/Comm.lua).
-- Eigene Zellen stehen zusätzlich je Charakter in ForeverHunterPetsCharDB.loc, gleiches Format (#43): Im
-- Entdeckermodus zählen sie (ns.Finds, Core/Discover.lua), geteilt wird nur aus dem Konto.
local _, ns = ...

local GRID = 50
local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"   -- 50 Zeichen
local MAX_CELLS = 500
local MAX_FOREIGN = 20000
local SEND_EVERY = 300
local OLD = "-"             -- Melder älterer fremder Zellen (unbekannt)
local FOREIGN_ENOUGH = 3    -- mehr Melder je Zelle braucht die Regel „ab 3 Meldern“ (Core/Observe.lua) nicht
ns.CELL_BUNDLE = 100        -- Zellen je Nachricht (200 Zeichen)

local migrated = false
local function store(foreign)
  if not ns.db then return nil end
  local key = foreign and "locIn" or "loc"
  ns.db[key] = ns.db[key] or {}
  if foreign and not migrated then
    migrated = true
    for _, maps in pairs(ns.db.locIn) do
      for map, v in pairs(maps) do
        if type(v) == "string" then maps[map] = v ~= "" and { [OLD] = v } or nil end
      end
    end
  end
  return ns.db[key]
end

local function hasCell(cells, cell)
  for i = 1, #cells - 1, 2 do
    if cells:sub(i, i + 1) == cell then return true end
  end
  return false
end

-- Wie viele Melder (ohne OLD) haben die Zelle gemeldet? byRep = locIn[npc][uiMapID]
local function reporters(byRep, cell)
  local n = 0
  for rep, cells in pairs(byRep or {}) do
    if rep ~= OLD and hasCell(cells, cell) then n = n + 1 end
  end
  return n
end

-- Fremde Zellen eines Tiers auf einer Karte, alle Melder zusammen, jede einmal: „xyxy…“
local function foreignCells(npc, map)
  local all, set = {}, {}
  for _, cells in pairs(((store(true) or {})[npc] or {})[map] or {}) do
    for i = 1, #cells - 1, 2 do
      local cell = cells:sub(i, i + 1)
      if not set[cell] then set[cell] = true; all[#all + 1] = cell end
    end
  end
  return table.concat(all)
end

function ns.ValidCells(cells)
  if type(cells) ~= "string" or #cells == 0 or #cells % 2 == 1 then return false end
  for i = 1, #cells do
    if not ALPHA:find(cells:sub(i, i), 1, true) then return false end
  end
  return true
end

-- ---- Wo steht der Spieler? uiMapID und Zelle, sonst nil ----
function ns.CellHere()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
  map = ok and tonumber(ns.clean(map))
  if not map then return nil end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  pos = ok2 and ns.clean(pos)
  if not pos then return nil end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  x, y = tonumber(ns.clean(x)), tonumber(ns.clean(y))
  if not (x and y) or (x == 0 and y == 0) or x < 0 or y < 0 or x > 1 or y > 1 then return nil end
  local cx = math.min(GRID - 1, math.floor(x * GRID))
  local cy = math.min(GRID - 1, math.floor(y * GRID))
  return map, ALPHA:sub(cx + 1, cx + 1) .. ALPHA:sub(cy + 1, cy + 1)
end

-- Sieht der Spieler gerade von woanders aus („Augen des Wildtiers“ 1002 oder „Adlerauge“ 6197, beides
-- Kanalzauber)? Dann ist seine Position nicht die des Gesehenen: keine Zellen. Die Spur-Probe (16.10.2026)
-- zeigte beide IDs; CheckInteractDistance misst dabei vom Jäger aus, das hier ist die zweite Sicherung.
local REMOTE_VIEW = { [1002] = true, [6197] = true }
function ns.Possessing()
  if not UnitChannelInfo then return false end
  local ok, name, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
  if not ok then return false end
  return ns.clean(name) ~= nil and REMOTE_VIEW[ns.clean(spellID)] == true
end

-- Steht die Einheit in etwa 10 m? true/false, nil wenn der Client es nicht sagt
function ns.UnitClose(unit)
  if not CheckInteractDistance then return nil end
  for _, index in ipairs({ 3, 2 }) do
    local ok, v = pcall(CheckInteractDistance, unit, index)
    v = ok and ns.clean(v)
    if v ~= nil then return v and true or false end
  end
  return nil
end

-- ---- Zellen aufnehmen ----
local foreignCount
local function countForeign()
  if foreignCount then return foreignCount end
  foreignCount = 0
  for _, maps in pairs(store(true) or {}) do
    for _, byRep in pairs(maps) do
      for _, cells in pairs(byRep) do foreignCount = foreignCount + #cells / 2 end
    end
  end
  return foreignCount
end

-- Fremde Zellen insgesamt (für /fhp teilen)
function ns.ForeignCellCount() return countForeign() end

local pending, flushing = {}, false   -- neue eigene Zellen bis zum nächsten Teilen: ["npc:map"] = Zellen
local function flush()
  flushing = false
  local list = pending
  pending = {}
  for key, cells in pairs(list) do
    local npc, map = key:match("^(%d+):(%d+)$")
    for i = 1, #cells, ns.CELL_BUNDLE * 2 do
      if ns.ShareCells then ns.SafeCall("share", ns.ShareCells, npc, map, cells:sub(i, i + ns.CELL_BUNDLE * 2 - 1)) end
    end
  end
end

local listeners = {}
function ns.OnCellsChanged(fn) listeners[#listeners + 1] = fn end
local function changed()
  for _, fn in ipairs(listeners) do ns.SafeCall("cells", fn) end
end

-- Nimmt Zellen auf; liefert die Zahl der neuen. Eigene werden zum Teilen vorgemerkt.
-- Zellen, die die mitgelieferten Daten schon haben (Punkte auf das Raster gerundet), einmal je Tier und Karte
local dataCells = {}
local function inData(npc, map, cell)
  local key = npc .. ":" .. map
  local set = dataCells[key]
  if not set then
    set = {}
    local packed = ns.Data.coords[npc] and ns.Data.coords[npc][map]
    for i = 1, #(packed or "") - 5, 6 do
      local cx = math.min(GRID - 1, math.floor(tonumber(packed:sub(i, i + 2)) * GRID / 1000))
      local cy = math.min(GRID - 1, math.floor(tonumber(packed:sub(i + 3, i + 5)) * GRID / 1000))
      set[ALPHA:sub(cx + 1, cx + 1) .. ALPHA:sub(cy + 1, cy + 1)] = true
    end
    dataCells[key] = set
  end
  return set[cell] or false
end

-- Eigene Zellen werden immer gespeichert – auch was die Daten schon kennen, gehört zu den eigenen Funden –,
-- geteilt aber nur, was die Daten nicht haben. Fremde Zellen werden nicht gespeichert, wenn die Daten oder die
-- eigenen Zellen sie haben oder schon FOREIGN_ENOUGH andere Melder sie gemeldet haben.
-- Eigene Zellen auch je Charakter; true, wenn eine neu war
local function addOwnChar(npc, map, cells)
  if not ns.char then return false end
  ns.char.loc = ns.char.loc or {}
  ns.char.loc[npc] = ns.char.loc[npc] or {}
  local have = ns.char.loc[npc][map] or ""
  local before = #have
  for i = 1, #cells - 1, 2 do
    local cell = cells:sub(i, i + 1)
    if #have / 2 >= MAX_CELLS then break end
    if not hasCell(have, cell) then have = have .. cell end
  end
  if #have == before then return false end
  ns.char.loc[npc][map] = have
  return true
end

-- foreign: Kürzel des Melders bei fremden Zellen, sonst nil.
function ns.AddCells(npc, map, cells, foreign)
  local s = store(foreign)
  if not (s and npc and map and ns.ValidCells(cells)) then return 0 end
  local charNew = not foreign and addOwnChar(npc, map, cells)
  s[npc] = s[npc] or {}
  local byRep = foreign and (s[npc][map] or {})
  local have = (foreign and byRep[foreign]) or (not foreign and s[npc][map]) or ""
  local mine = (not foreign and "") or ((store(false)[npc] or {})[map] or "")
  local added, toShare = "", ""
  for i = 1, #cells - 1, 2 do
    local cell = cells:sub(i, i + 1)
    if #have / 2 >= MAX_CELLS then break end
    if foreign and countForeign() >= MAX_FOREIGN then break end
    if not hasCell(have, cell) and not hasCell(mine, cell)
        and not (foreign and (inData(npc, map, cell) or reporters(byRep, cell) >= FOREIGN_ENOUGH)) then
      have = have .. cell
      added = added .. cell
      if foreign then foreignCount = countForeign() + 1 elseif not inData(npc, map, cell) then toShare = toShare .. cell end
    end
  end
  if added == "" then
    if charNew then changed() end
    return 0
  end
  if foreign then
    byRep[foreign] = have
    s[npc][map] = byRep
  else
    s[npc][map] = have
  end
  if toShare ~= "" then
    local key = npc .. ":" .. map
    pending[key] = (pending[key] or "") .. toShare
    if not flushing then
      flushing = true
      ns.After(SEND_EVERY, function() ns.SafeCall("share", flush) end)
    end
  end
  changed()
  return #added / 2
end

-- Bis zu n eigene Bündel { npc, map, cells } für die Antwort auf einen Gruß
function ns.OwnCellBundles(n)
  local out = {}
  for npc, maps in pairs(store(false) or {}) do
    for map, all in pairs(maps) do
      -- was die Daten schon haben, braucht niemand
      local cells = ""
      for i = 1, #all - 1, 2 do
        local cell = all:sub(i, i + 1)
        if not inData(npc, map, cell) then cells = cells .. cell end
      end
      for i = 1, #cells, ns.CELL_BUNDLE * 2 do
        if #out >= n then return out end
        out[#out + 1] = { npc = npc, map = map, cells = cells:sub(i, i + ns.CELL_BUNDLE * 2 - 1) }
      end
    end
  end
  return out
end

-- ---- Für die Anzeige ----
-- Mittelpunkte der Zellen eines Tiers auf einer Karte, in Prozent: { {x, y}, … }
-- ownOnly: nur eigene Zellen (Entdeckermodus), und zwar die, die nach ns.Finds zählen
local function ownStore(ownOnly)
  if ownOnly and ns.Finds then return (ns.Finds() or {}).loc end
  return store(false)
end

function ns.CellPoints(npc, map, ownOnly)
  local pts = {}
  local function add(cells)
    for i = 1, #(cells or "") - 1, 2 do
      local cx = ALPHA:find(cells:sub(i, i), 1, true) - 1
      local cy = ALPHA:find(cells:sub(i + 1, i + 1), 1, true) - 1
      pts[#pts + 1] = { (cx + 0.5) * 100 / GRID, (cy + 0.5) * 100 / GRID }
    end
  end
  add(((ownStore(ownOnly) or {})[npc] or {})[map])
  if not ownOnly then add(foreignCells(npc, map)) end
  return pts
end

-- Karten, auf denen Zellen eines Tiers liegen: { [uiMapID] = Zahl }
function ns.CellMaps(npc, ownOnly)
  local out = {}
  for map, cells in pairs(((ownStore(ownOnly) or {})[npc]) or {}) do out[map] = #cells / 2 end
  if not ownOnly then
    for map in pairs(((store(true) or {})[npc]) or {}) do out[map] = (out[map] or 0) + #foreignCells(npc, map) / 2 end
  end
  return out
end
