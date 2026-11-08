# Changelog

## 1.1.0 – 2026-11-08

The next full release, with everything from 1.1.0-beta.1 and one more fix. If you used the beta, only the last two points are new for you. New features will keep coming as beta versions first, until they are ready for the next full release.

**Please restart the game** after updating from 1.0.0 – this version brings new files, and `/reload` is not enough.

- **Your pet's level and experience at the pet frame:** a small level badge and an experience bar below the game's pet frame, with the exact numbers on hover. Both can be switched off in the settings (*Enable pet frame additions*).
- **One rule for everything other players report:** what 2 other players have reported is *uncertain*, from 3 players on it counts as confirmed – the same for which beast teaches a rank, a beast's name, family and level, where it lives, *teaches nothing* and attack speed. Uncertain data is only shown with *Show uncertain data*, with a **?** right after the value. What only one other player has reported is kept, but no longer shown.
- **New ranks found by others:** when other players tame a beast with a rank the addon doesn't know yet, your game looks up its name and rank. Once enough players saw it, the rank shows up in *Abilities* – with "pet level unknown" until someone finds out more.
- **The beast page shows the right beast:** the 3D model no longer shows a different beast you looked at before, while the game is still loading the new one.
- **Smaller fixes:** the beast page closes when you switch to explorer mode, and the German label of *Show finds of my other characters* is no longer cut off.
- **Privacy:** the self-test of `/fhp share` no longer stores the names of other players, and its log is cleared after a day.
- **New in this release – no false call for more proof:** the beast tooltip no longer says *Hunters need more proof of what this beast teaches* just because another player shared a taming of it, when the addon's data already confirms what it teaches.
- **More data from the game:** 178 beasts (1.0.0: 175), 1122 spawn points (1.0.0: 898), three new teaching beasts for Claw and Bite, and Faster Attack III is now confirmed for one more beast. Bite is now known for bears, Cower for boars and bears. A few entries reported by only one other player were dropped under the new rule.

## 1.1.0-beta.1 – 2026-11-07

The first beta on the way to 1.1.0. Betas now count up towards the next full release: 1.1.0-beta.1, 1.1.0-beta.2, … and then 1.1.0.

**Please restart the game** after updating – this version brings new files, and `/reload` is not enough.

- **Your pet's level and experience at the pet frame:** a small level badge and an experience bar below the game's pet frame, with the exact numbers on hover. Both can be switched off in the settings (*Enable pet frame additions*).
- **One rule for everything other players report:** what 2 other players have reported is *uncertain*, from 3 players on it counts as confirmed – the same for which beast teaches a rank, a beast's name, family and level, where it lives, *teaches nothing* and attack speed. Uncertain data is only shown with *Show uncertain data*, with a **?** right after the value. What only one other player has reported is kept, but no longer shown.
- **New ranks found by others:** when other players tame a beast with a rank the addon doesn't know yet, your game looks up its name and rank. Once enough players saw it, the rank shows up in *Abilities* – with "pet level unknown" until someone finds out more.
- **The beast page shows the right beast:** the 3D model no longer shows a different beast you looked at before, while the game is still loading the new one.
- **Smaller fixes:** the beast page closes when you switch to explorer mode, and the German label of *Show finds of my other characters* is no longer cut off.
- **Privacy:** the self-test of `/fhp share` no longer stores the names of other players, and its log is cleared after a day.
- **More data from the game:** 177 beasts (was 175), 1059 spawn points (was 898), three new teaching beasts for Claw and Bite; Bite is now known for bears and Cower for boars. A few entries reported by only one other player were dropped under the new rule.

## 1.0.0 – 2026-11-05

The first full release, now that WoW Forever is live. Thank you to everyone who hunted with the beta versions so far – what you found is in this version. New features will keep coming as beta versions first, until they are ready for the next full release.

- **Known beasts stay visible:** a beast the addon knows in a zone is no longer hidden there just because a single tooltip named an owner – for example the beasts hunters tame with the taming rod in their class quest. Beasts a player controls or has charmed are never taken as NPC companions, and taming a beast yourself proves it can be tamed on that map. What the addon's data says about a beast is never overruled by a single scan, only extended.
- **First-start window:** the note that the addon is in beta is gone, since this version is a full release.
- **More data from the game:** 175 beasts (was 172), 898 spawn points (was 798) – the first finds from the live servers.

No game restart needed – `/reload` is enough.

## 0.13.0-beta – 2026-10-29

Ready for the launch of WoW Forever on November 5. This version is about collecting: from day one, what hunters find reaches the addon in full.

- **New abilities and ranks found by others are kept:** a taming shared by another player used to be thrown away when it showed a spell the addon doesn't know yet – exactly the finds that are missing most. Now it is kept, and with enough players reporting it, it can become part of the addon's data. Until then it doesn't disprove anything you see. `/fhp share` tells you how many of the tamings from others contain unknown spells.
- **Tamings are matched more carefully:** a new pet only counts as the tamed beast if it shows up within 10 seconds after taming ends. A pet you summon later no longer gets mixed up with the beast you just tamed.
- **Stricter rules for what others report:** a report that reached you without knowing who sent it no longer helps to confirm anything, and an attack speed seen by others only counts once 3 players report it, like everything else.
- **Storage never stops collecting:** when the storage for other players' finds is full, the oldest entries make room for new ones, instead of nothing new being kept.
- **Clearer `/fhp share`:** rejected messages are listed once each, with how often they arrived.
- **More data from the game:** 172 beasts (was 169), 106 teaching beasts (was 107: two uncertain attack speed teachers dropped under the stricter rule, one new), 798 spawn points (was 695).

No game restart needed – `/reload` is enough.

## 0.12.0-beta – 2026-10-22

