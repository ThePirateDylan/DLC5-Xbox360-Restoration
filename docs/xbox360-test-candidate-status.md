# Xbox 360 Beta 2 test candidate

## Current artifact

The local candidate is `local-input/crybaby-test/candidates/patch_zm_beta2_scriptbackport_j.ff` (3,483,904 bytes; SHA-256 `042df45fbc188ac8f1d58a7e463156bc2d1a3d05c34a14b7398828ac2e0d9673`). The full local test package is created by `tools/Build-Dlc5TestCandidatePackage.ps1` under ignored `dist/`. It contains 45 game-root files: nine DLC5 map FastFiles, their nine IPaks and English localization, the June world-map/UI and August shared-support candidates, both owner-provided launchers, and this Beta 2 `patch_zm.ff`. Its logical size is about 2.22 GiB. The large map/support inputs are hard-linked into `dist/` so this local package does not duplicate them on the same drive.

Use the package only with a separate copy of a complete Xbox 360 BO2 base installation. The full base game, its `base.ipak`, and a title update are not included. The package's `INSTALL.txt` has the copy paths and a manual test checklist. It has not been tested in Xenia or on Xbox hardware.

## What is integrated

The candidate integrates 47 of the 72 Beta 2 GSC/CSC modules into 13 existing Xbox 360 script payloads. Server and client dispatch calls are attached to the existing Zombies initialization functions in `_zm.gsc` and `_zm.csc`; no separate loader is assumed. `zzz_zm_mk2box.gsc` is included after replacing two Plutonium dynamic lookups with static references to stock Xbox functions.

The current build used GSC Tool 1.4.10.333 targeting T6/Xbox 360. The manifest records hashes of the compiler, unpacker, source inputs, overrides, builder, and input zone. Compilation and payload-slot checks passed; the smallest remaining slot slack is 806 bytes. The static import/arity regression reported zero missing imports or argument-count mismatches. Repacking and decoding produced an exact zone round trip (SHA-256 `119291cecfa4e44a2b21c7f7e598843c38f299200cc6f0d4762b85f9c9324c84`).

These checks establish candidate file consistency only. The rebuilt FastFile has an unsigned TAffu100/dev-loader-style representation. It is not known whether `default_mp_patched.xex` accepts it, whether it loads from the expected path, or whether the script changes behave correctly in-game. The runtime import list is not confirmed against the XEX.

## Modules held back

The complete module-by-module reasons are in the generated `CANDIDATE-NOTES.txt` and `local-input/crybaby-test/beta2_script_backport_scan_20261012j/beta2_script_backport_manifest.json`.

| Reason | Modules |
|---|---|
| Full script replacement exceeds the existing Xbox payload slot | `zm_dog_combat.gsc`, `zm_dog_stop.gsc` |
| Needs a Plutonium-only API (`GetFunction`, `replaceFunc`, or other dynamic/hook API) | `zzz_cabinet.gsc`, `zzz_protonames.gsc`, `zzz_zm_eggsong.gsc`, `zzz_zm_factorytelevox.gsc`, `zzz_zm_howlparity.gsc`, `zzz_zm_moonintercom.gsc`, `zzz_zm_quaddescent.gsc`, `zzz_zm_quadvo.gsc`, `zzz_zm_templespike.gsc`, `zzz_zm_watersheet.gsc`, `zzz_zz_zzzzzzzsumpfshuffle.gsc` |
| Requires an unverified Xbox weapon variant and supporting assets | `zzz_zm_m27box.gsc` |
| Prototype only | `zzz_protoround.gsc`, `zzz_zm_barrelsound.gsc`, `zzz_zm_location.gsc` |
| Diagnostic probe, not a gameplay backport | `zzz_zm_centrifugewatch.gsc`, `zzz_zm_crawlerwatch.gsc`, `zzz_zm_cscprobe.csc`, `zzz_zm_gravitywatch.gsc`, `zzz_zm_whereami.gsc` |
| Requires a missing API or map-specific hook | `zzz_zm_dogfog.csc`, `zzz_zm_factoryfog.csc`, `zzz_zm_sumpffog.csc` |

The MkII box module is statically linked, but the M27 box module is excluded because the supplied Xbox scans do not verify the `hk416_zm` variant and its sound/localization assets. The Temple Spikemore helper points to a function absent from the scanned stock zones. These are blockers pending matching Xbox assets or a compatible implementation.

Other Beta 2 changes involve edits to map FastFiles or platform-specific models, textures, animations, sound, localization, and menu assets. PC `.ff` and `.ipak` files are not Xbox replacements and are not in this overlay.

## Test procedure

1. Make or use a separate complete copy of the Xbox 360 BO2 base game. Keep the original game copy untouched.
2. Back up any existing files in the test copy's game root, then copy every file under package `game-root/` into that root, preserving filenames. Keep the base game's `base.ipak` and all other base files in place.
3. Launch `default_mp_patched.xex` from the test copy with Aurora File Manager. Do not replace or launch `default_mp.xex` for the first Beta 2 test. `default_mp_nosound.xex` is included for a separate comparison run.
4. Check that the world-map UI lists the DLC5 maps and that each of the nine maps loads without FastFile, IPak, missing-asset, or script errors. `zm_prototype` is Nacht der Untoten.
5. In Custom Games, check Moon (`zm_moon`) for Area 51 perks from the start and reduced hacked wall-buy ammo pricing. On Shangri-La (`zm_temple`), check that the grenade wall-buy gives Semtex while the spawn grenade remains a frag.
6. Record any launch/load error, crash, missing asset, or behavior difference. If a test fails, discard the test copy or restore its changed files from the backups.

## Project state

The active branch is one checkpoint commit ahead of `main`; `main` is already in its history, so no merge is required for this candidate. The test overlay and local inputs are generated/private files and must remain outside Git history. No commit or push has been made.
