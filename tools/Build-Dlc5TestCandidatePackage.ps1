param(
    [string]$CandidateFastFile,
    [string]$CandidateManifestPath,
    [string]$PatchedXexPath,
    [string]$NosoundXexPath,
    [string]$OutputDirectory,
    [switch]$CopyFiles
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')

if ([string]::IsNullOrWhiteSpace($CandidateFastFile)) {
    $CandidateFastFile = Join-Path $repoRoot 'local-input\crybaby-test\candidates\patch_zm_beta2_scriptbackport_j.ff'
}
if ([string]::IsNullOrWhiteSpace($CandidateManifestPath)) {
    $CandidateManifestPath = Join-Path $repoRoot 'local-input\crybaby-test\beta2_script_backport_scan_20261012j\beta2_script_backport_manifest.json'
}
if ([string]::IsNullOrWhiteSpace($PatchedXexPath)) {
    $PatchedXexPath = Join-Path $repoRoot 'local-input\console-patched-xex\default_mp_patched.xex'
}
if ([string]::IsNullOrWhiteSpace($NosoundXexPath)) {
    $NosoundXexPath = Join-Path $repoRoot 'local-input\console-patched-xex\default_mp_nosound.xex'
}

$requiredInputs = @($CandidateFastFile, $CandidateManifestPath, $PatchedXexPath, $NosoundXexPath)
foreach ($path in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required test-package input not found: $path"
    }
    $item = Get-Item -LiteralPath $path
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Test-package inputs cannot be reparse points: $path"
    }
}

$candidateFastFile = [System.IO.Path]::GetFullPath($CandidateFastFile)
$candidateManifestPath = [System.IO.Path]::GetFullPath($CandidateManifestPath)
$patchedXexPath = [System.IO.Path]::GetFullPath($PatchedXexPath)
$nosoundXexPath = [System.IO.Path]::GetFullPath($NosoundXexPath)
$candidateHash = (Get-FileHash -LiteralPath $candidateFastFile -Algorithm SHA256).Hash.ToLowerInvariant()
$candidate = Get-Content -LiteralPath $candidateManifestPath -Raw | ConvertFrom-Json
if ($candidate.candidate_sha256 -ne $candidateHash) {
    throw "Candidate FastFile hash does not match its build manifest: $candidateHash"
}
if (-not $candidate.roundtrip_exact) {
    throw 'Candidate manifest does not record a byte-exact FastFile round trip.'
}

$localRoot = Join-Path $repoRoot 'local-input'
$mapRoot = Join-Path $localRoot 'dlc5-alpha'
$augustSupport = Join-Path $mapRoot 'shared-support-candidates'
$juneFirstPlayable = Join-Path $localRoot 'june-world-map-reference\first_playable'
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'dist')).TrimEnd('\')
$candidateId = $candidateHash.Substring(0, 12)
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $distRoot "ZombiesDeclassified-Xbox360-DLC5-Beta2-Test-$candidateId"
}
$packageRoot = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if (-not $packageRoot.StartsWith($distRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must be a new folder under dist: $packageRoot"
}
if (Test-Path -LiteralPath $packageRoot) {
    throw "Refusing to overwrite an existing package: $packageRoot"
}

$files = [System.Collections.Generic.List[object]]::new()
$targetNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
function Add-PackageFile([string]$sourcePath, [string]$targetName, [string]$role) {
    $sourcePath = [System.IO.Path]::GetFullPath($sourcePath)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required DLC5 package source not found: $sourcePath"
    }
    $sourceItem = Get-Item -LiteralPath $sourcePath
    if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "DLC5 package sources cannot be reparse points: $sourcePath"
    }
    if (-not $targetNames.Add($targetName)) {
        throw "Duplicate game-root package path: $targetName"
    }
    $files.Add([pscustomobject]@{ Source = $sourcePath; Name = $targetName; Role = $role })
}

# Rebuild the same June/August asset set used by the prior first-playable package.
# These are Xbox assets. The large base.ipak, debug exe, and PC release assets are
# intentionally omitted; the Beta 2 candidate replaces the old shared patch_zm.ff.
$mapNames = @('asylum', 'cosmodrome', 'factory', 'moon', 'pentagon', 'prototype', 'sumpf', 'temple', 'theater')
foreach ($map in $mapNames) {
    Add-PackageFile (Join-Path $mapRoot "zm_$map.ff") "zm_$map.ff" 'August DLC5 map FastFile'
    Add-PackageFile (Join-Path $mapRoot "zm_$map.ipak") "zm_$map.ipak" 'August DLC5 map assets'
    Add-PackageFile (Join-Path $mapRoot "en_zm_${map}_loc.ff") "en_zm_${map}_loc.ff" 'English DLC5 map localization'
}

