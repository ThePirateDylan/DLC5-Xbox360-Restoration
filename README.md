# Zombies Declassified — Xbox 360 Restoration

A work-in-progress project to backport selected DLC5 fixes and improvements to the Xbox 360 version of Call of Duty: Black Ops II. Plutonium is a reference for fixes; Xenia may be used to test Xbox 360 behavior and compatibility. Console-specific testing remains necessary.

## Goal

Produce a small, files-only update that can be copied into an existing Xbox 360 game installation with Aurora File Manager. This repository will not ship a PC installer, a full game, or proprietary DLC5 assets.

The backport should preserve Xbox 360-specific behavior and use only fixes that can be adapted to the console build. Xenia-related fixes and test notes should be kept when they affect compatibility.

## Current test candidate

A local test candidate integrates 47 of the 72 Beta 2 GSC/CSC modules into 13 existing Xbox 360 script assets, using the game's existing Zombies startup path. The test package includes the DLC5 map FastFiles/IPaks and localization, June world-map/UI and August shared-support candidates, both owner-provided launchers, and the Beta 2 `patch_zm.ff`. It does not include the full BO2 base game or `base.ipak`. The candidate's scripts compile, static link and slot checks pass, and its FastFile decodes to an exact copy of the rebuilt zone. It has not been tested in Xenia or on an Xbox 360, so patched-XEX loading and gameplay remain unverified.

See [the current candidate status and test checklist](docs/xbox360-test-candidate-status.md). Build the full local DLC5 test package with `tools/Build-Dlc5TestCandidatePackage.ps1`; it contains 45 game-root files and must be used with a separate copy of a complete base game installation. Its large source assets are hard-linked in `dist/` to avoid a second local copy; copying them to another drive/device transfers the full content.

## Progress

Bars show separate deliverables. Passing file and compiler checks does not mean the candidate has passed runtime testing.

| Work area | Progress | State |
|---|---:|---|
| Beta 2 script modules integrated | `█████████████░░░░░░░` 47/72 (65%) | 25 modules are held back for the reasons below. |
| Existing Xbox script payloads compiled, linked, and fit | `████████████████████` 13/13 (100%) | Static import/arity and payload-slot checks pass. |
| Full DLC5 test package files checksum-verified | `████████████████████` 45/45 (100%) | The package is ready for a separate base-game test copy. |
| Runtime test in Xenia or on Xbox 360 | `░░░░░░░░░░░░░░░░░░░░` 0/1 (0%) | Launch, FastFile acceptance, and gameplay are still unverified. |

## Why modules are skipped and what comes next

| Held-back work | Count and reason in this version | Next step |
|---|---|---|
| Dog behavior | 2 scripts replace full stock payloads and exceed their Xbox slots. | Rewrite as smaller targeted edits to compatible stock scripts; include only if the result fits and passes compile, import, and slot checks. |
| Plutonium hooks and APIs | 11 modules depend on dynamic function lookup/replacement or hooks that the scanned Xbox scripts do not provide. | Replace them with static calls to verified stock functions or implement a compatible Xbox/map hook, then validate imports and required assets. |
| M27 weapon box | 1 module depends on an unverified Xbox `hk416_zm` variant plus sound and localization assets. | Verify or backport the matching Xbox weapon and supporting assets before enabling the module. |
| Prototypes | 3 modules are prototype experiments without an identified release gameplay need. | Keep them out unless a concrete gameplay fix depends on one. |
| Diagnostic probes | 5 modules are investigation tools, not player-facing fixes. | Keep them development-only; do not include them in a gameplay package. |
| Fog behavior | 3 modules require a missing fog API or a map-specific hook. | Port to an Xbox-supported fog control or add a compatible map hook, then test each affected map. |

These counts cover the 25 excluded Beta 2 script modules. Other Beta 2 changes also modify map assets and platform-specific models, textures, animations, audio, localization, and menus. Those PC files cannot be copied into an Xbox package as-is. The current overlay contains the available Xbox DLC5 map files and earlier Xbox UI/support candidates, but not all Beta 2 asset changes. The next asset work is to compare the remaining changes against Xbox source files, make Xbox-compatible asset edits or rebuilds, and validate them map by map. The [candidate status document](docs/xbox360-test-candidate-status.md) has the detailed module list and manual test checklist.

The `main` branch changes are already in this checkout's history. The active branch is one checkpoint commit ahead of `main`; no merge is needed for this work.

## Local working files

Use `local-input/` for privately supplied source files and build/test material. Use `package/staging/` with `tools/Build-AuroraPackage.ps1` for general transfer packages. Use `tools/Build-Dlc5TestCandidatePackage.ps1` for the full DLC5/Beta 2 test package and `dist/` for generated packages. These paths are ignored by Git so proprietary game files and local generated packages are not committed.

Only add files needed for the backport. Keep original game files and backups in their existing locations; do not put them in the repository or its history.

## Credits and scope

See [CREDITS.md](CREDITS.md) for attribution. This is an unofficial fan project and is not affiliated with Activision, Treyarch, or the Plutonium team. All trademarks and copyrights belong to their respective owners.
