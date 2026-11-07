-- #131: Die Kartenseite zeigt nie das Modell des vorigen Tiers. Steht ein Tier noch nicht im Kreaturen-Cache,
-- lädt SetCreature nichts, ClearModel räumt nicht weg und GetModelFileID nennt noch die alte Datei; dann steht das
-- Familien-Icon da, bis der Client das Tier kennt und das Nachfragen das richtige Modell bringt.
-- lädt: UI/Widgets.lua UI/MapCanvas.lua

-- Nachgebildetes PlayerModel mit dem Verhalten des Clients, wie es der Test im Spiel (07.11.2026) nahelegt:
-- Bei versteckter Seite nennt GetModelFileID nichts, und OnModelLoaded feuert auch für das alte Modell.
local cached, files = {}, { [1984] = 111, [1985] = 111, [1995] = 222 }   -- zwei Eber mit demselben Modell, die Eule
local model, pageHidden
local plainCreateFrame = CreateFrame
function CreateFrame(kind, ...)
  local f = plainCreateFrame(kind, ...)
  if kind == "PlayerModel" then
    model = f
    f.file, f.alpha = 0, 1
    f.GetModelFileID = function(self) return pageHidden and 0 or self.file end
    f.ClearModel = function() end                              -- räumt im Client nichts sichtbar weg
    f.SetAlpha = function(self, a) self.alpha = a end
    f.SetCreature = function(self, id)
      if cached[id] then self.file = files[id] end             -- unbekannt: lädt nichts, das alte bleibt
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
-- wie im Spiel: Die Kartenseite ist beim Wechsel versteckt und erscheint erst danach
local function open(id) pageHidden = true; holder:SetBeast(id, {}); pageHidden = false end

-- bekannter Eber: lädt, wird gezeigt
cached[1984] = true
open(1984)
wait(1)
ok(visible() and model.file == 111, "bekannter Eber: Modell gezeigt")
ok(holder.icon.shown == false, "Icon weg, sobald das Modell da ist")

-- unbekannte Eule: der Eber darf nicht stehen bleiben
open(1995)
wait(1)
ok(not visible(), "unbekannte Eule: Modell versteckt (alter Eber nicht gezeigt)")
ok(model.file == 111, "Nachbildung: GetModelFileID nennt noch den Eber")
ok(holder.icon.shown == (holder.hasIcon == true), "stattdessen das Familien-Icon (sofern es eins gibt)")

-- der Client lernt die Eule kennen, das Nachfragen bringt sie
cached[1995] = true
wait(3)
ok(visible() and model.file == 222, "Eule nach dem Nachladen gezeigt")

-- bleibt ein Tier unbekannt, hört das Nachfragen auf
open(9999)
wait(10)
ok(not visible() and holder.retryAt == nil and holder.checkAt == nil, "unbekannt nach 6 s: Nachfragen beendet")

-- zwei Tiere mit demselben Modell: Vom alten nicht zu unterscheiden, das zweite behält das Icon (Grenzfall)
open(1984)
wait(1)
ok(visible(), "Eber gezeigt")
cached[1985] = true
open(1985)
wait(1)
ok(not visible(), "zweiter Eber mit demselben Modell: Icon statt Modell")

-- dasselbe Tier noch einmal geöffnet
open(1984)
wait(1)
open(1984)
wait(1)
ok(visible(), "dasselbe Tier noch einmal: gezeigt")