$supportSources = @{
    'common_mp.ff' = @{ Root = $augustSupport; Role = 'August shared support' }
    'common_zm.ff' = @{ Root = $juneFirstPlayable; Role = 'June shared Zombies support' }
    'dlc5_load_zm.ff' = @{ Root = $augustSupport; Role = 'August DLC5 map loader' }
    'dlc5_load_zm.ipak' = @{ Root = $augustSupport; Role = 'August DLC5 loader assets' }
    'en_patch_loc_zm.ff' = @{ Root = $juneFirstPlayable; Role = 'June world-map localization' }
    'en_patch_loc.ff' = @{ Root = $augustSupport; Role = 'August shared localization' }
    'en_patch_ui_loc_zm.ff' = @{ Root = $juneFirstPlayable; Role = 'June world-map UI localization' }
    'frontend_patch.ff' = @{ Root = $juneFirstPlayable; Role = 'June world-map frontend' }
    'patch_mp.ff' = @{ Root = $augustSupport; Role = 'August shared multiplayer support' }
    'patch_ui_mp.ff' = @{ Root = $augustSupport; Role = 'August shared multiplayer UI' }
    'patch_ui_zm.ff' = @{ Root = $juneFirstPlayable; Role = 'June world-map Zombies UI' }
    'patch_zm.ff' = @{ Root = $null; Role = 'Beta 2 script backport candidate' }
    'patch_zm.ipak' = @{ Root = $augustSupport; Role = 'August Zombies patch assets' }
    'ui_mp.ff' = @{ Root = $augustSupport; Role = 'August multiplayer UI support' }
    'ui_viewer_zm.ff' = @{ Root = $juneFirstPlayable; Role = 'June world-map UI viewer' }
    'ui_zm.ff' = @{ Root = $juneFirstPlayable; Role = 'June world-map Zombies UI' }
}
foreach ($name in $supportSources.Keys) {
    $entry = $supportSources[$name]
    if ($name -eq 'patch_zm.ff') {
        Add-PackageFile $candidateFastFile $name $entry.Role
    } else {
        Add-PackageFile (Join-Path $entry.Root $name) $name $entry.Role
    }
}
Add-PackageFile $patchedXexPath 'default_mp_patched.xex' 'Owner-provided patched Xbox launcher'
Add-PackageFile $nosoundXexPath 'default_mp_nosound.xex' 'Owner-provided alternate Xbox launcher'

if ($files.Count -ne 45) {
    throw "Expected 45 game-root files (9 map FastFiles, 9 map IPaks, 9 localization files, and 18 shared/launcher files); found $($files.Count)."
}

$sourceDrive = [System.IO.Path]::GetPathRoot($files[0].Source)
$targetDrive = [System.IO.Path]::GetPathRoot($packageRoot)
if (-not $CopyFiles -and -not $sourceDrive.Equals($targetDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Hard-link mode requires the sources and dist folder to be on the same drive. Use -CopyFiles to make a separate copy.'
}

$gameRoot = Join-Path $packageRoot 'game-root'
New-Item -ItemType Directory -Path $gameRoot -Force | Out-Null
$sumLines = [System.Collections.Generic.List[string]]::new()
$logicalBytes = [long]0
foreach ($file in $files) {
    $destination = Join-Path $gameRoot $file.Name
    if ($CopyFiles) {
        Copy-Item -LiteralPath $file.Source -Destination $destination
    } else {
        New-Item -ItemType HardLink -Path $destination -Target $file.Source | Out-Null
    }
    $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumLines.Add("$destinationHash *game-root/$($file.Name)")
    $logicalBytes += (Get-Item -LiteralPath $destination).Length
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), [string[]]$sumLines, $utf8NoBom)

$includedLines = @($candidate.included_modules | ForEach-Object { "- $_" })
$excludedLines = @(
    $candidate.excluded_modules.PSObject.Properties |
        Sort-Object Name |
        ForEach-Object { "- $($_.Name): $($_.Value)" }
)
$slacks = @($candidate.fit_report.PSObject.Properties | ForEach-Object { $_.Value.remaining_bytes })
$minimumSlack = ($slacks | Measure-Object -Minimum).Minimum
$linkErrors = 0
foreach ($report in $candidate.link_reports.PSObject.Properties) {
    $linkErrors += @($report.Value.missing).Count + @($report.Value.arity).Count
}
$checkpoint = (& git -C $repoRoot rev-parse --short HEAD 2>$null).Trim()
$packagedNames = @($files | ForEach-Object { $_.Name })
$roleLines = @($files | Group-Object Role | Sort-Object Name | ForEach-Object { "- $($_.Name): $($_.Count) file(s)" })
$storageMode = if ($CopyFiles) { 'Copied into dist as independent files.' } else { 'Hard-linked to ignored local-input sources, so building dist does not duplicate the large DLC5 assets on this drive. Copying the package to another drive/device transfers the full file contents.' }

