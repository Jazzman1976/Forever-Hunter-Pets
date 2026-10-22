# Changelog

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
