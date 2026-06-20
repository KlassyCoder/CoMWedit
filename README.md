# Source — Caster of Magic Savegame Editor

Early scaffolding. See `../docs/design.md` for the full plan.

## Files
- `CasBind.pas` — dynamic binding to the game's `CasApi.dll` (minimal; grows over time).
- `protoA.lpr` — **Prototype A**: load a save, edit wizard 0's gold/mana, save it back.

## Toolchain (not yet installed on this machine)
Built with **Free Pascal / Lazarus**, targeting **32-bit (i386)** — the game's `CasApi.dll`
is 32-bit, so a 64-bit build will not load it.

- Download Lazarus (bundles FPC): https://www.lazarus-ide.org/  — the standard Windows
  installer is 32-bit, which is what we want.

## Build & run Prototype A
From a terminal once FPC is on PATH:

```
fpc -Px86 protoA.lpr
./protoA.exe
```

`protoA` sets its working directory to the game folder itself (so the DLL and the game's
`Data\` files are found), then writes `PROTOA_TEST.SAV` into the game folder. Load that save
in the game to confirm wizard 0 has 9999 gold/mana.

## Key facts baked into the binding
- DLL exports 914 functions by **plain undecorated names** → `GetProcAddress` by name works.
- Engine lifecycle: `GameInitialize` → `Loadgame2` → (edit) → `Savegame` → wait for
  `SaveInProgress` to clear → `CloseGame`.
- `Savegame` is asynchronous (background thread, ~200 MB per save); always wait before exit.
- The game install path is currently **hard-coded** in `protoA.lpr` — make it configurable
  before release.
