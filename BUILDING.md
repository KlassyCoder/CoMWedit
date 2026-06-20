# Building CoMWedit from source

CoMWedit is written in Free Pascal and built with Lazarus.

## Requirements

- **Lazarus** (tested with 3.2.2) with Free Pascal.
- Build target must be **32-bit (i386 / win32)**. The editor is a 32-bit
  Windows program; a 64-bit build is not supported.

## Build

From the Lazarus IDE: open `CasterEditor.lpi` and Build (Run -> Build).

Or from the command line:

    lazbuild CasterEditor.lpi

The output is `CoMWedit.exe`. For a clean rebuild, delete the generated `lib/`
folder first and run `lazbuild -B CasterEditor.lpi`.

## What the source contains

- `CasterEditor.lpr` — the GUI (the whole editor, built in code).
- `SaveModel.pas` — typed read/write accessors over the save data.
- `SaveFile.pas` — reads/writes the `.SAV` (a zip containing `save.tmp`).
- `Offsets.pas` — the byte offsets of editable fields within the save.

The editor reads and writes save files directly. It does not require the game
or its DLL to run.
