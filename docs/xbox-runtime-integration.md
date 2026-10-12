# Xbox runtime integration research

This note complements `plutonium-backport.md`; it records loading research and does not claim that the test candidate is installable or runtime-tested. The current design preference is to start fixes through the game's existing Zombies initialization, without a separate script loader.

## What is available

The public [Tesseract BO2 Xbox 360 project](https://github.com/rheard/The-Tesseract-on-Xbox-360-for-Black-Ops-2) targets RGH/JTAG/devkits. Its README requires a title-update-patched XEX and a separately loaded Tesseract DLL. Its script hooks read GSC/CSC overrides from `game:\raw\<asset-name>` and can register a missing script when the engine requests it. This is a possible console asset loader, not a ready Aurora package.

The public [BO2 GSC Live Injector](https://github.com/Ticass/bo2-xenia-gsc-live-injector) is a separate Xenia-only test avenue. It targets the live `_callbacksetup.gsc` object for retail MP/ZM or `_objpoints.gsc` for the July 2012 MP Alpha. It inserts a call to a custom entrypoint and modifies Xenia guest memory; it does not make an Xbox install package.

## Current no-extra-loader candidate

The test-only `patch_zm.ff` candidate integrates 46 Beta 2 modules into existing server/client scripts and adds dispatch calls to `_zm.gsc::init()` and `_zm.csc::init()`. This is a static in-game bootstrap, not the Tesseract DLL or Xenia injector path described above. Selected `GetFunction` lookups are rewritten to statically imported stock script functions; modules requiring unresolved Plutonium hooks or map-specific replacement work remain excluded. See `plutonium-backport.md` and the candidate manifest for the current list.

The candidate's GSC/CSC compilation, slot fitting, static link checks, and FastFile decode/repack round trip pass. The generated FastFile uses an unsigned TAffu100/dev-loader-style representation, and neither Xenia nor the user's Xbox has confirmed that the patched XEX accepts it or loads it from the intended location. So the in-game startup code exists, but its execution is not yet proven.

## Why compiling scripts alone was not a backport

Static source audit of the 72 hash-verified Beta 2 GSC/CSC inputs shows:

- 68 have an `init()` entrypoint that depends on Plutonium's custom-script startup behavior.
- 25 use Plutonium's `GetFunction` API.
- 6 use Plutonium's `replaceFunc` API.
- One required a narrow Xbox compiler compatibility rewrite for `getdvarint`; that rewrite is not runtime-verified.

The six `replaceFunc` consumers are `zzz_protonames.gsc`, `zzz_zm_eggsong.gsc`, `zzz_zm_factorytelevox.gsc`, `zzz_zm_howlparity.gsc`, `zzz_zm_quaddescent.gsc`, and `zzz_zm_quadvo.gsc`. These remain outside the current candidate and need compatible edits to their target scripts or a verified hook mechanism; compiling their source is not sufficient.

Plutonium documents that it runs custom-script `main()` before stock scripts and `init()` after gametype startup, and that `replaceFunc` redirects an existing stock function. Tesseract's public script-loader source has hooks for loading/replacing parse-tree assets and loading a new asset when requested, but its script-loader source does not implement Plutonium's custom-script autostart or `GetFunction`/`replaceFunc`. Consequently, merely copying the 72 objects into `raw` does not establish that any of their map fixes will execute.

Sources:

- [Plutonium GSC custom scripts and `replaceFunc`](https://plutonium.pw/docs/modding/gsc/new-scripting-features/)
- [Tesseract BO2 Xbox 360 README](https://github.com/rheard/The-Tesseract-on-Xbox-360-for-Black-Ops-2)
- [Tesseract script-loader implementation](https://github.com/rheard/The-Tesseract-on-Xbox-360-for-Black-Ops-2/blob/master/db_registry.c)
- [GSC Live Injector README](https://github.com/Ticass/bo2-xenia-gsc-live-injector)

## Work still required

The user's workflow is to launch `default_mp_patched.xex` manually; we are not assuming that it contains a separate custom GSC loader. The next check is whether that XEX loads the rebuilt `patch_zm.ff` from the correct game path. Until confirmed, the test candidate must stay out of `package/staging/`.

For asset-only fixes—weapon models, textures, animations, audio, localization, and menu assets—the PC Beta 2 `.ff`/`.ipak` data cannot be copied to Xbox 360. The project still needs Xbox-compatible asset conversion/rebuild work and runtime checks per map. No Plutonium fix is currently marked as verified on console or Xenia.

No backups or archives were changed while performing this research.
