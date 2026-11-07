-- #131: Die Kartenseite zeigt nie das Modell des vorigen Tiers. Steht ein Tier noch nicht im Kreaturen-Cache,
-- lädt SetCreature nichts, ClearModel räumt nicht weg und GetModelFileID nennt noch die alte Datei; dann steht das
-- Familien-Icon da, bis der Client das Tier kennt und das Nachfragen das richtige Modell bringt.
-- lädt: UI/Widgets.lua UI/MapCanvas.lua

-- Nachgebildetes PlayerModel mit dem Verhalten des Clients
local cached, files = {}, { [1984] = 111, [1985] = 111, [1995] = 222 }   -- zwei Eber mit demselben Modell, die Eule
local model
local plainCreateFrame = CreateFrame
function CreateFrame(kind, ...)
  local f = plainCreateFrame(kind, ...)
  if kind == "PlayerModel" then
    model = f
    f.file, f.alpha = 0, 1
    f.GetModelFileID = function(self) return self.file end
    f.ClearModel = function() end                              -- räumt im Client nichts sichtbar weg
    f.SetAlpha = function(self, a) self.alpha = a end
    f.SetCreature = function(self, id)
      if not cached[id] then return end                        -- unbekannt: lädt nichts
      self.file = files[id]
      if self.scripts.OnModelLoaded then self.scripts.OnModelLoaded(self) end
    end
  end
  return f
end

Login()
local holder = NS.CreateBeastModel(CreateFrame("Frame"), 130)
local function tick(t) CLOCK = CLOCK + t; holder.scripts.OnUpdate(holder) end
local function wait(s) for _ = 1, s * 10 do tick(0.1) end end
local function visible() return model.alpha == 1 end

-- bekannter Eber: lädt, wird gezeigt
cached[1984] = true
holder:SetBeast(1984, {})
wait(1)
ok(visible() and model.file == 111, "bekannter Eber: Modell gezeigt")
ok(holder.icon.shown == false, "Icon weg, sobald das Modell da ist")

-- unbekannte Eule: der Eber darf nicht stehen bleiben
holder:SetBeast(1995, {})
wait(1)
ok(not visible(), "unbekannte Eule: Modell versteckt (alter Eber nicht gezeigt)")
ok(model.file == 111, "Nachbildung: GetModelFileID nennt noch den Eber")
ok(holder.icon.shown == (holder.hasIcon == true), "stattdessen das Familien-Icon (sofern es eins gibt)")

-- der Client lernt die Eule kennen, das Nachfragen bringt sie
cached[1995] = true
wait(3)
ok(visible() and model.file == 222, "Eule nach dem Nachladen gezeigt")

-- bleibt ein Tier unbekannt, hört das Nachfragen auf
holder:SetBeast(9999, {})
wait(10)
ok(not visible() and holder.retryAt == nil and holder.checkAt == nil, "unbekannt nach 6 s: Nachfragen beendet")

-- zwei Tiere mit demselben Modell: das zweite lädt (OnModelLoaded) und wird gezeigt
holder:SetBeast(1984, {})
wait(1)
cached[1985] = true
holder:SetBeast(1985, {})
wait(1)
ok(visible() and model.file == 111, "zweiter Eber mit demselben Modell gezeigt")

-- dasselbe Tier noch einmal geöffnet
holder:SetBeast(1985, {})
wait(1)
ok(visible(), "dasselbe Tier noch einmal: gezeigt")
