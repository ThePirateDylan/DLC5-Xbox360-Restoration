# Xbox 360 Beta 2 test candidate

## Current artifact

The broad Beta 2 script candidate at `local-input/crybaby-test/candidates/patch_zm_beta2_scriptbackport_j.ff` (3,483,904 bytes; SHA-256 `042df45fbc188ac8f1d58a7e463156bc2d1a3d05c34a14b7398828ac2e0d9673`) integrated 47 modules and black-screened on console; it remains excluded. The one-module Moon candidate at `local-input/crybaby-test/candidates/patch_zm_beta2_moona51perks_k.ff` (3,505,920 bytes; SHA-256 `daba3a82e258b811ca075997912551838026d872f9f1bf84ddf404bb5396b03a`) also black-screened when the user tested it. Its distribution has been withdrawn; do not copy it again. Both failing candidates used unsigned `TAffu100`. A no-content-change XMem/LZX repack now decodes exactly as `TAffx100`; a four-fix Moon candidate has been packaged using that format, but its signature bytes were copied unchanged and remain unverified. See [the container investigation](fastfile-container-investigation.md).

The 43-file June/August UI/map package was rejected because it still showed the old Five placeholder and contained no Beta 2 art; that generated folder has been removed. **Do not copy it.**

**Status: no rebuilt FastFile is currently testable on console.** The four-fix XMem/LZX Moon package was tested and black-screened. Its old signature was copied unchanged, so it is withdrawn; do not copy it again. The user confirmed the stable August `patch_zm.ff` and its matching `.ipak` restore stock-map and The Giant loading in the same test copy. The mismatch from restoring only the FastFile explained the earlier “Awaiting Textures” hang; `base.ipak` did not need to be rebuilt. The raw Beta 2 `mainlobby.lua` and `scoreboard.lua` are PC sources and have not been converted for Xbox.

