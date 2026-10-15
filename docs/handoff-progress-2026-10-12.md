# DLC5/Beta 2 handoff report — 2026-10-12

## Current state

The old 43-file June/August UI/map bundle was technically checksum-verified, but its UI was the old Five placeholder and it contained no Beta 2 map art. The user said that bundle was not useful to test, so its generated folder was removed. The one-module Moon package black-screened and was withdrawn. The follow-up four-fix XMem/LZX `TAffx100` package also black-screened in the user's test. It had the same uncorrected signing flaw: its 256-byte signature region was copied from the August file after the zone changed. That package is withdrawn too; no rebuilt FastFile has passed console loading.

The broad Beta 2 script candidate remains local-only at `local-input/crybaby-test/candidates/patch_zm_beta2_scriptbackport_j.ff` (3,483,904 bytes; SHA-256 `042df45fbc188ac8f1d58a7e463156bc2d1a3d05c34a14b7398828ac2e0d9673`). It integrated 47 of 72 modules and passed static checks, but black-screened on console, so it stays excluded. A new targeted candidate at `local-input/crybaby-test/candidates/patch_zm_beta2_moona51perks_k.ff` (3,505,920 bytes; SHA-256 `daba3a82e258b811ca075997912551838026d872f9f1bf84ddf404bb5396b03a`) integrates only `zzz_zm_moona51perks.gsc`.

The known-good console baseline is the matching August `patch_zm.ff` and `patch_zm.ipak`. The user reports that stock Zombies and The Giant both load after restoring that pair in the merged DLC5 test copy. The existing console install, original game, base assets, launchers, and backups were not changed by this continuation.

### Console-test update after this handoff was written

The user tested both the earlier broad 47-module Beta 2 `patch_zm.ff` and the later one-module Moon `patch_zm.ff` on Xbox 360; both black-screened. Restoring the original `patch_zm.ff` alone restored menu boot, but maps still froze at “Awaiting Textures.” The user then restored the matching `patch_zm.ipak` from the same known-good DLC5 build. Stock Zombies and The Giant loaded in that test copy afterward. The original base FastFiles and `base.ipak` were present and the copy procedure was correct; the user believes no title update was active. The exact launcher/title-update pairing for both copies remains unconfirmed.

The package's `default_mp_patched.xex` and `default_mp_nosound.xex` are distinct owner-provided binaries, not untouched copies of each other. Their SHA-256 hashes are `42b6e9ae5ccd39798b195001c5805074c564d37d62ee9c92170107337e8670af` and `63b07df157e6acdc5f26a795e56c3d304455f090c8e2f6360c955ef74cf762f8`, respectively. Both have title ID `0x415608C3`, but their execution-ID version/base-version fields are zero; this does not prove that they use the same title update. The working-build launcher still needs to be identified exactly.

