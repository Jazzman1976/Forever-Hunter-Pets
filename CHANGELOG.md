# Changelog

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
