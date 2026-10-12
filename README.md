# Zombies Declassified — Xbox 360 Restoration

A work-in-progress project to adapt selected fixes and imporvements from Zombies Declassified / Plutonium Beta 2 for Call of Duty: Black Ops II Zombies.

## Goal

The goal is to provide a small, files-only update that can eventually be transferred into an existing Xbox 360 game installation using Aurora File Manager, without requiring a separate GSC loader.
The project prioritizes compatibility with the original Xbox 360 game, preserving its existing startup behavior, and adapting only fixes that can be supported by the console environment.

## Current state

- Xbox 360 backport development is ongoing.
- An experimental FastFile candidate has been built with a subset of the identified Beta 2 script modules.
- Build-level checks have passed for the current candidate, including Xbox-target script compilation, static-linking, script slot-size checks, and FastFile repacking and decoding.
- The patched executable's compatibility with the candidate has not been confirmed.
- Xbox 360 boot and in-game Zombies functionality remain unverified.
- Additional script hooks, map-specific work, and compatible assets may still be required.

## Compatibility and Limitations

This is a partial back port of an unfinished upstream project. Not every PC-side fix can be transferred to Xbox 360.

Some features may requires unavailable Plutonium APIs, console-compatible script hooks, map-specific changes, or assets built for the Xbox 360 version. Features that cannot be adapted reliably may remain unsupported. 

Xenia may be useful for preliminary compatibility testing, but successful emulator testing would not replace testing on real Xbox 360 hardware.

## Credits and scope

See [CREDITS.md](CREDITS.md) for attribution. This is an unofficial fan project and is not affiliated with Activision, Treyarch, or the Plutonium team. All trademarks and copyrights belong to their respective owners.
