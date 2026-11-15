-- #177: Die Startansicht stellt beide Modi nebeneinander vor, ohne Empfehlung. Jeder Knopf setzt seinen Modus und
-- führt danach die Folgeaktion aus (etwa: das Fenster öffnen); Schließen ohne Wahl (ESC) ergibt den
-- Entdeckermodus, den Standard; bei schon gewähltem Modus ändert Schließen nichts.
-- lädt: UI/Widgets.lua UI/ModeDialog.lua
local L = NS.L
local de = NS.Locales.deDE

-- Knöpfe und den Dialog selbst merken (die nachgebildete API kennt keine Kinder)
local plainCreateFrame = CreateFrame
local buttons, dialog = {}, nil
function CreateFrame(kind, name, ...)
  local f = plainCreateFrame(kind, name, ...)
  if kind == "Button" then buttons[#buttons + 1] = f end
  if name == "ForeverHunterPetsModeDialog" then dialog = f end
  return f
end
local function button(text)
  for _, b in ipairs(buttons) do if b.text == text then return b end end
end

-- Texte: keine Empfehlung mehr, Hinweis auf die wachsenden Daten
for key, text in pairs(de) do
  ok(not text:find("Empfohlen%.") and not text:find("empfohlen"), "keine Empfehlung: " .. key:sub(1, 40))
end
ok(de["The data is still being collected and grows more complete over time. So don't be surprised if something is still missing."] ~= nil, "Hinweis zu den Daten übersetzt")
ok(de["You are in explorer mode. If you would rather see all details right away, switch explorer mode off in the settings."] ~= nil, "Tooltip Entdeckermodus ohne Empfehlung übersetzt")
ok(de["You are in complete mode. There are no challenges here and no hunt of your own, but you see all details. Why not give explorer mode a try?"]:find("Probier doch mal"), "Komplettmodus wirbt weiter")

-- frischer Charakter: Komplettmodus wählen, danach läuft die Folgeaktion
ForeverHunterPetsCharDB = {}
Login({})
ok(not NS.ModeChosen(), "noch kein Modus gewählt")
local opened = 0
NS.ShowModeDialog(function() opened = opened + 1 end)
ok(dialog ~= nil and dialog:IsShown(), "Startansicht offen")
ok(table.concat(UISpecialFrames, ","):find("ForeverHunterPetsModeDialog"), "ESC schließt die Startansicht")
local explorer, complete = button(L["Explorer mode"]), button(L["Complete mode"])
ok(explorer ~= nil and complete ~= nil, "je Modus ein Knopf")
complete.scripts.OnClick()
dialog.scripts.OnHide()   -- im Spiel ruft Hide() das Skript
ok(NS.ModeChosen() and not NS.Discovering(), "Knopf Komplettmodus setzt den Komplettmodus")
ok(opened == 1, "Folgeaktion einmal (" .. opened .. ")")

-- /fhp start bei gewähltem Modus: Schließen ändert nichts
NS.ShowModeDialog()
dialog:Hide()
dialog.scripts.OnHide()
ok(NS.ModeChosen() and not NS.Discovering(), "Schließen ändert einen gewählten Modus nicht")

-- Knopf Entdeckermodus
explorer.scripts.OnClick()
ok(NS.Discovering(), "Knopf Entdeckermodus setzt den Entdeckermodus")

-- frischer Charakter, Schließen ohne Wahl: Entdeckermodus, Folgeaktion läuft
NS.char.modeChosen, NS.char.discover = nil, nil
ok(not NS.ModeChosen(), "wieder kein Modus gewählt")
opened = 0
NS.ShowModeDialog(function() opened = opened + 1 end)
dialog:Hide()
dialog.scripts.OnHide()
ok(NS.Discovering(), "ESC ohne Wahl ergibt den Entdeckermodus")
ok(opened == 1, "Folgeaktion auch nach ESC (" .. opened .. ")")