- **Companions of NPCs are no longer beasts:** a beast whose tooltip names an owner can't be tamed, so it no longer shows up in the *Zone* tab, in tracks or in the beast tooltip, and shared reports about it are ignored. Coming from 0.11.0: a wolf in the Barrens that belongs to an NPC hunter disappears from your lists.
- **New beasts found by others are good news:** when other hunters discovered new beasts in a zone since you last looked, the *Zone* tab tells you so once – instead of your progress quietly dropping from "8 of 8" to "8 of 9".
- **Clearer words for what you know:** tooltip, filters, headers and settings now say whom they mean – *you have it*, *you lack it*, *your pet has it* – instead of "learned" or "new".
- **Not only by colour:** the active tab has a bar below it, and the selected row has a stripe on its left.
- **Sharing explained in the game:** with sharing on, the first-start window and the setting tell you that confirmed observations become part of the addon's data under the MIT license. The first-start window now points to the *Zone* tab instead of a "book" that doesn't exist.
- **Less work in the background:** the *Abilities* list only rebuilds when you open it, not while the window is closed.
- **Calmer hidden channel:** with many players online, only a few answer each greeting, and your own finds are always sent before answers to others. `/fhp share` shows how many answers were sent or skipped.
- **Fixed:** the header of an ability in *Abilities* wraps instead of running past the right edge.
- **More data from the game:** 169 beasts (was 162), 107 teaching beasts (was 105), 695 spawn points (was 626).

No game restart needed – `/reload` is enough.

## 0.11.0-beta – 2026-10-20

- **Every character discovers on its own:** in explorer mode, what your other characters found no longer counts for this one. Prefer the old way? Switch on *Show finds of my other characters* below *Explorer mode* in the settings. Coming from 0.10.0: your main character (most sightings and tamings) keeps its finds, the others start from scratch.
- **Discoveries are celebrated:** in explorer mode, a taming that uncovers something in the *Zone* tab adds a chat line, for example *Discovered: Bite Rank 3 – Duskwood: 5 of 12 ranks*.
- **Explorer mode first:** the first-start window now recommends explorer mode, explains that the addon is in beta, and closing it without a choice starts you in explorer mode. Hover over the mode in the top right corner for a short explanation, click it to open the settings.
- **Uncertain ranks marked in the Zone tab:** in complete mode an uncertain rank carries a **?** there too, as in the beast tooltip, and the counters count what the list shows.
- **More trustworthy names:** a beast name reported by a single other player no longer overrides the known name; it needs 3 players like everything else. *Teaches nothing* from other players also needs 3 players now.
- **Fixed:** demons that cannot be tamed (such as the Felstalker) no longer show up as beasts.
- **Privacy:** shared data that reaches the project is stored in its public repository with the short code replaced by a new, secret one and the time cut to the day. Please don't post your account's SavedVariables file publicly.
- **More data from the game:** 162 beasts (was 134), 105 teaching beasts (was 85), 626 spawn points (was 385), 1 new ability taught by crocolisks.

No game restart needed – `/reload` is enough.

## 0.10.0-beta – 2026-10-18

- **Explorer mode wants to be explored:** the *Zone* tab shows every teaching beast and every ability rank of a zone as a tile – a red question mark until you found it, then its icon. Click a tile to see the beast on the map. Undiscovered beasts invite you to go stalking.
- **The Zone tab follows you:** it opens on your current zone (*Current zone*) and follows you as you travel. The tab is now called *Zone* (was *Area*).
- **New finds show up right away:** with *Current zone* selected in *Abilities*, abilities you just found appear without `/reload`.
- **Help wanted:** in complete mode the beast tooltip tells you when nobody knows yet what a beast teaches – tame it and help out.
- **More trustworthy sharing:** reports from other players only count once they reached you through at least two different players. Received tames are no longer dropped as "invalid", and `/fhp share` names the reason when something is rejected.
- **Fixed:** hunter spells no longer show up in the *Abilities* list; a new ability is recognized on the very first tame; opening *Beast Training* while a vendor, trainer or stable master window is open no longer mixes it up with the pet trainer; no more "No player named … is currently playing" messages when sharing.
- **More data from the game:** 134 beasts (was 69), 85 teaching beasts (was 46), 385 spawn points (was 221), 4 new abilities and 4 new pet families.

No game restart needed – `/reload` is enough.

## 0.9.0-beta – 2026-10-18

- **Shared observations count sooner:** what other players report counts as confirmed once 3 different players saw it (was 10).
- **Spawn points from other players** can now become part of the shipped data once 3 players found them.
- **Names in your language:** beast and family names show in your client's language wherever your game already knows them (tracks, your own pets), and names seen by players with your language need no confirmation.
- **No more false "0 TP":** ranks without a confirmed price show no cost instead of 0 (for example Swipe and Web).
- **Fixed:** the addon logo no longer appears on other pages of the game options, and scrolling the game options (for example *Social*) no longer reports that Forever Hunter Pets was blocked.
- **More data from the game:** 69 beasts (was 30), 52 teaching beasts (was 19), 221 spawn points (was 114).

**Please restart the game once after updating** – a new file was added, and `/reload` does not load it.

## 0.8.0 (beta) – 2026-10-17

First public beta.

- **Complete mode and explorer mode:** see everything that is known, or only what you discovered yourself and how much is still out there.
- **Abilities, Area and Training tabs**, beast tooltips, spawn points on the zone map, tracks and scent for beasts you have not found yet.
- **Collects as you play** – targeting, hovering, nameplates, *Track Beasts*, taming and *Beast Training* – and shares with other players of the addon in the game. `/fhp share` shows what was sent and received.
- Everything the addon knows was found in the game by its players. Shared observations may become part of the shipped data under the MIT license once enough players have confirmed them; only a short code is stored instead of character names.
