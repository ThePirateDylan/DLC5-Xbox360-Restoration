# Xbox 360 package staging

Place only the finished project files in `staging/`, keeping each file's path relative to the target Black Ops II game directory. Run `tools/Build-AuroraPackage.ps1` from the repository root to create a transfer folder under `dist/`; the output preserves those relative paths under `game-root/` and includes SHA-256 hashes.

Do not stage the full game, DLC archives, or backups. Keep private source files under the ignored `local-input/` directory and generated output under the ignored `dist/` directory. Nothing in this folder is ready to install on a console yet; the target Xbox 360 file layout and actual payload still need to be confirmed.
