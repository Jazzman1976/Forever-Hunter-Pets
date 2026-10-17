-- Forever Hunter Pets · Karten: Zone → uiMapID und die Kartenkacheln des Clients
local _, ns = ...
local D = ns.Data

local function mapInfo(mapID)
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  info = ok and ns.clean(info)
  return type(info) == "table" and info or nil
end

-- uiMapID einer Zone. Seit dem Umbau auf eigene Daten sind die Zonen selbst uiMapIDs (auch die aus
-- gesammelten Fundort-Zellen); eine abweichende Zuordnung in den Daten geht vor. Zweiter Rückgabewert
-- („über den Namen gefunden“) ist immer false und bleibt für /fhp zonen.
function ns.MapForZone(zoneId)
  local z = D.zones[zoneId]
  if z and z.map then return z.map, false end
  return zoneId, false
end

-- Kartenbild einer uiMapID: { w, h, tw, th, cols, textures = { Datei-ID, … } } oder nil
local art = {}
function ns.MapArt(mapID)
  if not mapID then return nil end
  if art[mapID] == nil then
    art[mapID] = false
    if C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures then
      local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
      local layer = ok and type(layers) == "table" and layers[1]
      if layer and (layer.layerWidth or 0) > 0 and (layer.tileWidth or 0) > 0 then
        local ok2, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
        if ok2 and type(textures) == "table" and #textures > 0 then
          art[mapID] = {
            w = layer.layerWidth, h = layer.layerHeight, tw = layer.tileWidth, th = layer.tileHeight,
            cols = math.ceil(layer.layerWidth / layer.tileWidth), textures = textures,
          }
        end
      end
    end
  end
  return art[mapID] or nil
end

-- Die Bildstücke, die der Client über das Kartenbild legt, wo der Charakter die Zone erkundet hat:
-- { { textureWidth, textureHeight, offsetX, offsetY, fileDataIDs = { … }, … }, … } in Pixeln des
-- Kartenbilds. Nicht gemerkt, weil mit jedem Schritt Neues dazukommen kann. Unerkundetes gibt der
-- Client nicht her – die Karte bleibt dort so blass, wie man sie im Spiel kennt.
function ns.MapExplored(mapID)
  local E = C_MapExplorationInfo
  if not (mapID and E and E.GetExploredMapTextures) then return nil end
  local ok, list = pcall(E.GetExploredMapTextures, mapID)
  list = ok and ns.clean(list)
  return type(list) == "table" and list or nil
end

-- Höchstens max Punkte, gleichmäßig über die Liste verteilt (wie sample() auf der Seite)
function ns.Sample(pts, max)
  if #pts <= max then return pts end
  local out = {}
  for i = 0, max - 1 do out[#out + 1] = pts[math.floor(i * #pts / max) + 1] end
  return out
end

-- /fhp zonen: welche Zone hat welche Karte? Landet auch in ForeverHunterPetsDB.zoneReport.
function ns.ZoneReport()
  local ids = {}
  for id in pairs(D.zones) do ids[#ids + 1] = id end
  table.sort(ids)
  local report, missing, found = {}, {}, {}
  for _, id in ipairs(ids) do
    local mapID, viaName = ns.MapForZone(id)
    local info = mapID and mapInfo(mapID)
    local hasArt = ns.MapArt(mapID) ~= nil
    local line = ("%d %s -> %s %s%s%s"):format(id, ns.ZoneName(id), tostring(mapID), info and tostring(ns.clean(info.name)) or "-",
      viaName and mapID and " (über den Namen)" or "", (mapID and not hasArt) and " (ohne Kartenbild)" or "")
    report[#report + 1] = line
    if not (mapID and hasArt) then
      missing[#missing + 1] = ns.ZoneName(id) .. (D.zones[id].inst and "*" or "")
    elseif viaName then
      found[#found + 1] = ns.ZoneName(id) .. "=" .. mapID
    end
  end
  ns.db.zoneReport = report
  ns.Print(#ids .. " Zonen, " .. (#ids - #missing) .. " mit Karte.")
  if #found > 0 then ns.Print("Über den Namen gefunden: " .. table.concat(found, ", ")) end
  ns.Print("Ohne Karte (" .. #missing .. ", * = Instanz): " .. (#missing > 0 and table.concat(missing, ", ") or "keine"))
end
