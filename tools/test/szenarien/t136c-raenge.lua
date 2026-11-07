-- #136: fremder Rang einer bekannten Fähigkeit ab 2 Meldern unsicher („Rang n?“, nur mit dem Schalter), mit dem
-- dritten Melder belegt
local a
for _, x in ipairs(NS.Data.abilities) do if x.de == "Ducken" then a = x end end
local top = 0
for _, r in ipairs(a.ranks) do top = math.max(top, r.rank) end
local ID = 7710001
C_Spell.GetSpellName = function(id) return id == ID and "Ducken" or nil end
C_Spell.GetSpellSubtext = function(id) return id == ID and ("Rang " .. (top + 1)) or nil end
C_Spell.IsSpellDataCached = function(id) return id == ID end
local obs = { ("991001;40;%d;;1792000001;a0000001"):format(ID), ("991001;40;%d;;1792000002;a0000002"):format(ID) }
Login({ obs = obs, via = { a0000001 = "e0000001", a0000002 = "e0000002", a0000003 = "e0000003" }, ui = { showUncertain = false } })
RunTimers()
local r
for _, x in ipairs(a.ranks) do if x.id == ID then r = x end end
ok(r and r.conf == NS.CONF_UNSURE, "2 Melder: Rang " .. (top + 1) .. " als unsicher eingehängt")
ok(#NS.Teachers(a, r) == 0, "ohne Schalter: kein Lehrtier gezeigt")
NS.db.ui.showUncertain = true
local t = NS.Teachers(a, r)
ok(#t == 1 and t[1].id == 991001 and t[1].conf == NS.CONF_UNSURE, "mit Schalter: Tier 991001 als unsicheres Lehrtier")
ok(NS.RankLabel(a, r) == "Rang " .. (top + 1) .. "?", "Rang mit „?“")

-- dritter Melder: belegt
NS.db.obs[#NS.db.obs + 1] = ("991001;40;%d;;1792000003;a0000003"):format(ID)
NS.ObservationsChanged()
NS.MergeSurveyAbilities()
ok(r.conf == nil and NS.RankLabel(a, r) == "Rang " .. (top + 1), "3 Melder: belegt, ohne „?“")
NS.db.ui.showUncertain = false
local t3 = NS.Teachers(a, r)
ok(#t3 == 1 and t3[1].conf == NS.CONF_SURE, "und ohne Schalter gezeigt, als belegtes Lehrtier")
