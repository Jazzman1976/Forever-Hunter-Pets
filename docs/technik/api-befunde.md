# Befunde zur Forever-API

Was der WoW-Forever-Client Addons erlaubt und was nicht – jeweils im Spiel geprüft (Build 1.60.1.70338, deDE, Oktober 2026). Gesammelt während der Entwicklung. Wie das Addon damit umgeht, beschreibt [addon-technik.md](addon-technik.md).

Der Client meldet `## Interface: 16001` und `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`. Es ist die moderne Engine: `C_Map`, `C_Spell`, `C_SpellBook`, `C_AddOns`, Addon-Compartment.

## Auslesen (API-Probe `/fhp api`)

- **Die Craft-API fehlt in Forever** (`GetNumCrafts`, `GetCraftInfo`, `CraftFrame`, Ereignisse `CRAFT_*`), ebenso `GetPetTrainingPoints`. Das alte Fenster „Wildtierausbildung“ ist so nicht auslesbar.
- **Pet-Zauberbuch geht:** `C_SpellBook.GetSpellBookItemInfo(i, 1)` liefert `spellID` und Rang; die IDs sind die Zauber-IDs der Pet-Ränge (Beißen Rang 3 = 17256). `IsSpellKnown(id, true)` sagt je Rang, ob das aktive Pet ihn kann. Ohne `true` und für nicht aktive Ränge kommt `false`.
- **Familie mit ID:** `UnitCreatureFamily("pet")` liefert Name und ID („Eber“, 5), die ID ist die Familien-ID, die auch die Daten nutzen.
- **Auch Dämonen haben eine Familie** (20.10.2026, #80): Teufelspirscher und Teufelstöter liefern 15 „Teufelsjäger“, der Leerwandlerdiener (Diener eines NPC) 16 „Leerwandler“. Zähmen bricht bei ihnen mit „Ungültiges Ziel“ ab, bevor der Zauber beginnt.
- **Kreaturtyp mit ID** (20.10.2026, #80): `UnitCreatureType(unit)` liefert Name und eine sprachunabhängige ID („Wildtier“, 1; „Dämon“, 3). `C_CreatureInfo.GetCreatureTypeInfo(1)` gibt `{ id = 1, name = "Wildtier" }`.
- **Karten gehen:** `C_Map.GetMapArtLayers` (1002 × 668, Kacheln 256) und `GetMapArtLayerTextures`; `C_Map.GetAreaInfo(12)` = „Wald von Elwynn“; uiMapID 1429 stimmt.
- `C_Spell.GetSpellDescription(id)` gab beim ersten Aufruf nichts zurück. Die Beschreibung aus den Daten bleibt Reserve.
- Registrierbar: `UNIT_PET`, `UNIT_PET_TRAINING_POINTS`, `PET_BAR_UPDATE`, `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`, `TRAINER_SHOW`, `PET_STABLE_SHOW`.
- **Zweite Probe:** Beim Öffnen des Ausbildungsfensters feuert `TRAINER_SHOW`. Forever zeigt die Wildtierausbildung also vermutlich als Trainer-Fenster (`GetNumTrainerServices`, `GetTrainerServiceInfo`). Trainingspunkte liefert `C_PetInfo.GetPetTrainingPoints`. Weitere Kandidaten: `C_StableInfo.GetStablePetInfo`, `GetActivePetList`.
- **Dritte Probe: das Ausbildungsfenster ist lesbar.** Es ist ein Trainer-Fenster ohne NPC (`UnitName("npc")` = nil, `IsTradeskillTrainer()` = false). `GetTrainerServiceInfo(i)` liefert Name, Status, Icon, Pet-Stufe und Rang („Beißen | used | 132278 | 16 | Rang 3“), `GetTrainerServiceCost(i)` die TP, `GetTrainerServiceDescription(i)` die Beschreibung. `C_PetInfo.GetPetTrainingPoints()` = gesamt | verbraucht (110 | 41).
  - Die Liste enthält die Ränge, die der Jäger kennt **und** die die Familie des aktiven Pets lernen kann (beim Eber 21 Einträge). `used` = hat das Pet schon („Bereits bekannt“), `available` = lernbar.
  - Direkt bei `TRAINER_SHOW` ist die Liste teils noch unfertig (Rang = nil, alles `available`); ein zweiter Durchlauf kurz danach stimmt.
  - Der Filter „Bereits bekannt“ ist im Spiel standardmäßig aus; dann fehlen die `used`-Einträge in der Liste.
  - Eine Spell-ID liefert die Trainer-Liste nicht (`GetTrainerServiceItemLink` = nil). Zuordnung über Name und Rang.
  - **Der Tooltip der Zeile schon** (Erhebung, 16.10.2026): `C_TooltipInfo.GetTrainerService(i).id` und `GameTooltip:SetTrainerService(i)` + `:GetSpell()` nennen beide die Zauber-ID des **Pet-Rangs**, gleich wie im Zauberbuch des Pets (Beißen 3 = 17256, Natürliche Rüstung 3 = 24550, Sturmangriff 3 = 26178) – in der Wildtierausbildung wie beim Tierausbilder.
  - **Tierausbilder in der Stadt** (Trainer-Fenster mit NPC): Er bietet Knurren, Große Ausdauer, Natürliche Rüstung und die fünf Widerstände an, alle Ränge bis 60. Die vierte Rückgabe ist dort die **Jägerstufe** (0 = schon gelernt), `GetTrainerServiceCost` der Preis in Kupfer. Direkt nach dem Öffnen fehlt auch hier der Rangtext; nach `TRAINER_UPDATE` ist er da.
  - **Fehler im Client** (vom Nutzer gesehen, 16.10.2026): Beim ersten Öffnen je Sitzung zeigt der Tierausbilder alle Ränge, als wäre keiner gelernt; erst ab dem zweiten Öffnen steht „Bereits gelernt“ dran. Die Erhebung nimmt vom Tierausbilder keinen Status und überschreibt die Jägerstufe nicht mit 0 – das erste Öffnen liefert so sogar die Stufen der schon gelernten Ränge.  - Beim Lernen kommt `CHAT_MSG_SYSTEM` „Euer Begleiter hat den neuen Zauber 'Knurren (Rang 3)' erlernt.“ und `SPELLS_CHANGED`.
- **Folge für Inkrement 6:** Lernstand = alle Einträge des Ausbildungsfensters (jeder Status heißt: der Jäger kennt den Rang), gesammelt über die Zeit, weil das Fenster nur die Familie des aktiven Pets zeigt. Dazu `IsSpellKnown(id, true)` für das, was das aktive Pet kann – **das war falsch, siehe nächster Punkt.**
- **Das Pet kann einen Rang früher als der Jäger** (im Spiel beobachtet, 13.10.2026): Ein frisch gezähmtes Tier beherrscht seinen Rang sofort, `IsSpellKnown(id, true)` meldet ihn also. Der Jäger lernt ihn erst, nachdem das Tier ihn einige Male eingesetzt hat; dann kommt `CHAT_MSG_SYSTEM` „Ihr habt einen neuen Zauber erlernt: [Wildes Verwunden].“ mit Zauber-Link, und ab da steht der Rang in der Wildtierausbildung. `IsSpellKnown` ist deshalb seit 0.2.1 keine Quelle für den Lernstand mehr. Vor der Lernmeldung steht der Rang nicht in der Wildtierausbildung (im Spiel bestätigt, 13.10.2026, Beißen Rang 4).
- **Die Lernmeldung trägt nicht die ID des Rangs** (im Spiel geprüft, 14.10.2026). Roh: `Ihr habt einen neuen Zauber erlernt: |cff71d5ff|Hspell:26185:0|h[Sturmangriff]|h|r.` – in den Daten ist Sturmangriff Rang 3 die 26178. Der Jäger lernt also einen eigenen Zauber mit eigener ID; der Rang steht weder im Text noch im Link. Die Meldung kommt als `CHAT_MSG_SYSTEM`, war im offenen Kampf lesbar (kein geheimer Wert) und passt auf `ERR_LEARN_SPELL_S` („Ihr habt einen neuen Zauber erlernt: %s.“). `LEARNED_SPELL_IN_SKILL_LINE` kam dabei nicht. Seit 0.2.1 ordnet das Addon über den Namen im Link und den Rang des aktiven Pets zu.
- **Ungeprüft:** was die Meldung trägt, wenn man beim Tierausbilder in der Stadt lernt. Vermutlich ebenfalls eine jägerseitige ID; dann erkennt das Addon den Rang erst beim nächsten Öffnen der Wildtierausbildung.

## Angriffstempo (Probe, 16.10.2026)

- Ein abweichendes Tempo ist eine **passive Fähigkeit im Zauberbuch** des Pets, mit Namen und Zauber-ID: Halbwüchsiger Schneeleopard (1199, 1,5 s) → „Schnellerer Angriff III“ (1263102), Junger Waldbär (822, 2,5 s) → „Langsamerer Angriff II“ (1263113). Die römische Ziffer gehört zum Namen; Untertitel „Passiv“, kein Rang. Normales Tempo (2,0 s, Eisklauenbär 1196) hat keine.
- `UnitAttackSpeed(unit)` beim wilden Tier (angevisiert, außerhalb des Kampfs) liefert dasselbe Tempo wie nach dem Zähmen, in allen drei Fällen.

## Kampf (Probe, 16.10.2026)

- Bei `PLAYER_REGEN_DISABLED` (Kampfbeginn) ist das Ziel noch lesbar, nicht geheim: GUID, NPC-ID, `UnitIsDead`, `CheckInteractDistance`. Drei Kämpfe gegen den Großen Fleischreißer (154) in Westfall.
- Bei `PLAYER_REGEN_ENABLED` (Kampfende) war das tote Tier nicht mehr im Ziel; daraus lässt sich nichts lesen.
- Folge: Ein Kampf bringt für das Entdecken nichts, was die Sichtung nicht schon liefert. Jäger beginnen meist aus der Ferne (kein Fundort), und ein vorher nahes Ziel hat die Sichtung schon erfasst. Kampf wird nicht eigens behandelt (Entscheidung des Nutzers).

## Spur und Fernsicht (Spur-Probe `/fhp spur`, 16.10.2026, Build 70425)

- **„Wildtiere aufspüren“** ist Zauber 1494 (Icon 132328, die Pfoten) und eine Aura des Spielers (`C_UnitAuras.GetPlayerAuraBySpellID(1494)`).
- **„Augen des Wildtiers“** ist Kanalzauber 1002, **„Adlerauge“** Kanalzauber 6197; `UnitChannelInfo("player")` nennt Name und ID an 8. Stelle. `UnitIsPossessed("pet")` und `IsPossessBarVisible()` sagen während des Kanals nichts.
- In beiden Fällen reicht die Maus weit: `UPDATE_MOUSEOVER_UNIT` mit Name und Familie auch für Tiere am anderen Ende. `CheckInteractDistance` misst dabei vom Jäger aus (alle `false`) – Fundorte entstehen also ohnehin nicht, das Addon sperrt sie trotzdem (`ns.Possessing`).
- `UnitPosition` liefert für fremde Einheiten und das Pet nichts.
- **Minikarte** (zweite Probe, 16.10.2026): Die Namen der Spur stehen im **GameTooltip mit dem Besitzer `UIParent`** (nicht `Minimap`), alle in Zeile 1, durch Zeilenumbrüche getrennt, gleiche Tiere auch doppelt („Großer Fleischreißer
Großer Fleischreißer“). Lesbar, kein geheimer Wert. Der Client tauscht den Text aus, ohne den Tooltip neu zu zeigen – `OnShow` reicht also nicht, man muss nachsehen, solange die Maus über der Minikarte ist. Dazwischen stehen auch Spieler, Pets und Knöpfe („Vergrößern“).

## Ausbilden (Lehrprobe)

- **Öffnen geht:** Ein sicherer Knopf (`SecureActionButtonTemplate`, Typ `spell`, Zauber 5149 „Wildtierausbildung“) wirkt den Zauber, `TRAINER_SHOW` kommt, `ClassTrainerFrame` ist sichtbar.
- **Lehren ist gesperrt:** `BuyTrainerService(index)` löst `ADDON_ACTION_FORBIDDEN` aus, beim eigenen Klick wie im Ein-Klick-Ablauf. Es wurden keine Trainingspunkte verbraucht.
- **Schließen wirkt nicht:** `CloseTrainer()` wirft nichts, das Fenster bleibt offen.
- **Vormarkieren geht nicht:** `SelectTrainerService(Zeile)` ändert die Auswahl der API (`GetTrainerSelectionIndex`), das Fenster zeigt aber weiter sein eigenes Feld `ClassTrainerFrame.selectedService`. Setzt das Addon dieses Feld, markiert das Fenster zwar richtig, sein Knopf „Ausbilden“ ist danach aber gesperrt (`ADDON_ACTION_FORBIDDEN: BuyTrainerService()`).
- **Wildtierausbildung neben einem NPC** (#32, Proben im Spiel, 18.10.2026):
  - `UNIT_SPELLCAST_SUCCEEDED` (player, 5149) kommt **nach** `TRAINER_SHOW`, nicht davor. `UNIT_SPELLCAST_SENT` und `_START` kommen für 5149 nicht.
  - Die Wildtierausbildung schließt das Fenster von Händler, Jägerlehrer oder Tierausbilder; nur das Fenster des Stallmeisters bleibt daneben offen. Das `TRAINER_CLOSED` des alten Trainer-Fensters kommt erst nach dem `TRAINER_SHOW` der Wildtierausbildung.
  - Bis dahin ist `UnitExists("npc")` wahr. Ein NPC beim Öffnen sagt also nicht sicher, dass es der Tierausbilder ist.
- **Tierausbilder-NPC:** Das Öffnen seines Fensters liefert dem Addon nichts. Was man dort lernt, kommt über die Systemnachricht mit Zauber-Link in den Lernstand.

## Zähmen (Zähm-Probe `/fhp zaehmen`, 14.10.2026, Build 70374)

Gezähmt wurde ein Großer Fleischreißer (NPC 154) auf Stufe 17.

- **Ablauf:**
  - `UNIT_SPELLCAST_CHANNEL_START` und gleichzeitig `UNIT_SPELLCAST_SUCCEEDED` (player, Zauber 1515) kommen gleich zu Beginn. Zu diesem Zeitpunkt ist das Ziel noch das Tier.
  - Nach 20 s folgt `UNIT_SPELLCAST_CHANNEL_STOP`, 0,1 s später **zweimal** `UNIT_PET` (player), dazu `SPELLS_CHANGED`.
  - Ob das Zähmen gelungen ist, sagt nur das neue Pet; der Stopp des Kanals sagt es nicht.
- **Die GUID des Pets trägt nicht die NPC-ID:** Sie lautet `Pet-0-…-165189-…`, auch beim Fleischreißer. Die NPC-ID muss deshalb beim Beginn des Zähmens aus der GUID des Ziels kommen (`Creature-…-154-…`).
- **Zauberbuch:**
  - Beim ersten `UNIT_PET` ist es noch leer: `C_SpellBook.HasPetSpells()` liefert `nil`, und `UnitAttackSpeed("pet")` ist geheim.
  - Beim zweiten `UNIT_PET` ist es vollständig. Fähigkeiten tragen `spellID` und `subName` („Rang 1“); Begleiterbefehle und -haltungen haben `spellID = nil`.
  - **Ausnahme: ein Zauber, den der Client in dieser Sitzung noch nicht gezeigt hat** (18.10.2026, #17, Blitzschlagatem 25008): `subName` ist leer, `C_Spell.GetSpellSubtext` liefert `nil`, `C_Spell.IsSpellDataCached` `false`. Nur ID und Name sind da. Nach `C_Spell.RequestLoadSpellData` kommen die Daten nach; nach `/reload` oder einem Tooltip sind sie im Cache.
  - `IsSpellKnown(id, true)` ist für den mitgebrachten Rang `true`. `ns.PetRanks()` stimmt damit überein.
  - Danach ändert sich nichts mehr (geprüft nach 1, 3 und 6 s).
- **Stufe und Tempo:** `UnitLevel("pet")` ist die Stufe des Tiers (17), `UnitAttackSpeed("pet")` liefert 2 (normal). `GetPetTrainingPoints` gibt es nicht.
- **Ergebnis:**
  - Der Fleischreißer brachte nur Demoralisierendes Kreischen 1 mit.
  - Beißen 3 und Klaue 3, die für dieses Tier vermutet worden waren, fehlten, obwohl Stufe 17 für beide reicht. Beide stehen als „widerlegt“ in `tools/korrekturen.json`.
  - Sturzflug 1 (Pet-Stufe 30) lässt sich auf Stufe 17 weder bestätigen noch widerlegen.

## Addon-Nachrichten (Selbsttest `/fhp teilen test`, 14.10.2026)

- **Senden geht:** `C_ChatInfo.SendAddonMessage` liefert über Gilde, den eigenen Kanal (`JoinTemporaryChannel`) und Flüstern an sich selbst `0` (Erfolg). `RegisterAddonMessagePrefix` wirkt, und `IsAddonMessagePrefixRegistered` meldet `true`.
- **Eigene Nachrichten kommen zurück:** Über alle drei Wege fast sofort als `CHAT_MSG_ADDON`.
- **Namen in Forever: „Vorname Nachname“.** Als Absender steht `Grimmbart Hesingway`, mit Leerzeichen und ohne Realm. `UnitFullName("player")` liefert die beiden Teile getrennt (`Grimmbart`, `Hesingway`). Ein Vergleich mit „Name-Realm“ schlägt deshalb fehl. Das Addon vergleicht ohne Leerzeichen und Bindestriche, immer den vollen Namen. Geflüstert wird an genau den Namen, den der Client als Absender nennt. An `Grimmbart-Hesingway` kam das Flüstern ebenfalls an.

## Karte und Einstellungen

- **Erkundete Gebiete:** `C_MapExplorationInfo.GetExploredMapTextures(uiMapID)` liefert die aufgedeckten Kartenteile – auch für Zonen, in denen der Charakter gerade nicht steht. Das Addon nutzt nur das; eine fremde Overlay-Tabelle, wie Karten-Aufdecker sie mitbringen, kommt aus Lizenzgründen nicht in Frage.
- **Einstellungsseite:** Die moderne `Settings`-API (`RegisterAddOnSetting` mit Variablentabelle) funktioniert im Forever-Client.
- **Keine Rahmen oder Funktionen der Einstellungsliste anfassen** (18.10.2026, #5): Die Liste verwendet ihre Rahmen für alle Seiten der Spieloptionen wieder. Seit 0.7.0 war das Logo eine Überschrift des Clients mit ersetztem `InitFrame` und `GetExtent`; damit richtete Code des Addons Rahmen ein, die sich alle Seiten teilen. Nachdem die Addon-Seite offen war, meldete der Client beim Scrollen auf *Kontakte* „Forever-Hunter-Pets wurde geblockt“ (Taint) – ohne vorheriges Öffnen der Addon-Seite nicht. Ein zusätzlicher `hooksecurefunc(frame, "Init", …)` und ein Kind-Rahmen mit `OnUpdate` änderten daran nichts. Sauberer Weg: eigene XML-Vorlage, die von der Vorlage des Clients erbt, und `Settings.CreateElementInitializer` – eigener Pool, kein Addon-Code beim Aufbau der Liste. Ob das reicht, zeigt der Test zu #5.
- **Zone → Karte:** Fehlt eine Zone in `ZONE_MAP`, findet das Addon die Karte über den Zonennamen (`C_Map.GetAreaInfo` gegen `C_Map.GetMapInfo`); `/fhp zones` listet, was übrig bleibt.

## Geheime Werte

In Kampf und Instanzen liefert die API „secret values“, die schon beim Vergleichen einen Fehler werfen. Nur `issecretvalue()` ist ein sicherer Test. Auslesen also nur außerhalb des Kampfs und durch `ns.clean()`.
