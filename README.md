# Zombies Declassified — Xbox 360 Restoration

A work-in-progress project to backport selected DLC5 fixes and improvements to the Xbox 360 version of Call of Duty: Black Ops II. Plutonium is a reference for fixes; Xenia may be used for preliminary compatibility testing. Console-specific testing remains necessary.

## Goal

Produce a small, files-only update that can be copied into an existing Xbox 360 game installation with Aurora File Manager, without requiring a separate GSC loader. This repository will not ship a PC installer, a full game, or proprietary DLC5 assets.

The backport should preserve Xbox 360-specific behavior and use only fixes that can be adapted to the console build.

## Experimental Beta 2 script candidate

A broad local candidate integrates 47 of the 72 Beta 2 GSC/CSC modules into 13 existing Xbox 360 script assets, but it black-screened on console and remains excluded. The one-module Moon candidate also black-screened and is withdrawn. The four-fix Moon candidate used XMem/LZX `TAffx100` and decoded back to the exact edited zone, but it also black-screened in the user's console test. Its signature bytes were copied from the August file, not regenerated. No rebuilt FastFile is currently console-validated. See [the FastFile investigation](docs/fastfile-container-investigation.md). The known-good August `patch_zm.ff` and its matching `.ipak` remain the baseline pair.

The broad 47-module Beta 2 FastFile remains excluded. Its source candidate is local-only in ignored `local-input/` for further debugging. See [the candidate status](docs/xbox360-test-candidate-status.md) for runtime findings.

## Console test package status

The [Moon four-fix LZX test package](dist/ZombiesDeclassified-Xbox360-Moon-4Fix-LZX-Test-20261012/INSTALL.txt) black-screened and is withdrawn; do not copy it again. It contained only `patch_zm.ff` and the matching August `patch_zm.ipak`, with no map art or menu UI. The unchanged signature is the leading suspected cause, though the exact console rejection point is not proven. Beta 2 map art and menu UI remain a separate conversion task; see [the UI asset port notes](docs/beta2-ui-asset-port.md).

## Progress

Bars show separate deliverables. Passing file and compiler checks does not mean the candidate has passed runtime testing.

| Work area | Progress | State |
|---|---:|---|
| Broad candidate Beta 2 script modules integrated (excluded) | `█████████████░░░░░░░` 47/72 (65%) | 25 modules are held back for the reasons below; this candidate black-screened. |
| Broad candidate Xbox script payloads compiled, linked, and fit | `████████████████████` 13/13 (100%) | Static import/arity and payload-slot checks pass; this is not a runtime result. |
| Historical Beta 2 package files checksum-verified | `████████████████████` 45/45 (100%) | File checks passed before console testing; the candidate black-screened and its generated package was removed. |
| Targeted Moon Area 51 script candidate | `████████████████████` 1/1 (100%) | One Beta 2 module compiles and fits, but the package black-screened and is withdrawn. |
| Follow-on Moon scripts integrated and compiled | `████████████████████` 4/4 (100%) | Four modules statically integrate into existing script assets, with 912 bytes of minimum slot slack. |
| XMem/LZX FastFile round trip | `████████████████████` 2/2 (100%) | Both decode byte-for-byte locally; the four-fix candidate still black-screened on console, so the local round trip did not validate the loader format or signature. |
| Shared map loading recovered | `████████████████████` 1/1 (100%) | Restoring the known-good `patch_zm.ff` and matching `.ipak` lets a stock map and The Giant load in the test copy. |
| Targeted Moon package checksums | `████████████████████` 2/2 (100%) | Checksums passed, but the package black-screened and is withdrawn. |
| Four-fix Moon package checksums | `████████████████████` 2/2 (100%) | New two-file LZX package checksums pass; original signature bytes were reused and not validated. |
| Beta 2 world-map UI and art port | `░░░░░░░░░░░░░░░░░░░░` 0/1 (0%) | The old placeholder bundle was removed; Beta 2 art is not yet converted to Xbox IPak form. |
| Targeted Moon runtime verification | `░░░░░░░░░░░░░░░░░░░░` 0/1 (0%) | User tested the one-module package; it black-screened. |
| Four-fix Moon runtime verification | `░░░░░░░░░░░░░░░░░░░░` 0/1 (0%) | User tested it; it black-screened. None of the four behaviors could be checked. |
| Any rebuilt FastFile accepted on console | `░░░░░░░░░░░░░░░░░░░░` 0/3 (0%) | Both earlier `TAffu100` candidates and the `TAffx100` four-fix candidate black-screened. |

## Why modules are skipped and what comes next

| Held-back work | Count and reason in this version | Next step |
|---|---|---|
| Dog behavior | 2 scripts replace full stock payloads and exceed their Xbox slots. | Rewrite as smaller targeted edits to compatible stock scripts; include only if the result fits and passes compile, import, and slot checks. |
| Plutonium hooks and APIs | 11 modules depend on dynamic function lookup/replacement or hooks that the scanned Xbox scripts do not provide. | Replace them with static calls to verified stock functions or implement a compatible Xbox/map hook, then validate imports and required assets. |
| M27 weapon box | 1 module depends on an unverified Xbox `hk416_zm` variant plus sound and localization assets. | Verify or backport the matching Xbox weapon and supporting assets before enabling the module. |
| Prototypes | 3 modules are prototype experiments without an identified release gameplay need. | Keep them out unless a concrete gameplay fix depends on one. |
| Diagnostic probes | 5 modules are investigation tools, not player-facing fixes. | Keep them development-only; do not include them in a gameplay package. |
| Fog behavior | 3 modules require a missing fog API or a map-specific hook. | Port to an Xbox-supported fog control or add a compatible map hook, then test each affected map. |

These counts cover the 25 excluded Beta 2 script modules from the broad candidate. The four-fix package was a script-only backport; other gameplay changes, map art, UI descriptions, models, textures, animations, audio, and localization remain out. PC files cannot be copied into an Xbox package as-is. Do not test another rebuilt FastFile until its signature/trust path and console loading are established. The [handoff report](docs/handoff-progress-2026-10-12.md) compares this work with the previous agent's state.

## Compatibility and limitations

This is a partial backport of an unfinished upstream project. Some features need Plutonium APIs, Xbox-compatible script hooks, map-specific changes, or console-built assets. Features that cannot be adapted reliably may remain unsupported. Passing emulator tests would not replace testing on real Xbox 360 hardware.

The `main` branch is already in this branch's history; no merge from `main` is needed for this candidate.

## Local working files

Use `local-input/` for privately supplied source files and build/test material. Use `package/staging/` with `tools/Build-AuroraPackage.ps1` for general transfer packages. The regular package builders refuse unvalidated candidates. `tools/Build-Dlc5MoonPlusTestPackage.ps1` produced the four-fix package that black-screened; its explicit `-AllowUnverifiedSignature` option does not make the output test-ready. Do not rebuild or distribute that candidate. The older `tools/Build-Dlc5UiMapTestPackage.ps1` outputs only the rejected June placeholder UI bundle; do not use it as a Beta 2 test build. Keep generated packages in ignored `dist/` so proprietary game files stay out of Git.

Only add files needed for the backport. Keep original game files and backups in their existing locations; do not put them in the repository or its history.

## Credits and scope

See [CREDITS.md](CREDITS.md) for attribution. This is an unofficial fan project and is not affiliated with Activision, Treyarch, or the Plutonium team. All trademarks and copyrights belong to their respective owners.
