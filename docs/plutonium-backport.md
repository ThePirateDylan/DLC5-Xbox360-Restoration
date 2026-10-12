# Plutonium DLC5 fixes: Xbox 360 backport status

## Reference set

The Plutonium-side reference is Zombies Declassified Beta 2, tag `beta2`, commit `6b98da9`, and its companion `beta2-data` release. The release notes describe fixes for the nine DLC5 maps; the data release contains 278 PC assets, including PC FastFiles, IPaks, sound banks, localization, menu Lua, and 72 GSC/CSC scripts.

Sources:

- https://github.com/Logo-2K/zombies-declassified/releases/tag/beta2
- https://github.com/Logo-2K/zombies-declassified/releases/tag/beta2-data
- https://github.com/xensik/gsc-tool
- https://github.com/Laupetin/OpenAssetTools/issues/298

The PC release's `.ff`, `.ipak`, `.sabl`, and `.sabs` files are not Xbox 360 replacements. They are built for the PC engine/platform and cannot be copied into this console package as-is.

## Fix inventory from Beta 2

Map aliases below match the August prototype filenames in `local-input/dlc5-alpha`.

- All maps: AN-94 price normalized to 1600; per-map weapon lists corrected; Ray Gun Mark II added to each mystery box with its sounds and spin display; box contents corrected to remove unavailable or unintended weapons; voice-line remaps, Samantha box laugh, normal footstep levels, and Pack-a-Punch audio isolated from retail maps.
- Verrückt (`zm_asylum`): brightness increased 25%; intro card corrected; Thundergun removed.
- Shi No Numa (`zm_sumpf`): perk-purchase sting restored; Hellhounds audible at original distances (also Der Riese).
- Der Riese (`zm_factory`): claymores no longer damage their owner.
- Kino (`zm_theater`): crawler death gas/damage timing corrected; headshot kills do not release gas; early crawlers wait for curtains and player entry; Mob death-song mix-up removed; Five window-glass sound restored.
- Five (`zm_pentagon`): teleport/elevator transitions stop spawns in the area left; crawler behavior corrected; electric traps zap once per second and respect Juggernog; lobby no longer darkens after power.
- Ascension (`zm_cosmodrome`): brightness increased 25%; centrifuge damage/rumble and restart timing corrected; long-lived out-of-map crawler requeued; lander and Thundergun camo corrected.
- Shangri-La (`zm_temple`): monkey/napalm behavior corrected; crawler requeue; slide speed and pool-drop damage corrected; grenade wall-buy gives Semtex while spawn grenade remains frag; Spikemores trigger on zombie contact.
- Moon (`zm_moon`): Area 51 perks enabled from start; hacked wall-buys use reduced ammo price; crawler kills award points; R870 label corrected; gravity adjusted for high frame rates.
- Weapons: MP40 BO2 model/textures/animations; STG-44 BO2 model/textures/animations and reload details; FAL OSW reload/EPC magazine fixes; M27 added to the box on Verrückt and Shi No Numa with sound set; monkey-bomb pull-pin/throw animations; Wunderwaffe reload/raise animation recompiled.
- Menus and presentation: scoreboard map logos; map descriptions/art; Solo Play globe entries (currently route through Custom Games); language-specific character/announcer/power-up lines.

Known Beta 2 limitations to retain in test notes: Solo Play does not use the native solo flow; Moon and Shangri-La MP40 reload foley remains silent; some weapons lack original reload/handling audio; Der Riese windows remain opaque; Moon can still damage players during powered-up zone crossings.

## Work completed locally

