param(
    [string]$OutputDirectory,
    [switch]$CopyFiles
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$localRoot = Join-Path $repoRoot 'local-input'
$mapRoot = Join-Path $localRoot 'dlc5-alpha'
$augustSupport = Join-Path $mapRoot 'shared-support-candidates'
$juneUi = Join-Path $localRoot 'june-world-map-reference\first_playable'
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'dist')).TrimEnd('\')

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $distRoot 'ZombiesDeclassified-Xbox360-DLC5-UI-Map-Test-20261012'
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
function Add-PackageFile([string]$SourcePath, [string]$Name, [string]$Role) {
    $source = [System.IO.Path]::GetFullPath($SourcePath)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required UI/map test input not found: $source"
    }
    $item = Get-Item -LiteralPath $source
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Package inputs cannot be reparse points: $source"
    }
    if (-not $targetNames.Add($Name)) {
        throw "Duplicate game-root package path: $Name"
    }
    $files.Add([pscustomobject]@{ Source = $source; Name = $Name; Role = $Role })
}

$mapNames = @('asylum', 'cosmodrome', 'factory', 'moon', 'pentagon', 'prototype', 'sumpf', 'temple', 'theater')
foreach ($map in $mapNames) {
    Add-PackageFile (Join-Path $mapRoot "zm_$map.ff") "zm_$map.ff" 'August DLC5 map FastFile'
    Add-PackageFile (Join-Path $mapRoot "zm_$map.ipak") "zm_$map.ipak" 'August DLC5 map assets'
    Add-PackageFile (Join-Path $mapRoot "en_zm_${map}_loc.ff") "en_zm_${map}_loc.ff" 'English DLC5 map localization'
}

$supportSources = @{
    'common_mp.ff' = @{ Root = $augustSupport; Role = 'August shared support' }
    'common_zm.ff' = @{ Root = $juneUi; Role = 'June shared Zombies support' }
    'dlc5_load_zm.ff' = @{ Root = $augustSupport; Role = 'August DLC5 map loader' }
    'dlc5_load_zm.ipak' = @{ Root = $augustSupport; Role = 'August DLC5 loader assets' }
    'en_patch_loc_zm.ff' = @{ Root = $juneUi; Role = 'June world-map localization' }
    'en_patch_loc.ff' = @{ Root = $augustSupport; Role = 'August shared localization' }
    'en_patch_ui_loc_zm.ff' = @{ Root = $juneUi; Role = 'June world-map UI localization' }
    'frontend_patch.ff' = @{ Root = $juneUi; Role = 'June world-map frontend' }
    'patch_mp.ff' = @{ Root = $augustSupport; Role = 'August shared multiplayer support' }
    'patch_ui_mp.ff' = @{ Root = $augustSupport; Role = 'August shared multiplayer UI' }
    'patch_ui_zm.ff' = @{ Root = $juneUi; Role = 'June world-map Zombies UI' }
    'patch_zm.ff' = @{ Root = $augustSupport; Role = 'August baseline Zombies patch FastFile; no Beta 2 script backport' }
    'patch_zm.ipak' = @{ Root = $augustSupport; Role = 'August patch_zm matching asset archive' }
    'ui_mp.ff' = @{ Root = $augustSupport; Role = 'August multiplayer UI support' }
    'ui_viewer_zm.ff' = @{ Root = $juneUi; Role = 'June world-map UI viewer' }
    'ui_zm.ff' = @{ Root = $juneUi; Role = 'June world-map Zombies UI' }
}
foreach ($name in $supportSources.Keys) {
    $entry = $supportSources[$name]
    Add-PackageFile (Join-Path $entry.Root $name) $name $entry.Role
}

if ($files.Count -ne 43) {
    throw "Expected 43 game-root files (27 map/localization files and 16 support/UI files); found $($files.Count)."
}