$noteLines = @(
    'Xbox 360 BO2 DLC5 Beta 2 script test candidate',
    '',
    'This package combines the June world-map/UI candidates, the August Xbox 360 DLC5 maps and shared-support candidates, the owner-provided launchers, and the rebuilt Beta 2 patch_zm FastFile. It is a test package, not a verified console release or full game.',
    '',
    'The complete BO2 base game is required. The 2.7 GB base.ipak, debug CoDMP_patched.exe, unverified June load/stream reference bundles, title update, and PC-built FastFiles/IPaks are intentionally excluded. The zm_prototype map is Nacht der Untoten.',
    '',
    "Candidate patch_zm SHA-256: $candidateHash",
    "Candidate patch_zm bytes: $($candidate.candidate_bytes)",
    "Package game-root files: $($files.Count); logical bytes: $logicalBytes",
    "Local disk behavior: $storageMode",
    "Project checkpoint: $checkpoint (with local working-tree build-tool changes)",
    "GSC compiler: $($candidate.build_provenance.gsc_tool_version)",
    "Included Beta 2 modules: $($candidate.included_modules.Count) in $($candidate.modified_sources.Count) existing script assets",
    "Minimum remaining script-slot space: $minimumSlack bytes",
    "Static link regressions (missing imports / arity mismatches): $linkErrors",
    "FastFile decode/repack round trip: $($candidate.roundtrip_exact); zone SHA-256 $($candidate.zone_sha256)",
    '',
    "File groups:`r`n$($roleLines -join [Environment]::NewLine)",
    '',
    'The Beta 2 FastFile is an unsigned TAffu100/dev-loader-style build. Whether default_mp_patched.xex accepts it, loads it from the target path, or executes the backported changes has not been confirmed in Xenia or on an Xbox 360. Compilation, static link/slot checks, and round-trip integrity are file-level checks only.',
    '',
    'Included Beta 2 modules:'
) + $includedLines + @('', 'Skipped modules and reasons:') + $excludedLines + @('', 'Game-root file list:') + @($packagedNames | Sort-Object | ForEach-Object { "- $_" })
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'CANDIDATE-NOTES.txt'), ($noteLines -join "`r`n") + "`r`n", $utf8NoBom)

$installLines = @(
    'TEST PACKAGE — Xbox 360 Black Ops II DLC5 with Beta 2 script backport',
    '',
    'This package contains the 9 DLC5 map FastFiles, their 9 IPaks, English map localization, June world-map/UI candidates, August shared-support candidates, both owner-provided launchers, and a Beta 2 script-backported patch_zm.ff. It is not a full game.',
    '',
    'Required: a complete Xbox 360 Black Ops II base installation with its own base-game files (including base.ipak) and a separate test copy. The complete base game and any title update are not included.',
    '',
    'Before copying, make a separate test copy of the complete game and back up any existing files in its game root. Keep the original game installation untouched.',
    '',
    'Copy every file under game-root into the root of the test copy, preserving each filename. This folder contains all DLC5 map FastFiles/IPaks and the shared/UI assets needed by this candidate.',
    '',
    'The two patched launchers are side by side. Start with default_mp_patched.xex from the test copy using Aurora File Manager; do not replace default_mp.xex. default_mp_nosound.xex is the alternate owner-provided launcher for a separate comparison test.',
    '',
    'First confirm the world-map UI lists the DLC5 maps and that each of the 9 maps reaches gameplay without FastFile/IPAK/script errors. The map named zm_prototype is Nacht der Untoten. Then use Custom Games to check Beta 2 changes: on Moon (zm_moon), check Area 51 perks from the start and reduced hacked wall-buy ammo pricing; on Shangri-La (zm_temple), check the grenade wall-buy gives Semtex while the spawn grenade remains a frag.',
    '',
    'Record any launch/load error, crash, missing asset, or behavior difference. If a test fails, discard the test copy or restore its changed files from the backups. The original installation is not part of this package.',
    '',
    'SHA256SUMS.txt verifies all 45 packaged game-root files; hashes do not prove runtime compatibility or correct gameplay.'
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'INSTALL.txt'), ($installLines -join "`r`n") + "`r`n", $utf8NoBom)

foreach ($line in $sumLines) {
    if ($line -match '^([0-9a-f]{64}) \*(.+)$') {
        $expectedHash = $Matches[1]
        $relativePath = $Matches[2] -replace '/', '\'
        $packagedPath = Join-Path $packageRoot $relativePath
        if (-not (Test-Path -LiteralPath $packagedPath -PathType Leaf)) {
            throw "Packaged-file missing after build: $relativePath"
        }
        $actualHash = (Get-FileHash -LiteralPath $packagedPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "Packaged-file checksum failed: $relativePath"
        }
    }
}

Write-Output "Full DLC5 test package created: $packageRoot"
Write-Output "Game-root files: $($files.Count); logical size: $logicalBytes bytes"
Write-Output "Beta 2 candidate: $candidateHash; included script modules: $($candidate.included_modules.Count)"
Write-Output "SHA-256 checks passed for all packaged game files."
