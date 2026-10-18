# Contributing

Thanks for your interest. Bug reports, findings from the game and pull requests are welcome. Please keep it friendly and on topic – see the [Code of Conduct](CODE_OF_CONDUCT.md).

What is planned and in progress: [milestones](https://github.com/Jazzman1976/Forever-Hunter-Pets/milestones) and the [project board](https://github.com/users/Jazzman1976/projects/2).

The project documentation, code comments and commit messages are in **German**, and so are the issues the maintainer opens. Please open issues and pull requests in English (or German, if you like) – an issue opened in English is discussed in English.

## Collecting data

The data is collected in game. The simplest way to contribute is to play with the addon and leave **Share observations** switched on: what you see when you target or tame a beast, and what your Beast Training shows, reaches other players of the addon. Shared observations may become part of the shipped data under the [MIT license](LICENSE), with a short code instead of your character name (details in the [README](README.md#data-and-license)).

## Reporting a problem

Open an [issue](https://github.com/Jazzman1976/Forever-Hunter-Pets/issues/new/choose) – the forms for bugs and data findings help, but every field is optional and a plain issue is fine too. Useful to include:

- the addon version (shown in chat at login) and your client language
- what you did, what you expected and what happened
- for wrong data: the ability, rank and beast (with its NPC ID if you can), and what you saw in game

Please do not edit `Data/Data.lua` or `tools/data.json` by hand – both are generated from `tools/eigene/`.

## Changing code

1. The project follows [GitFlow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow). Every change has an issue – open one if there is none. Branch from `develop` as `feature/<issue number>-<issue-title-as-slug>` (for example `feature/3-tiernamen-in-der-sprache-des-clients`) and open your pull request against `develop`. Commit messages follow `#<issue number> <issue title> => <what the commit does>`. The pull request explains what changed, why, and what the consequences are. `main` only receives releases. Both branches are protected: changes go in by pull request and need one approval from the maintainer.
2. Read [docs/technik/entwicklung.md](docs/technik/entwicklung.md) for setup and testing, [docs/technik/addon-technik.md](docs/technik/addon-technik.md) for how the addon is built, and [docs/konzept/konzept.md](docs/konzept/konzept.md) for the concept and the decisions behind it.
3. Keep a change small enough to be tested in game in one go.
4. Say in the pull request what you tested and how – in game, or only with the offline checks.

## Rules that are not negotiable

- **Only data collected in game.** Every entry in `tools/eigene/` needs its evidence (`beleg`, or `quelle` and `datum`). Data from websites or other addons does not go in – not even as a starting point.
- **No third-party libraries in the addon, and no code from other addons.** Prefer what the game client provides at runtime, even if that is less convenient.
- **Generated files are not edited by hand:** `tools/data.json` and `Data/Data.lua`.
- **No state is shown by colour alone** – always add a symbol or a word.

## License of contributions

By contributing you agree that your contribution – code or data – is released under the [MIT license](LICENSE) of this project.
