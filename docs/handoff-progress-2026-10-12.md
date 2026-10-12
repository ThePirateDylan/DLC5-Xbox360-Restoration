# DLC5/Beta 2 handoff report — 2026-10-12

## Current state

The full local test package is at `dist/ZombiesDeclassified-Xbox360-DLC5-Beta2-Test-042df45fbc18/`. It has 45 game-root files and a logical size of 2,381,966,400 bytes (about 2.22 GiB). The package's large map/support files are hard-linked to the ignored source files under `local-input/`; this keeps the package usable as a folder without allocating a second local copy on the same drive. Copying it to a USB drive, another disk, or the console transfers the full file content.

It combines the prior June world-map/UI and August DLC5 map/shared-support candidates, both owner-provided launchers, and the new Beta 2 `patch_zm.ff`. It includes nine DLC5 map FastFiles, nine map IPaks, nine English map-localization FastFiles, and 18 shared-support/launcher files. It excludes the complete BO2 base game, `base.ipak` (2.7 GB), a title update, the debug executable, and PC-built FastFiles/IPaks.

The candidate `patch_zm.ff` is 3,483,904 bytes with SHA-256 `042df45fbc188ac8f1d58a7e463156bc2d1a3d05c34a14b7398828ac2e0d9673`. The package uses the owner-provided `default_mp_patched.xex` and `default_mp_nosound.xex` side by side; it does not replace the base `default_mp.xex`.

## Comparison with the previous agent's state

| Area | Previous state | Current handoff |
|---|---|---|
| DLC5 distribution | A 45-game-file June/August first-playable package existed in `dist/`. It included maps, IPaks, localization, UI/shared-support candidates, and two launchers, but its `patch_zm.ff` hash (`0a21ac…`) had no Beta 2 script backport. | Rebuilt the same 45 game-root paths using the previous package's checksum list as a baseline, then replaced only `patch_zm.ff` with the Beta 2 candidate. The other 44 file hashes match the previous package exactly. All 45 current package checksums pass. |
| Beta 2 script integration | Candidate `patch_zm_beta2_scriptbackport_i.ff` integrated 46 of 72 modules into 13 existing script assets. | Candidate `patch_zm_beta2_scriptbackport_j.ff` integrates 47 of 72 into 13 assets. `zzz_zm_mk2box.gsc` was added using static references to stock Xbox functions. |
| Remaining scripts | 26 modules were skipped, including oversize dog replacements, unsupported Plutonium APIs, prototypes, and diagnostic probes. | 25 remain skipped. `zzz_zm_m27box.gsc` is also held back because its Xbox weapon variant and supporting assets are unverified. Two full dog replacements still exceed their existing payload slots. Per-module reasons are in `xbox360-test-candidate-status.md` and the candidate manifest. |
| Build provenance/tool version | Existing notes claimed GSC Tool 1.6.0.360, while the candidate recheck's available compiler was not clearly recorded. | The new manifest records GSC Tool 1.4.10.333, compiler/unpacker/source/builder hashes, and hashes for the input zone and metadata. Repository docs now identify the compiler used for this candidate. |
| Package size | The earlier package occupied about 2.38 GB on disk and had been staged with local/private files. | The same full file set is hard-linked into `dist/`, so it does not duplicate the large source assets locally. The accidentally staged distribution and local-input additions were removed from the Git index; their source files remain on disk. |
| Main branch | There was concern that recent `main` changes might need to be merged. | `main` is an ancestor of the active branch (`main...HEAD` is `0 1`); no merge is required. No commit or push was made. |

## Checks completed

- Rebuilt all edited GSC/CSC payloads for T6/Xbox 360 with GSC Tool 1.4.10.333.
- Integrated 47 modules into 13 existing script assets and attached server/client dispatch to the existing Zombies initialization path.
- Regression-checked all 13 modified scripts: zero newly missing qualified imports and zero argument-count mismatches. New unqualified engine imports still require confirmation against the XEX at runtime.
- Confirmed the smallest edited payload retains 806 bytes of slot space.
- Repacked and decoded the FastFile; the candidate zone round-tripped exactly with SHA-256 `119291cecfa4e44a2b21c7f7e598843c38f299200cc6f0d4762b85f9c9324c84`.
- Rebuilt the full 45-file DLC5 package and verified every packaged game-file hash. Comparing it with the previous package's `SHA256SUMS.txt` showed only `patch_zm.ff` changed.
- Confirmed the package's large asset files are hard links to their retained `local-input/` sources.
- Ran `git diff --check`; no whitespace errors. The Git index is clean of staged files.

## Still unverified or incomplete

- No Xenia binary was available, and the package has not been booted on Xenia or an Xbox 360. Acceptance of the unsigned TAffu100 FastFile by `default_mp_patched.xex`, the load path, and actual gameplay behavior remain unknown.
- The test package requires a separate complete Xbox 360 BO2 base installation. It does not include the base game, `base.ipak`, or title update. Use its `INSTALL.txt` to copy the 45 files into a separate test copy and check all nine map loads plus the Moon and Shangri-La script changes.
- This candidate includes the earlier June/August Xbox asset candidates and the Beta 2 script work. It does not port every Beta 2 PC asset change; PC `.ff`/`.ipak` files are not Xbox replacements. Additional Xbox asset conversion and map-specific work remains.
- The 25 excluded script modules remain outstanding for the reasons recorded in the status document and build manifest.

## Key files

- Test instructions: `dist/ZombiesDeclassified-Xbox360-DLC5-Beta2-Test-042df45fbc18/INSTALL.txt`
- Package file hashes: `dist/ZombiesDeclassified-Xbox360-DLC5-Beta2-Test-042df45fbc18/SHA256SUMS.txt`
- Candidate details and skipped modules: `docs/xbox360-test-candidate-status.md`
- Package builder: `tools/Build-Dlc5TestCandidatePackage.ps1`
- Candidate FastFile: `local-input/crybaby-test/candidates/patch_zm_beta2_scriptbackport_j.ff`
- Candidate build manifest: `local-input/crybaby-test/beta2_script_backport_scan_20261012j/beta2_script_backport_manifest.json`
