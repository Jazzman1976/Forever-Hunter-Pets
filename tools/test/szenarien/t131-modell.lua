-- #131: Die Kartenseite zeigt nie das Modell des vorigen Tiers. Steht ein Tier noch nicht im Kreaturen-Cache,
-- lädt SetCreature nichts, und ein schon benutzter Rahmen zeigte weiter das alte Modell. Jedes Tier hat deshalb
-- seinen eigenen Rahmen: Bekannte Tiere stehen sofort da (ohne Icon), unbekannte zeigen das Familien-Icon,
-- bis der Client sie kennt, und Tiere mit gleichem Aussehen zeigen beide ihr Modell.
-- lädt: UI/Widgets.lua UI/MapCanvas.lua

-- Nachgebildetes PlayerModel mit dem Verhalten des Clients: unbekanntes Tier lädt nichts, das alte bleibt stehen
local cached, files = {}, { [1984] = 111, [1985] = 111, [1995] = 222 }   -- zwei Eber mit demselben Modell, die Eule
local created = 0
local plainCreateFrame = CreateFrame
function CreateFrame(kind, ...)
  local f = plainCreateFrame(kind, ...)
  if kind == "PlayerModel" then
    created = created + 1
    f.file, f.shown = 0, true
    f.GetModelFileID = function(self) return self.file end
    f.ClearModel = function() end                              -- räumt im Client nichts sichtbar weg
    f.SetCreature = function(self, id)
      if cached[id] then self.file = files[id] end             -- unbekannt: lädt nichts, das alte bleibt
    end
  end
  return f
end

Login()
local holder = NS.CreateBeastModel(CreateFrame("Frame"), 130)
local function tick(t) CLOCK = CLOCK + t; holder.scripts.OnUpdate(holder) end
local function wait(s) for _ = 1, s * 10 do tick(0.1) end end
-- was man sieht: Datei des sichtbaren Rahmens (nil = leer) und ob das Icon steht
local function seen()
  local file
  for _, f in pairs(holder.models) do
    if f.shown then
      ok(file == nil, "höchstens ein Rahmen sichtbar")
      file = f.file ~= 0 and f.file or nil
    end
  end
  return file
end
local function iconShown() return holder.icon.shown == true end
local icon = holder.hasIcon   -- ohne Icon in den Daten bleibt der Bereich leer

-- bekannter Eber: sofort da, kein Icon vorher
cached[1984] = true
holder:SetBeast(1984, {})
ok(seen() == 111 and not iconShown(), "bekannter Eber: Modell sofort da, kein Icon")
wait(1)
ok(seen() == 111 and not iconShown(), "bekannter Eber: bleibt")

-- unbekannte Eule: nie der Eber; nach dem ersten Blick das Icon
holder:SetBeast(1995, {})
ok(seen() == nil, "unbekannte Eule: leer, kein Eber")
wait(1)
ok(seen() == nil, "unbekannte Eule: weiter kein Eber")
ok(iconShown() == (holder.hasIcon == true), "stattdessen das Familien-Icon (sofern es eins gibt)")

-- der Client lernt die Eule kennen, das Nachfragen bringt sie
cached[1995] = true
wait(3)
ok(seen() == 222 and not iconShown(), "Eule nach dem Nachladen gezeigt, Icon weg")

-- bleibt ein Tier unbekannt, hört das Nachfragen auf
holder:SetBeast(9999, {})
wait(10)
ok(seen() == nil and holder.retryAt == nil and holder.checkAt == nil, "unbekannt nach 6 s: Nachfragen beendet")

-- zwei Tiere mit demselben Modell: beide zeigen es, sofort
cached[1985] = true
holder:SetBeast(1984, {})
ok(seen() == 111 and not iconShown(), "Eber erneut: sofort da")
holder:SetBeast(1985, {})
ok(seen() == 111 and not iconShown(), "zweiter Eber mit demselben Modell: sofort da")

-- ein Rahmen je Tier, keiner doppelt
local before = created
holder:SetBeast(1995, {})
holder:SetBeast(1985, {})
ok(created == before, "erneut geöffnete Tiere bekommen keinen neuen Rahmen")
ok(created == 4, "vier Tiere, vier Rahmen: " .. created)
