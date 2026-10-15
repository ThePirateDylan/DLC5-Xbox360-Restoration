# Beta 2 UI and map-art port notes

## Required visible change

The upstream Beta 2 notes list new map-select art for Five, Shangri-La, and Moon, plus map descriptions for Five, Ascension, Shangri-La, and Moon ([release notes](https://github.com/Logo-2K/zombies-declassified/releases/tag/beta2)). The next Xbox test bundle needs at least one of these real changes. The older 43-file bundle only copied June Xbox placeholder UI and was removed; it is not a Beta 2 port.

## What is available locally

- Xbox DLC5 map FastFiles/IPaks and June/August Xbox support candidates are under ignored `local-input/`.
- Beta 2 `mainlobby.lua` and `scoreboard.lua` are PC Lua sources under `local-input/plutonium-beta2-ui-source/`.
- The small PC `mod_load.ff`/`.ipak` pair is under `local-input/ui-investigation/`. It is not an Xbox replacement.
- The available Xbox Lua utility can inspect/re-emit existing compiled bytecode or rebuild from its HKS assembly/JSON workspace. Its description explicitly says it is not a full source compiler.
- The available OAT `ImageConverter` exposes a T6 conversion mode, but no tested Xbox 360 image-to-IPak build path is present in this project. OAT's FastFile unlinker reports invalid zlib streams on the PC Beta 2 `mod_load.ff` supplied here.

## Findings and limits

The decompiled Xbox `MapInfoImage` code forms a Zombies preview material from the UI map name, game type, and `CoD.Zombie.START_LOCATION_TRANSIT`. The Xbox `CoD.Zombie` strings show that this start-location constant is `"transit"`. A diagnostic scan tested 348 likely image-name combinations against the index sections of the repository's base IPak and 13 local non-base IPak files, including the supplied PC `mod_load.ipak`; it found no name-hash matches. This is only a search across inferred names. It does not prove that the artwork is absent from other archives or that every actual game mode/map alias was included.

BO2 IPak indices map a material-name hash and image-data CRC to streamed image blocks ([IPak format reference](https://openassettools.dev/reference/ipak-file-format.html)). Matching a menu name is therefore not enough: the converted Xbox image bytes, CRC, block layout, and correct load order must all agree. The currently available PC source and T6 tools have not established those Xbox-specific parts.

## Next work to unlock a safe test package

1. Identify the actual Xbox material names requested by map-select UI for Five, Shangri-La, and Moon from the game tables/compiled UI, rather than relying on guessed aliases.
2. Locate the corresponding Beta 2 source images in the upstream data pack and confirm their dimensions, pixel formats, and PC/Xbox differences.
3. Use or implement a reproducible Xbox 360 image conversion and IPak builder, then validate generated indices, image CRCs, chunk/block boundaries, and pairing/load order against known Xbox IPaks.
4. Adapt any required menu Lua/localization changes to the Xbox bytecode/zone format while preserving the stock startup and UI entry points.
5. Build a small one-map UI test package with the exact changed UI FastFile/localization and paired IPak, plus the known-good August `patch_zm.ff`/`.ipak` baseline. Hash it and test the changed map selection on console before expanding to the other maps.

Until these steps produce a verifiable Xbox-format change, there is no Beta 2 UI/art package ready for console testing. A separate four-fix Moon script package is available, but it contains no UI/art and its signature is unverified; see `docs/xbox360-test-candidate-status.md` and `docs/fastfile-container-investigation.md`. The older broad 47-module and one-module FastFiles remain excluded because they black-screened on the user's console.
