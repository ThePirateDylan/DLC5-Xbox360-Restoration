# Inputs for the Xbox 360 backport

The current repository contains no DLC5 game files or Xenia build. To begin adapting fixes, provide the smallest relevant source set you can, with original relative paths preserved:

- The Xbox 360 DLC5 alpha files that need fixes, plus any directly related files required to rebuild or test them.
- A path listing for the working Xbox 360 BO2 installation and its format (extracted game folder or GOD package), including the title update version if known.
- The Xenia build/version or commit used to identify fixes, and any relevant patch notes or logs. The complete emulator folder is unnecessary unless a specific binary is required to reproduce a fix.

Put the DLC5 source files under the ignored `local-input/dlc5-alpha/` folder and Xenia build notes/logs under `local-input/xenia/`. Preserve original relative paths. Do not add a full game, backups, or proprietary game assets to Git. We'll keep Xenia-specific test notes and any applicable fixes in scope, but the eventual Aurora package should contain only the Xbox 360 files that need to be copied.