The matching known-good `patch_zm.ff`/`.ipak` pair loads a stock map and The Giant in the user's test copy; restoring only the FastFile had caused “Awaiting Textures.” This supports the pair mismatch as the texture-loading cause, and rebuilding `base.ipak` is not indicated. Separately, all three modified FastFile candidates tested so far black-screened, including the XMem/LZX four-fix build. The four-fix file reused a source signature after changing the zone. Public OpenAssetTools project notes say its maintainer does not know Treyarch's private FastFile signing key, so creating an ordinary retail-valid signature is not currently available through that tool ([issue #54](https://github.com/Laupetin/OpenAssetTools/issues/54)). The precise console rejection point is not proven; the launcher/signature path must be resolved before another candidate. See [the FastFile container investigation](fastfile-container-investigation.md). The repository source IPaks pass structural section/index range checks, including 48,063 base-IPak index entries, but this does not validate the user's installed file or resolve each requested image key to its payload.

## Comparison with the previous agent's state

| Area | Previous state | Current handoff |
|---|---|---|
| DLC5 distribution | A 45-game-file June/August first-playable package existed in `dist/`, using the August baseline patch pair. | The placeholder UI bundle, one-module Moon package, and four-fix Moon LZX package are withdrawn after user tests. No new FastFile is console-validated. |
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
- Removed the rejected 43-file generated package from `dist/`; its hard-linked sources remain under ignored `local-input/`.
- Scanned 348 inferred Zombies menu-image names against the base-IPak index and 13 supplied non-base IPak indices. No name-hash matches were found. Since aliases are inferred and not all archives/material names are present, this does not prove the images are absent.
- Confirmed the local PC Beta 2 `mainlobby.lua`/`scoreboard.lua` sources and small PC `mod_load.ipak` are not Xbox-ready replacements; the available tools do not provide a verified Xbox 360 UI image-to-IPak path. See `docs/beta2-ui-asset-port.md`.
- Added a repeatable `--include-module` option to the script builder, built a one-module `zzz_zm_moona51perks.gsc` candidate, and verified compilation, slot fit, static link checks, and exact zone round-trip.
- Packaged the one-module candidate with the matching August `patch_zm.ipak` only (two game files, 8,126,208 bytes logical); both SHA-256 entries passed. The user tested it and it black-screened; the package was withdrawn.
- Built a no-content-change `TAffu100` repack from the known-good decoded `patch_zm` zone. It decodes byte-for-byte to the input zone but differs from the original console header (`TAffx100`) and has no signature. This makes the writer/container the leading failure hypothesis; no no-op console test has been made.
- Extracted Microsoft-signed XNA 4.0 Refresh into ignored scratch space without installing it; confirmed its `XnaNative.dll` MD5 matches the helper's hard-coded XMem function offsets. Retained only `XnaNative.dll` and its two runtime dependencies under ignored `_tools/xna-native-4.0.30901.0`; updated the ignored local repacker to accept `XNA_NATIVE_DIR`.
- Built an XMem/LZX `TAffx100` no-op from the baseline; it decoded byte-for-byte to the original zone (SHA-256 `7dd80608ebf7feb928b9cbff65890134ea26732f2859aa1d23d76e9debf84d7f`). Its signature region still copies the original bytes and is not validated for rebuilt contents.
- Rebuilt the four-module Moon candidate with XMem/LZX: perks, gravity, hacked wall-buy price bridge, and sky transition. Candidate size is 3,258,560 bytes, SHA-256 `e6f0fa35f79f0f769d0b1381d27a01c2bbddc3f936f8533e4d1876ab08e202e6`; decoded zone exactly matches the 4-module source zone hash `de0065c4719b4e76054bbb1f96f2cc19e1cfad97acc8c7216f5a58733c1b13a9`.
- Packaged that candidate with only the August `patch_zm.ipak` (two game-root files, 7,878,848 logical bytes) at `dist/ZombiesDeclassified-Xbox360-Moon-4Fix-LZX-Test-20261012/`; checksums passed, but the user tested it and it black-screened. It is withdrawn.
- Hardened the broad and one-module package builders to refuse unvalidated FastFiles; added a separate, explicitly opt-in experimental four-fix package builder that documents the reused signature and restore steps.
- Ran `git diff --check`; no whitespace errors. The Git index is clean of staged files.

## Still unverified or incomplete

- The broad 47-module, one-module Moon, and four-fix Moon packages all black-screened on Xbox 360. Do not retest those artifacts.
- The four-module candidate reuses the August source signature; it was not regenerated. That is the leading known defect, but the exact loader failure point is not proven. Establish a valid signing/bypass path or a clear no-op diagnostic plan before creating another console candidate.
- In the earlier test copy, restoring the known-good `patch_zm.ff` without its matching IPak left maps at “Awaiting Textures”; restoring the pair allowed a stock map and The Giant to load.
- Static checks show the repository source IPak sections/index ranges are internally consistent, but no data CRC/decompression audit or runtime image-key resolution audit has been completed. The user's installed `base.ipak` has not been compared byte-for-byte with the repository source copy.
- The raw Beta 2 PC UI Lua/art has not been converted to Xbox formats. PC `.ff`/`.ipak` files are not Xbox replacements. Additional Xbox-compatible Beta 2 asset/UI conversion and map-specific work remains.
- The 25 excluded script modules remain outstanding for the reasons recorded in the status document and build manifest.

## Key files

- Test instructions: `dist/ZombiesDeclassified-Xbox360-Moon-4Fix-LZX-Test-20261012/INSTALL.txt`
- Four-fix test package builder: `tools/Build-Dlc5MoonPlusTestPackage.ps1`
- FastFile writer/black-screen investigation: `docs/fastfile-container-investigation.md`
- UI/art port blocker and next steps: `docs/beta2-ui-asset-port.md`
- Candidate details and skipped modules: `docs/xbox360-test-candidate-status.md`
- Package builder: `tools/Build-Dlc5TestCandidatePackage.ps1`
- Candidate FastFile: `local-input/crybaby-test/candidates/patch_zm_beta2_scriptbackport_j.ff`
- Candidate build manifest: `local-input/crybaby-test/beta2_script_backport_scan_20261012j/beta2_script_backport_manifest.json`
