# Xbox 360 package staging

For a general files-only package, put project files under `staging/` with paths relative to the BO2 game root and run `tools/Build-AuroraPackage.ps1`.

For the current experimental DLC5/Beta 2 test package, run `tools/Build-Dlc5TestCandidatePackage.ps1`. It packages the nine DLC5 map FastFiles/IPaks and English localization files, the June world-map/UI and August shared-support candidates, both owner-provided launchers, and the Beta 2 `patch_zm.ff`, with checksums and a test checklist. It excludes the complete BO2 base game and the 2.7 GB `base.ipak`; use it with a separate full base-game installation. It has not been tested in Xenia or on hardware. By default, large local source files are hard-linked into `dist/` to avoid duplicating them on the same drive; pass `-CopyFiles` only when an independent local copy is needed and there is enough storage.

Keep private source files and generated build output under the ignored `local-input/` and `dist/` directories. Do not add full game files, DLC archives, backups, or proprietary assets to Git.
