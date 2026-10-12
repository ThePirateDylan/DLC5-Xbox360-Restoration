# Zombies Declassified — Xbox 360 Restoration

A work-in-progress project to backport selected DLC5 fixes and improvements to the Xbox 360 version of Call of Duty: Black Ops II. Plutonium is a reference for fixes; Xenia may be used to test Xbox 360 behavior and compatibility. Console-specific testing remains necessary.

## Goal

Produce a small, files-only update that can be copied into an existing Xbox 360 game installation with Aurora File Manager. This repository will not ship a PC installer, a full game, or proprietary DLC5 assets.

The backport should preserve Xbox 360-specific behavior and use only fixes that can be adapted to the console build. Xenia-related fixes and test notes should be kept when they affect compatibility.

## Current state

- The current checkout does not yet contain Xbox 360 DLC5 source files or a finished payload.
- The former PC updater and PC server instructions were removed from this working branch; they remain available on `main`.
- Package paths and install instructions will be finalized after checking the target Xbox 360 game layout.

## Local working files

Use `local-input/` for privately supplied source files and Xenia test material. Use `package/staging/` for the project files that are ready to be packaged, preserving their paths relative to the game directory. Use `dist/` for generated transfer packages. These paths are ignored by Git so game files and generated packages are not accidentally committed.

Only add files needed for the backport. Keep original game files and backups in their existing locations; do not put them in the repository or its history.

## Credits and scope

See [CREDITS.md](CREDITS.md) for attribution. This is an unofficial fan project and is not affiliated with Activision, Treyarch, or the Plutonium team. All trademarks and copyrights belong to their respective owners.