- Downloaded only the 72 small GSC/CSC script assets from the public Beta 2 data release (about 145 KiB total); no PC map binaries, full game files, or archives were downloaded.
- The Xbox-target compile workflow uses T6 / Xbox 360 (`xb2`) and verifies script VM revision 6. The latest candidate build used the locally available GSC Tool 1.4.10.333 (recorded in its manifest); older notes referring to 1.6.0.360 do not describe this candidate build. The PC script `zzz_zm_exertvoice.gsc` needs a local compiler-compatibility rewrite from `getdvarint` to the equivalent `getdvar("killvox") == "0"` check. Original downloaded source remains unchanged, and this rewrite still needs runtime confirmation.
- The compiled objects are retained under the ignored `local-input/plutonium-beta2-xb2-script-objects/` folder for further integration work. They are research/build outputs, not an installable package and have not been tested in-game.
- The 72 original script inputs are hash-verified against the upstream Beta 2 manifest and kept under ignored `local-input/plutonium-beta2-source/`; the one Xbox-specific compile copy is under `local-input/plutonium-beta2-xb2-script-source/`.
- Added `tools/Build-PlutoniumXboxGsc.ps1` to reproduce the Xbox-target compilation and verify VM headers without overwriting conflicting output. Run it with `-GscToolPath <path-to-gsc-tool.exe>` after placing the upstream scripts in the ignored source folder.
- The earlier June/August package did not include the Beta 2 script backport. The current test package combines its DLC5 map and UI/support assets with the rebuilt Beta 2 `patch_zm.ff`; details are in `docs/xbox360-test-candidate-status.md`.

## Test-only in-game script candidate

A local FastFile workflow now exists using the Crybaby T6 scanner/repacker under ignored `local-input/crybaby-t6-linker-tool/`. The test builder is `tools/build_beta2_script_backport.py`. It copies an unpacked existing Xbox 360 `patch_zm` scan, compiles compatible Beta 2 GSC/CSC code for T6/Xbox 360, and fits it into already allocated ScriptParseTree slots without shifting neighboring zone data.

The latest test candidate is `local-input/crybaby-test/candidates/patch_zm_beta2_scriptbackport_j.ff`. It incorporates 47 of the 72 Beta 2 script modules into 13 existing script assets. Selected Plutonium `GetFunction` lookups, including the MkII box helpers, are rewritten as static calls to stock script functions. The server dispatcher is called from the existing Zombies `_zm.gsc::init()` entrypoint, and the client dispatcher from `_zm.csc::init()`; the design does not require a separate GSC loader. Generated editable sources are kept in `local-input/crybaby-test/beta2_script_backport_scan_20261012j`, and its manifest records module assignments, exclusions, and build input hashes. The local test package contains all nine DLC5 map FastFiles/IPaks and English localization files, June world-map/UI candidates, August shared-support candidates, both owner-provided launchers, and this Beta 2 `patch_zm.ff`.

Build checks passed: all edited scripts compile for XB2 with the locally available GSC Tool 1.4.10.333; static link regression reports no missing qualified imports or argument-count mismatches; every edit fits its original payload slot (minimum remaining slack 806 bytes); and the repacked FastFile decodes to an exact copy of the candidate zone. The repacker emits an unsigned TAffu100/dev-loader-style file. Its XEX-level acceptance has not been verified, so the new unqualified engine imports have not been confirmed against the launcher's runtime. These are file-level checks only; neither Xenia nor a console has confirmed loading or gameplay.

The remaining 25 modules and reasons are listed in `docs/xbox360-test-candidate-status.md`. Two full dog-script replacements do not fit their existing Xbox slots; unsupported Plutonium APIs and map-specific hooks, prototypes, and diagnostic probes are also excluded. `zzz_zm_m27box.gsc` is held back because the required Xbox weapon variant and supporting assets could not be verified. Other Beta 2 fixes need map FastFile edits or Xbox versions of models, textures, animations, audio, localization, and menu assets. The PC asset release is not a usable Xbox replacement. The current candidate is local-only; no original game file, archive, or backup was overwritten.

## Remaining verification

The no-separate-loader startup path is a static in-game script integration, not proof that the console will load the rebuilt FastFile. Before packaging, the exact `patch_zm.ff` placement and patched-XEX behavior must be confirmed, then the candidate needs a runtime boot/map test. The remaining script hooks and non-script assets must be ported separately; this candidate is a partial script backport, not all Plutonium fixes.
