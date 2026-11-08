-- #144: Fremde Zähmungen unter der Schwelle lösen den Hinweis „brauchen noch mehr Belege“ nur aus, wenn die Daten
-- den gezeigten Rang nicht schon belegen. Räudiger Bergeber (1191) lehrt laut Stammdaten Sturmangriff Rang 2 (26177).
local CHARGE2, BITE1 = 26177, 17253
-- Login setzt den Index der Zähmungen nicht zurück, daher nach jedem Login NS.ObservationsChanged()
local via = { a0000001 = "e0000001", a0000002 = "e0000002" }

Login({ ui = { showUncertain = false } }); NS.ObservationsChanged()
local _, base = NS.TeachInfo(1191, false)
ok(base == false, "ohne fremde Zähmung: kein Hinweis")

Login({ obs = { ("1191;15;%d;2;1792400001;a0000001"):format(CHARGE2) }, via = via, ui = { showUncertain = false } }); NS.ObservationsChanged()
local info, unsure = NS.TeachInfo(1191, false)
ok(info and #info == 1 and info[1].conf == NS.CONF_SURE, "1 Melder bestätigt den belegten Rang: Sturmangriff belegt")
ok(unsure == false, "1 Melder mit belegtem Rang: kein Hinweis")

Login({ obs = { ("1191;15;%d;2;1792400001;a0000001"):format(CHARGE2), ("1191;15;%d;2;1792400002;a0000002"):format(CHARGE2) },
  via = via, ui = { showUncertain = false } }); NS.ObservationsChanged()
ok(select(2, NS.TeachInfo(1191, false)) == false, "2 Melder mit belegtem Rang: kein Hinweis")

-- zusätzlicher Rang, den die Daten dem Bergeber nicht zuschreiben: weiter unklar
Login({ obs = { ("1191;15;%d,%d;2;1792400001;a0000001"):format(CHARGE2, BITE1) }, via = via, ui = { showUncertain = false } }); NS.ObservationsChanged()
ok(select(2, NS.TeachInfo(1191, false)) == true, "1 Melder mit zusätzlichem Rang: Hinweis")

-- Testtier ohne Daten: wie bisher
Login({ obs = { ("991441;20;%d;;1792400001;a0000001"):format(BITE1) }, via = via, ui = { showUncertain = false } }); NS.ObservationsChanged()
local i2, u2 = NS.TeachInfo(991441, false)
ok(i2 == nil and u2 == true, "Tier ohne Daten, 1 Melder: unklar, mit Hinweis")
