# CoMWedit — Caster of Magic for Windows Save Editor

A savegame editor for Master of Magic: Caster of Magic for Windows (the Steam release). It edits the
values stored in your saved games.

This is only for Caster of Magic for Windows — not the original DOS Master of Magic or other versions.

## Links

- **Home page (start here):** https://klassgaming.com/comwedit.html
- **Download:** https://klassgaming.itch.io/comwedit
- **Mailing list** (get notified about updates): https://klassgaming.com/mailing-list.html

This repository holds the source code. If you just want to use the editor, grab it from the download
link above.

## Features

Wizards (yours and the AI players'):
- Gold, mana, casting skill, fame
- Disposition toward you, −100 to +100 (AI wizards)
- Number of spellbooks per realm
- Retorts (on/off)
- Spell status: unknown, researchable, or known

Cities:
- Name, owner, race, population

Map:
- A clickable minimap of both planes
- Add or remove a tile's resource (ore, gems, wild game, nightshade, etc.)
- Add or remove corruption on a tile

Heroes:
- For a chosen wizard and hero, turn abilities on or off, including super versions where they exist

Spell, hero, ability, and retort names are read from the game's data files, so they match any mods
you have installed.

## Requirements

- Windows, on the PC where the game is installed
- Caster of Magic for Windows

It is a single program; there is no installer or other files to set up.

## Running it

1. Run CoMWedit.exe. It locates the game folder on its own. If it can't, it asks you to point it to
   the folder that contains Spells.dat, then remembers it.
2. Choose a save from the dropdown and click Load.
3. Edit values on the Wizards, Cities, Map, and Heroes tabs.
4. Click Save, then load that save in the game.

## Notes

- Save overwrites the slot you chose. The first time you save a slot, it backs up the original to
  `<slot>.bak` and keeps that copy (it is not overwritten by later saves). Save As writes to a
  different slot instead.
- The game only lists saves named like its own slots (1.sav–8.sav, QUICKSAVE.SAV, etc.) in its load
  menu. A custom name from Save As will not show up there.
- Do not save a slot in the editor at the same moment the game is writing that slot.
- CoMWedit changes save files only, not the game itself.
- Changing a city's race can leave it with buildings that race cannot normally build. This is usually
  harmless in the game.
- Stacking a large number of retorts on a single wizard can cause the game to crash when viewing the
  mirror (default F9 key), but the retorts will still take effect.

## Not included in this version

- Reroll (generating a new map and opponents with the same game settings) is planned for a later
  version.
- Terrain editing is planned for a future version.

## Troubleshooting

- "Windows protected your PC" on first run: this appears for unsigned programs. Click More info, then
  Run anyway. Scan the file first if you prefer.
- No saves listed, or it keeps asking for the folder: point it to your game folder (the one
  containing Spells.dat). The choice is saved in CoMWedit.ini next to the program.
- A change did not appear in the game: confirm you clicked Save in the editor and then loaded that
  same slot in the game.

## Building from source

See [BUILDING.md](BUILDING.md). In short: open `CasterEditor.lpi` in Lazarus and build for 32-bit
(i386), or run `lazbuild CasterEditor.lpi`.

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

Unofficial fan-made tool, not affiliated with the game's developers. Use at your own risk and keep
backups of saves you care about.

Version 1.0
