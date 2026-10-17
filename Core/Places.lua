-- Forever Hunter Pets · Fundorte: wo ein Tier stand, als Zellen eines Rasters (Umbau eigene Daten, Inkrement 5).
-- Der Client nennt nur die Position des Spielers, nicht die des Tiers. Deshalb zählt sie nur, wenn das Tier
-- in etwa 10 m steht (CheckInteractDistance 3, sonst 2; im Spiel geprüft am 16.10.2026), und wird auf ein
-- Raster von 2 % der Karte gerundet (50 × 50 Zellen, je nach Zone etwa 60–100 m). Die Karte zeigt so
-- „hier ungefähr“; wandernde Tiere ergeben eine Kette von Zellen.
--
-- Ablage kontoweit: ForeverHunterPetsDB.loc[npc][uiMapID] = „xyxy…“ für eigene, locIn ebenso für fremde
-- Zellen; je Zelle zwei Zeichen aus ALPHA (Spalte, Zeile). Nur neue Zellen zählen, höchstens MAX_CELLS je
-- Tier und Karte. Neue eigene Zellen werden gesammelt und höchstens alle 5 Minuten geteilt (Core/Comm.lua).
local _, ns = ...

local GRID = 50
local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"   -- 50 Zeichen
local MAX_CELLS = 500
local MAX_FOREIGN = 20000
local SEND_EVERY = 300
ns.CELL_BUNDLE = 100        -- Zellen je Nachricht (200 Zeichen)

local function store(foreign)
  if not ns.db then return nil end
  local key = foreign and "locIn" or "loc"
  ns.db[key] = ns.db[key] or {}
  return ns.db[key]
end

local function hasCell(cells, cell)
  for i = 1, #cells - 1, 2 do
    if cells:sub(i, i + 1) == cell then return true end
  end
  return false
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
    for _, cells in pairs(maps) do foreignCount = foreignCount + #cells / 2 end
  end
  return foreignCount
end

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
-- geteilt aber nur, was die Daten nicht haben. Fremde Zellen, die die Daten haben, werden nicht gespeichert.
function ns.AddCells(npc, map, cells, foreign)
  local s = store(foreign)
  if not (s and npc and map and ns.ValidCells(cells)) then return 0 end
  s[npc] = s[npc] or {}
  local have = s[npc][map] or ""
  local mine = (not foreign and "") or ((store(false)[npc] or {})[map] or "")
  local added, toShare = "", ""
  for i = 1, #cells - 1, 2 do
    local cell = cells:sub(i, i + 1)
    if #have / 2 >= MAX_CELLS then break end
    if foreign and countForeign() >= MAX_FOREIGN then break end
    if not hasCell(have, cell) and not hasCell(mine, cell) and not (foreign and inData(npc, map, cell)) then
      have = have .. cell
      added = added .. cell
      if foreign then foreignCount = countForeign() + 1 elseif not inData(npc, map, cell) then toShare = toShare .. cell end
    end
  end
  if added == "" then return 0 end
  s[npc][map] = have
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
-- ownOnly: nur eigene Zellen (Entdeckermodus)
function ns.CellPoints(npc, map, ownOnly)
  local pts = {}
  local function add(cells)
    for i = 1, #(cells or "") - 1, 2 do
      local cx = ALPHA:find(cells:sub(i, i), 1, true) - 1
      local cy = ALPHA:find(cells:sub(i + 1, i + 1), 1, true) - 1
      pts[#pts + 1] = { (cx + 0.5) * 100 / GRID, (cy + 0.5) * 100 / GRID }
    end
  end
  add(((store(false) or {})[npc] or {})[map])
  if not ownOnly then add(((store(true) or {})[npc] or {})[map]) end
  return pts
end

-- Karten, auf denen Zellen eines Tiers liegen: { [uiMapID] = Zahl }
function ns.CellMaps(npc, ownOnly)
  local out = {}
  for _, foreign in ipairs(ownOnly and { false } or { false, true }) do
    for map, cells in pairs(((store(foreign) or {})[npc]) or {}) do out[map] = (out[map] or 0) + #cells / 2 end
  end
  return out
end
