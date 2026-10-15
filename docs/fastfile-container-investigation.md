# FastFile console black-screen investigation

## Current conclusion

The four-fix Moon candidate also black-screened on the user's Xbox. That candidate used XMem/LZX `TAffx100`, but its 256-byte signature area was copied unchanged from the August source after the zone contents were modified. The old signature is the leading concrete cause; the candidate must be treated as failed, not as a usable build. A local decode/round-trip is not a signature or console-load check.

## Evidence from local files

| Artifact | Size | Header | SHA-256 | What it tells us |
|---|---:|---|---|---|
| Known-good August `patch_zm.ff` | 3,302,720 bytes | `TAffx100` | `0a21ac956b5d87a314d1a4aca753eeb39d5e1c8f7837f8baa9cffe92546b557c` | Xbox source baseline; signature region is populated. |
| One-module Moon candidate `...moona51perks_k.ff` | 3,505,920 bytes | `TAffu100` | `daba3a82e258b811ca075997912551838026d872f9f1bf84ddf404bb5396b03a` | User tested this build; it black-screened. Its signature region is zeroed. |
| No-content-change diagnostic repack | 3,537,920 bytes | `TAffu100` | `508e7f9cb7c0e2ec43fbc3289678a59c0d7f0abdd5518d3107581487d2d01e26` | Rebuilt from the original decoded zone with no source recompilation. Decoding it reproduced the original zone byte-for-byte (SHA-256 `7dd80608ebf7feb928b9cbff65890134ea26732f2859aa1d23d76e9debf84d7f`). This isolates the container rewrite from script edits at file level; it has not been tested on console. |
| No-content-change XMem/LZX diagnostic repack | 3,292,096 bytes | `TAffx100` | `9dc79f430e0a9bd954f777a1f1e7f27c92ed8c566e79f1de82410538f2feb1f2` | Rebuilt from the same original zone, then decoded byte-for-byte to its source. It has the original signature bytes, not a regenerated signature; it has not been tested on console. |
| Four-fix Moon XMem/LZX candidate | 3,258,560 bytes | `TAffx100` | `e6f0fa35f79f0f769d0b1381d27a01c2bbddc3f936f8533e4d1876ab08e202e6` | User tested it; it black-screened. It decodes exactly to the edited zone, but carries the unchanged source signature. Do not reuse it. |

The repacker's own CLI describes the default `deflate` mode as plaintext `TAffu100` for a dev loader. Its `lzx` route uses Microsoft's XMem LZX encoder and Salsa20 chunk encryption, emits `TAffx100`, and reuses the original header signature. The Microsoft XNA Framework 4.0 Refresh package was downloaded from Microsoft's Download Center, its Authenticode signature verified, and its MSI was administratively extracted into ignored scratch space without installing it. Its `XnaNative.dll` MD5 is `cbffc669518ee511890f236fefffb4c1`, matching the XNA 4.0.30901.0 function addresses in [gibbed/XCompression](https://github.com/gibbed/XCompression/blob/vs2017/XnaNative.cs). The extracted `XnaNative.dll` plus its two Microsoft runtime dependencies are retained under ignored `local-input/crybaby-t6-linker-tool/_tools/xna-native-4.0.30901.0`; the helper accepts that folder through `XNA_NATIVE_DIR`. Reusing the August signature after changing the zone does not make the rebuilt file validly signed. The OpenAssetTools maintainer says the Treyarch FastFile private signing key is unknown, so normal retail-valid re-signing is not currently available through that tool ([issue #54](https://github.com/Laupetin/OpenAssetTools/issues/54)).

## What the black screens do and do not prove

- The broad 47-module candidate, one-module candidate, and four-fix XMem/LZX candidate all black-screened. Reducing the script count and switching to the Xbox-style compression family did not solve it.
- The four-fix candidate's console failure confirms it is unusable. It does not by itself isolate invalid signature from a malformed console container or fatal script initialization. The unchanged August signature is the clearest known defect, and public tooling research says the retail signing key is unavailable.
- The XMem/LZX no-op shows only that this local writer and reader agree on a round trip. It has not been console-tested and also carries an old signature; it is not a safe workaround or a release candidate.
- Exact zone round-tripping proves the repacker can reconstruct the decoded zone. It does not validate the Xbox loader's codec, authentication rules, chunk reader, script linker behavior, or the new script calls.
- The four-module Moon follow-on (`patch_zm_beta2_moonplus_l_xmem.ff`) adds the Beta 2 Area 51 perk startup, high-frame-rate gravity correction, hacked wall-buy ammo-cost bridge, and Moon sky-transition fix. It passed local static/slot/round-trip checks but black-screened on console. None of those behaviors has been runtime-tested.

## Next concrete steps

1. Keep the matching August `patch_zm.ff`/`.ipak` pair as the known-good baseline. Identify exactly which owner-provided XEX was launched and what its patch is meant to change; the filename `default_mp_patched.xex` alone does not prove that it bypasses BO2 FastFile authentication.
2. Prepare one small no-content-change XMem/LZX diagnostic repack of the known-good `patch_zm.ff`. If the user agrees to test it with the same XEX and matching August IPak, a successful boot would show that the rebuilt container path can load unchanged zone contents; another black screen would point back to signature/container acceptance. This is a diagnostic, not a gameplay candidate.
3. If modified FastFiles remain rejected, investigate a BO2-specific game DLL sideload or a purpose-built XEX patch. PeerPressure documents game/app DLL sideloading and states that DashLaunch plugins are unsupported ([PeerPressure project](https://github.com/grimdoomer/Xbox360PeerPressure)). A mod menu is only a control surface; the required component would be loader code that changes FastFile validation or injects compatible assets/scripts.
4. Do not rebuild or distribute the withdrawn four-fix candidate. Keep the known-good August pair restored until a loader route is demonstrated.

The failed one-module Moon distribution has been withdrawn from `dist/`. The new four-fix distribution is at `dist/ZombiesDeclassified-Xbox360-Moon-4Fix-LZX-Test-20261012/`; its two game files checksum correctly, but it is not a verified release. The last known-good user state is the matching August `patch_zm.ff` + `patch_zm.ipak` pair, which restored stock maps and The Giant.