$sourceDrive = [System.IO.Path]::GetPathRoot($files[0].Source)
$targetDrive = [System.IO.Path]::GetPathRoot($packageRoot)
if (-not $CopyFiles -and -not $sourceDrive.Equals($targetDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Hard-link mode requires sources and dist on the same drive. Use -CopyFiles to create independent files.'
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
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumLines.Add("$hash *game-root/$($file.Name)")
    $logicalBytes += (Get-Item -LiteralPath $destination).Length
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), [string[]]$sumLines, $utf8NoBom)
$patchHash = (Get-FileHash -LiteralPath (Join-Path $gameRoot 'patch_zm.ff') -Algorithm SHA256).Hash.ToLowerInvariant()
$patchIpakHash = (Get-FileHash -LiteralPath (Join-Path $gameRoot 'patch_zm.ipak') -Algorithm SHA256).Hash.ToLowerInvariant()
$storageMode = if ($CopyFiles) { 'Copied as independent files.' } else { 'Hard-linked to ignored local-input assets, minimizing extra local disk use. Copying to another drive transfers the full file contents.' }
$roleLines = @($files | Group-Object Role | Sort-Object Name | ForEach-Object { "- $($_.Name): $($_.Count) file(s)" })
$fileLines = @($files | Sort-Object Name | ForEach-Object { "- $($_.Name)" })

$notes = @(
    'Xbox 360 BO2 DLC5 UI/map test distribution',
    '',
    'Purpose: test the available Xbox 360 DLC5 map and world-map UI candidates with the stable August patch_zm.ff/.ipak pair. This package intentionally does not include the Beta 2 script-backported FastFile or any launcher executable.',
    '',
    'This is not a full game. It excludes the base game, base.ipak, title update, and PC Beta 2 assets. The raw Plutonium Beta 2 menu Lua sources are not compiled or included; the UI files here are the available June Xbox world-map UI candidates.',
    '',
    "Game-root files: $($files.Count); logical size: $logicalBytes bytes",
    "Local storage: $storageMode",
    "Baseline patch_zm.ff SHA-256: $patchHash",
    "Matching patch_zm.ipak SHA-256: $patchIpakHash",
    'Beta 2 script modules included: 0 (the previous Beta 2 FastFile black-screened on console)',
    '',
    "File groups:`r`n$($roleLines -join [Environment]::NewLine)",
    '',
    'Game-root file list:',
    ($fileLines -join [Environment]::NewLine)
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'CANDIDATE-NOTES.txt'), ($notes -join "`r`n") + "`r`n", $utf8NoBom)

$install = @(
    'TEST PACKAGE — Xbox 360 BO2 DLC5 maps and world-map UI',
    '',
    'Use a separate copy of a complete Xbox 360 BO2 installation. Keep your original and known-good merged build unchanged.',
    '',
    'Copy all 43 files from game-root into the root of the separate test copy, preserving filenames. This package includes the stable August patch_zm.ff/.ipak pair and the June Xbox world-map UI candidates. It contains no XEX files; keep your current launcher and title-update setup unchanged.',
    '',
    'This test does not include the Beta 2 script backport. Its previous patch_zm.ff black-screened on console, so it has been held out. The PC Beta 2 mainlobby.lua and scoreboard.lua sources are also not Xbox-ready and are not included.',
    '',
    'After copying, check the Zombies world-map menu for DLC5 entries and UI behavior, then try each DLC5 map. The Giant is zm_factory; Nacht der Untoten is zm_prototype.',
    '',
    'SHA256SUMS.txt verifies the 43 packaged game-root files. File hashes do not establish console runtime compatibility.'
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'INSTALL.txt'), ($install -join "`r`n") + "`r`n", $utf8NoBom)

foreach ($line in $sumLines) {
    if ($line -match '^([0-9a-f]{64}) \*(.+)$') {
        $expected = $Matches[1]
        $relative = $Matches[2] -replace '/', '\'
        $path = Join-Path $packageRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Packaged-file missing after build: $relative"
        }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "Packaged-file checksum failed: $relative"
        }
    }
}

Write-Output "UI/map test distribution created: $packageRoot"
Write-Output "Game-root files: $($files.Count); logical size: $logicalBytes bytes"
Write-Output 'SHA-256 checks passed for all packaged game files.'