The package excludes the full base game, its `base.ipak`, and any title update. Do not rebuild `base.ipak` based on the freeze alone. A structural audit of the repository's source base IPak found 48,063 index entries whose data ranges fit the declared data section; all nine source map IPaks and both shared-support IPaks also passed section/index bounds and block-alignment checks. This does not prove the console's installed base file matches that source, validate decompression or CRCs, or prove that every map FastFile image key resolves to the right payload. BO2 IPak lookup uses an image-name hash and data CRC, with image data streamed from the loaded IPak ([OpenAssetTools format reference](https://openassettools.dev/reference/ipak-file-format.html)).

## Launcher identity

Both package launchers were supplied by the user and were not edited by the package builder. They are distinct executables, not untouched copies of one another:

| File | Bytes | SHA-256 |
|---|---:|---|
| `default_mp_patched.xex` | 11,231,232 | `42b6e9ae5ccd39798b195001c5805074c564d37d62ee9c92170107337e8670af` |
| `default_mp_nosound.xex` | 11,132,928 | `63b07df157e6acdc5f26a795e56c3d304455f090c8e2f6360c955ef74cf762f8` |

Both report title ID `0x415608C3`; their execution-ID version and base-version fields are zero, so that metadata does not establish title-update equivalence. For a controlled comparison, identify the exact XEX used by the working merged build and use that same file in the candidate test copy.

## Shared `patch_zm` generation pairing

The repository contains two different source generations of the shared Zombies patch zone and IPak:

| Source set | `patch_zm.ff` | `patch_zm.ipak` |
|---|---|---|
| June first-playable | 3,281,536 bytes; `c85e42cc7cc1631d6f11462ec74415294682ce3cbd184f65243d6a7f5f9ecb82` | 4,816,896 bytes; `e566b3cb8e58f04b9f200f02ffae165ab357aa9610773a382e3f96052ca2389e` |
| August shared-support | 3,302,720 bytes; `0a21ac956b5d87a314d1a4aca753eeb39d5e1c8f7837f8baa9cffe92546b557c` | 4,620,288 bytes; `84cea61461d03ada2278762ff686069639ca076aefeb4d9017c807d7f7f4dcc3` |

The Beta 2 FastFile was rebuilt from the August `patch_zm.ff` zone, and the failed package had the August `patch_zm.ipak`. The user restored only `patch_zm.ff` at first, then copied the matching IPak from the same known-good merged build. A stock map and The Giant then loaded. This supports the shared FF/IPak mismatch as the cause of “Awaiting Textures.” The console's `base.ipak` was not changed, so rebuilding it is not indicated by this result.

## Beta 2 world-map UI and art investigation

The upstream Beta 2 notes specifically list map descriptions for Five, Ascension, Shangri-La, and Moon, plus new map-select art for Five, Shangri-La, and Moon ([Beta 2 release notes](https://github.com/Logo-2K/zombies-declassified/releases/tag/beta2)). This is the visible UI work the next package must actually contain. See [the detailed UI asset port notes](beta2-ui-asset-port.md) for local source and tool findings.

The local inputs include the PC Beta 2 `mainlobby.lua` and `scoreboard.lua` source, plus a small PC `mod_load.ipak`; they do not include Xbox-ready Beta 2 map-art assets. The installed Crybaby tools can inspect and repack Xbox script/FastFile candidates, but there is no verified Xbox image converter/IPak builder in the project. The available OAT image converter exposes T6 conversion only, and the included OAT unlinker could not parse the PC `mod_load.ff` (zlib stream errors). PC Beta 2 `.ff`/`.ipak` files must not be copied into the Xbox overlay.

The Xbox `MapInfoImage` Lua reference builds a material name dynamically from map, mode, and start-location values. A local index scan checked 48 likely material-name combinations across 13 supplied IPaks, including the PC `mod_load.ipak`, and found no matches. The names were inferred from decompiled UI code, so this is a narrow diagnostic result, not proof that no relevant image exists anywhere in the Xbox archives. Exact material strings and source-image records still need to be identified before a safe Xbox IPak can be built.

The rejected 43-file bundle was removed. Do not run `tools/Build-Dlc5UiMapTestPackage.ps1` as a Beta 2 test build: it produces only the June placeholder UI assets.

## Broad 47-module candidate (excluded after console failure)

The candidate integrates 47 of the 72 Beta 2 GSC/CSC modules into 13 existing Xbox 360 script payloads. Server and client dispatch calls are attached to the existing Zombies initialization functions in `_zm.gsc` and `_zm.csc`; no separate loader is assumed. `zzz_zm_mk2box.gsc` is included after replacing two Plutonium dynamic lookups with static references to stock Xbox functions.

The current build used GSC Tool 1.4.10.333 targeting T6/Xbox 360. The manifest records hashes of the compiler, unpacker, source inputs, overrides, builder, and input zone. Compilation and payload-slot checks passed; the smallest remaining slot slack is 806 bytes. The static import/arity regression reported zero missing imports or argument-count mismatches. Repacking and decoding produced an exact zone round trip (SHA-256 `119291cecfa4e44a2b21c7f7e598843c38f299200cc6f0d4762b85f9c9324c84`).

These checks establish candidate file consistency only. The rebuilt FastFile has an unsigned TAffu100 representation; both the `j` candidate and the one-module Moon package black-screened on console. The runtime import list is not confirmed against the XEX. No title update is included, and the exact title-update/XEX pairing for the user's test copy has not been established. Container evidence and next steps are in [the investigation report](fastfile-container-investigation.md).

## Targeted Moon Area 51 candidate

The withdrawn one-module candidate contained only `zzz_zm_moona51perks.gsc`, adapted from the Beta 2 source. Its `init()` exits unless `mapname` is `zm_moon`, then starts a short thread that enables the Speed Cola and Juggernog perk machines in Area 51. No art, localization, map FastFiles, launcher, or other Beta 2 module was included.

Build details:

- Candidate `patch_zm.ff`: 3,505,920 bytes; SHA-256 `daba3a82e258b811ca075997912551838026d872f9f1bf84ddf404bb5396b03a`.
- Paired August `patch_zm.ipak`: 4,620,288 bytes; SHA-256 `84cea61461d03ada2278762ff686069639ca076aefeb4d9017c807d7f7f4dcc3`.
- Changed stock ScriptParseTrees: `maps/mp/zombies/_zm.gsc` and `maps/mp/zombies/_zm_devgui.gsc`.
- GSC Tool 1.4.10.333; minimum remaining slot space 2,908 bytes; static link report has no missing imports or arity mismatches; exact zone round-trip passed (SHA-256 `a6be6295ea34d86e393207d4dc6bfc1559eb42d61ca687ac9ab8952d9ebc682c`).
- Previous package: two game-root files, 8,126,208 logical bytes, SHA-256 verified; distribution withdrawn after the console black-screen.
- Runtime status: failed. The user tested the one-module Moon package and it black-screened, like the prior 47-module build. Do not ask the user to retry this candidate. Its `TAffu100` container path must be fixed or ruled out first.

The old package's install steps are obsolete because its candidate black-screened. The generated distribution has been removed; keep the known-good August `patch_zm.ff` and `.ipak` pair restored until a validated candidate is available.

## Four-module Moon XMem/LZX candidate

The withdrawn package was `dist/ZombiesDeclassified-Xbox360-Moon-4Fix-LZX-Test-20261012/`. It contained the candidate `patch_zm.ff` and matching known-good August `patch_zm.ipak`, totaling 7,878,848 logical bytes. It black-screened; do not copy it again.

Included Beta 2 changes, all guarded to Moon:

1. Start Area 51 with Speed Cola and Juggernog powered.
2. Enable the Moon high-frame-rate gravity correction.
3. Bridge the Moon hacked wall-buy state into stock Xbox trigger objects so the reduced ammo price can apply.
4. Resend the normal-side sky state when the expected Moon sky transition event is missing.

The candidate is 3,258,560 bytes (`e6f0fa35f79f0f769d0b1381d27a01c2bbddc3f936f8533e4d1876ab08e202e6`). It has `TAffx100` magic, is XMem/LZX-compressed and Salsa20-encrypted, and decodes byte-for-byte to the modified 9,276,397-byte zone (`de0065c4719b4e76054bbb1f96f2cc19e1cfad97acc8c7216f5a58733c1b13a9`). The 256-byte signature region was copied unchanged from the August baseline and not regenerated. **The user tested this exact package and it black-screened; it is withdrawn and must not be copied again.** No included Moon change could be tested in gameplay. See the linked container investigation for the signing blocker.

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

## Safe test baseline and next verification

1. Keep the original install and known-good merged build unchanged.
2. The known-good test baseline is the matching August `patch_zm.ff`/`.ipak` pair; the user reports that stock maps and The Giant load with it.
3. Do not test the four-fix package again. The user already tested it and it black-screened. Keep the known-good August patch pair restored until a legitimate signature/bypass path is established.
4. Do not copy the removed 43-file June placeholder bundle, the black-screening 47-module FastFile, or the black-screening one-module Moon FastFile. `zm_prototype` is Nacht der Untoten.

## Project state

The active branch is one checkpoint commit ahead of `main`; `main` is already in its history. The test overlay and local inputs are generated/private files and must remain outside Git history. No commit or push has been made.
