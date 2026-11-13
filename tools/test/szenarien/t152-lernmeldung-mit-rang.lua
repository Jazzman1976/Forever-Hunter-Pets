-- #152: Die Lernmeldung trägt die Zauber-ID des Jägers, nicht die des Pet-Rangs. Bei manchen Fähigkeiten steht
-- der Rang im Namen des Links („[Zwicken (Rang 1)]“); dann entscheidet die Zahl, auch ohne Pet. Ohne Rang im
-- Namen bleibt es beim Rang, den das Pet schon kann.
ERR_LEARN_SPELL_S = "Ihr habt einen neuen Zauber erlernt: %s."
local PET = {}   -- Zauber-IDs, die das aktive Pet kann; leer = kein Pet
function UnitExists(unit) return unit == "pet" and next(PET) ~= nil end
function IsSpellKnown(id) return PET[id] == true end

Login({})
local D = NS.Data

local function ability(name)
  for _, a in ipairs(D.abilities) do if a.de == name then return a end end
end
-- eine Fähigkeit mit mindestens zwei Rängen
local multi
for _, a in ipairs(D.abilities) do
  if not multi and a.de and #a.ranks >= 2 and NS.Learnable(a) then multi = a end
end
local nip = ability("Zwicken")
ok(nip ~= nil and nip.ranks[1].id == 1264735, "Zwicken Rang 1 (1264735) in den Daten")
ok(multi ~= nil, "Fähigkeit mit zwei Rängen: " .. tostring(multi and multi.de))

local function learn(id, name)
  PRINTED = {}
  FireEvent("CHAT_MSG_SYSTEM", ("Ihr habt einen neuen Zauber erlernt: |cff71d5ff|Hspell:%d:0|h[%s]|h|r."):format(id, name))
end
local function known(r) return NS.IsKnown(r) end
local function lastLog() local log = ForeverHunterPetsDB.learnLog; return log and log[#log] or "" end

-- Meldung wie im Protokoll vom 10.11.2026, ohne Pet
learn(1264745, "Zwicken (Rang 1)")
ok(known(nip.ranks[1]), "[Zwicken (Rang 1)] mit fremder ID ohne Pet: Rang 1 gelernt")
ok(NS.char.known[nip.ranks[1].id] == "t", "… Quelle „t“")
ok(#PRINTED == 1 and PRINTED[1]:find("Zwicken", 1, true) ~= nil, "… eine Chatzeile")
ok(lastLog():find("erkannt über Rang", 1, true) ~= nil, "… Protokoll „erkannt über Rang“")

-- dieselbe Meldung noch einmal: keine zweite Chatzeile
learn(1264745, "Zwicken (Rang 1)")
ok(#PRINTED == 0, "schon bekannter Rang: keine zweite Chatzeile")

-- englische Form, Rang 2 einer Fähigkeit mit mehreren Rängen
learn(9999001, multi.de .. " (Rank 2)")
ok(known(multi.ranks[2]), "[" .. multi.de .. " (Rank 2)]: Rang 2 gelernt")
ok(not known(multi.ranks[1]), "… Rang 1 bleibt offen")

-- Rang, den es in den Daten nicht gibt: wie ohne Rang, also über das Pet (ohne Pet nichts)
learn(9999002, nip.de .. " (Rang 9)")
ok(#PRINTED == 0, "[Zwicken (Rang 9)] ohne Pet: nichts gelernt")

-- Gegenprobe des alten Wegs: Name ohne Rang, das Pet kann Rang 1
NS.char.known[multi.ranks[2].id] = nil
PET[multi.ranks[1].id] = true
learn(9999003, multi.de)
ok(known(multi.ranks[1]), "[" .. multi.de .. "] ohne Rang, Pet kann Rang 1: Rang 1 gelernt")
ok(not known(multi.ranks[2]), "… Rang 2 bleibt offen")
ok(lastLog():find("erkannt über Name", 1, true) ~= nil, "… Protokoll „erkannt über Name“")
PET = {}

-- keine Pet-Fähigkeiten
learn(8613, "Kürschnerei")
ok(#PRINTED == 0, "[Kürschnerei]: nichts gelernt")
learn(1978, "Schlangenbiss (Rang 1)")
ok(#PRINTED == 0, "[Schlangenbiss (Rang 1)]: nichts gelernt")
ok(lastLog():find("kein Rang erkannt", 1, true) ~= nil, "… Protokoll „kein Rang erkannt“")

-- Meldungen aus dem Protokoll vom 12.11.2026 (beim Tierausbilder, ohne offenen Rang am Pet): damals „kein Rang
-- erkannt“, jetzt eindeutig über die Zahl
local stamina, armor = ability("Große Ausdauer"), ability("Natürliche Rüstung")
learn(4195, "Große Ausdauer (Rang 1)")
learn(24547, "Natürliche Rüstung (Rang 1)")
learn(4197, "Große Ausdauer (Rang 3)")
learn(24557, "Natürliche Rüstung (Rang 3)")
ok(known(stamina.ranks[1]) and known(stamina.ranks[3]), "Große Ausdauer Rang 1 und 3 vom Tierausbilder gelernt")
ok(not known(stamina.ranks[2]), "… Rang 2 bleibt offen")
ok(known(armor.ranks[1]) and known(armor.ranks[3]), "Natürliche Rüstung Rang 1 und 3 vom Tierausbilder gelernt")
-- Zauber des Jägers mit Rang im Namen bleiben außen vor
learn(14318, "Aspekt des Falken (Rang 2)")
learn(13550, "Schlangenbiss (Rang 3)")
ok(#PRINTED == 0, "[Aspekt des Falken (Rang 2)], [Schlangenbiss (Rang 3)]: nichts gelernt")
