# Notices and credits

Forever Hunter Pets is a fan project. It is not affiliated with, endorsed by or sponsored by
Blizzard Entertainment.

## What the MIT license covers

The [MIT license](LICENSE) covers the **code** of this project – the addon and the scripts in
`tools/` –, the **data collected in game** in `tools/eigene/` and `Data/Data.lua`, and the **logo**
in `media/`. Copyright (c) 2026 Elmar Höfinghoff.

The logo was created for this project with AI image generation (ChatGPT). It contains no Blizzard Entertainment image. To the extent that rights in it exist, they are released under the MIT license as well.

## Where the data comes from

Every entry in the data was collected in the game itself, by the maintainer and by players of the
addon:

- **Beast Training window and pet trainer** – abilities, ranks, spell IDs, pet levels, training
  points, which family can learn what
- **Targeting a beast** – NPC ID, name, level, classification and family
- **Taming a beast** – which abilities and attack speed it actually brought along
- **Where a beast stood** – the player's position when close to the beast, rounded to about 2 % of
  the map

Players of the addon share what they observe in game over addon messages. Only a short code is
stored instead of a character name. Each entry in `tools/eigene/` carries its evidence; the details
are in [docs/technik/quellen.md](https://github.com/Jazzman1976/Forever-Hunter-Pets/blob/main/docs/technik/quellen.md) (German).

No data from websites or other addons is included.

## Blizzard Entertainment

World of Warcraft, Warcraft and Blizzard Entertainment are trademarks or registered trademarks of
Blizzard Entertainment, Inc. Names of abilities, creatures, zones and pet families, ability
descriptions, icons, maps and creature models are © Blizzard Entertainment, Inc.

The addon reads ability names, descriptions, icons, zone names, map art and creature models from the
game client at runtime. No icon, map or model file is shipped with this project. Names stored in the
data are the ones the client showed when they were collected.

Screenshots in the documentation show the addon inside the game; the game interface, icons, map and
model visible in them are © Blizzard Entertainment, Inc.

## Third-party software

The addon uses no third-party libraries and contains no code from other addons.
