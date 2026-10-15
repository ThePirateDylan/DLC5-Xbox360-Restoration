param(
    [string]$OutputDirectory,
    [switch]$HardLinkFiles
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$localRoot = Join-Path $repoRoot 'local-input'
$candidate = Join-Path $localRoot 'crybaby-test\candidates\patch_zm_beta2_moona51perks_k.ff'
$candidateManifest = Join-Path $localRoot 'crybaby-test\beta2_script_backport_moona51_20261012k\beta2_script_backport_manifest.json'
$sourceScan = Join-Path $localRoot 'crybaby-test\patch_zm_scan\zone_decompressed.dat'
$sourceScanHeader = Join-Path $localRoot 'crybaby-test\patch_zm_scan\ff_header.bin'
$baselineFastFile = Join-Path $localRoot 'dlc5-alpha\shared-support-candidates\patch_zm.ff'
$baselineIpak = Join-Path $localRoot 'dlc5-alpha\shared-support-candidates\patch_zm.ipak'
$expectedBaselineFastFileHash = '0a21ac956b5d87a314d1a4aca753eeb39d5e1c8f7837f8baa9cffe92546b557c'
$expectedBaselineIpakHash = '84cea61461d03ada2278762ff686069639ca076aefeb4d9017c807d7f7f4dcc3'
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'dist')).TrimEnd('\')

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $distRoot 'ZombiesDeclassified-Xbox360-Moon-Area51-Perks-Test-20261012'
}
$packageRoot = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if (-not $packageRoot.StartsWith($distRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must be a new folder under dist: $packageRoot"
}
if (Test-Path -LiteralPath $packageRoot) {
    throw "Refusing to overwrite an existing package: $packageRoot"
}

foreach ($path in @($candidate, $candidateManifest, $sourceScan, $sourceScanHeader, $baselineFastFile, $baselineIpak)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required test-package input not found: $path"
    }
}

$manifest = Get-Content -LiteralPath $candidateManifest -Raw | ConvertFrom-Json
$candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
$candidateHeader = [System.IO.File]::ReadAllBytes($candidate)
$candidateMagic = [System.Text.Encoding]::ASCII.GetString($candidateHeader, 0, 8)
$scanHash = (Get-FileHash -LiteralPath $sourceScan -Algorithm SHA256).Hash.ToLowerInvariant()
$scanHeaderHash = (Get-FileHash -LiteralPath $sourceScanHeader -Algorithm SHA256).Hash.ToLowerInvariant()
$baselineFastFileHash = (Get-FileHash -LiteralPath $baselineFastFile -Algorithm SHA256).Hash.ToLowerInvariant()
$baselineIpakHash = (Get-FileHash -LiteralPath $baselineIpak -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifest.included_modules.Count -ne 1 -or $manifest.included_modules[0] -ne 'zzz_zm_moona51perks.gsc') {
    throw 'This test package accepts only the one-module Area 51 perks candidate.'
}
if ($candidateMagic -ne 'TAffx100' -or $manifest.console_fastfile_validation -ne 'passed') {
    throw "Refusing to package an unvalidated FastFile for Xbox testing. Candidate magic is $candidateMagic; require a validated console-compatible container and console_fastfile_validation='passed' in the manifest."
}
if (-not $manifest.roundtrip_exact -or $manifest.candidate_sha256 -ne $candidateHash -or $manifest.build_provenance.input_zone_sha256 -ne $scanHash) {
    throw 'Candidate hash, input-zone hash, or exact FastFile round-trip verification does not match the build manifest.'
}
if ($baselineFastFileHash -ne $expectedBaselineFastFileHash -or $manifest.build_provenance.input_ff_header_sha256 -ne $scanHeaderHash) {
    throw 'Candidate scan header does not match the identified August baseline patch_zm.ff.'
}
if ($baselineIpakHash -ne $expectedBaselineIpakHash) {
    throw "The August baseline patch_zm.ipak hash changed: $baselineIpakHash"
}

$sourceDrive = [System.IO.Path]::GetPathRoot($candidate)
$targetDrive = [System.IO.Path]::GetPathRoot($packageRoot)
if ($HardLinkFiles -and -not $sourceDrive.Equals($targetDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Hard-link mode requires the source and dist folders on the same drive.'
}

$gameRoot = Join-Path $packageRoot 'game-root'
New-Item -ItemType Directory -Path $gameRoot -Force | Out-Null
$packageFiles = @(
    [pscustomobject]@{ Source = $candidate; Name = 'patch_zm.ff' },
    [pscustomobject]@{ Source = $baselineIpak; Name = 'patch_zm.ipak' }
)
$sumLines = [System.Collections.Generic.List[string]]::new()
$logicalBytes = [long]0
foreach ($file in $packageFiles) {
    $sourceItem = Get-Item -LiteralPath $file.Source
    if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Package source cannot be a reparse point: $($file.Source)"
    }
    $destination = Join-Path $gameRoot $file.Name
    if ($HardLinkFiles) {
        New-Item -ItemType HardLink -Path $destination -Target $file.Source | Out-Null
    } else {
        Copy-Item -LiteralPath $file.Source -Destination $destination
    }
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumLines.Add("$hash *game-root/$($file.Name)")
    $logicalBytes += (Get-Item -LiteralPath $destination).Length
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines((Join-Path $packageRoot 'SHA256SUMS.txt'), [string[]]$sumLines, $utf8NoBom)
$notes = @(
    'Experimental Xbox 360 BO2 DLC5 script test: Moon Area 51 perks at startup',
    '',
    'This candidate contains exactly one Beta 2 script module: zzz_zm_moona51perks.gsc. It is guarded by mapname == zm_moon and is intended to power on the Speed Cola and Juggernog machines in Moon Area 51 from the beginning of the match.',
    '',
    "Candidate patch_zm.ff SHA-256: $candidateHash",
    "August source patch_zm.ff SHA-256: $baselineFastFileHash",
    "Matching August patch_zm.ipak SHA-256: $baselineIpakHash",
    "Game-root files: $($packageFiles.Count); logical bytes: $logicalBytes",
    "GSC compiler: $($manifest.build_provenance.gsc_tool_version)",
    "Changed stock script assets: $($manifest.modified_sources -join ', ')",
    "Minimum remaining payload space: $(($manifest.fit_report.PSObject.Properties | ForEach-Object { $_.Value.remaining_bytes } | Measure-Object -Minimum).Minimum) bytes",
    "Static link missing imports/arity mismatches: $((@($manifest.link_reports.PSObject.Properties | ForEach-Object { @($_.Value.missing).Count + @($_.Value.arity).Count }) | Measure-Object -Sum).Sum)",
    "Exact zone round trip: $($manifest.roundtrip_exact); zone SHA-256: $($manifest.roundtrip_zone_sha256)",
    '',
    'This candidate has not been verified in Xenia or on an Xbox 360. A previous 47-module candidate black-screened on console; this reduced build is an isolation attempt, not a runtime guarantee.',
    'No UI changes, Beta 2 map art, DLC5 map FastFiles, full game files, base.ipak, XEX launcher, or title update are included.'
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'CANDIDATE-NOTES.txt'), ($notes -join "`r`n") + "`r`n", $utf8NoBom)
$install = @(
    'EXPERIMENTAL TEST PACKAGE — Moon Area 51 perks startup fix',
    '',
    'Use only a separate test copy of the complete Xbox 360 BO2 installation with the known-good merged DLC5 build. Keep your original and known-good copy unchanged.',
    '',
    'Back up both current patch_zm.ff and patch_zm.ipak in the test copy. Copy both files from game-root into that same game root, replacing the pair together. Keep the launcher, title-update setup, other map files, and base.ipak exactly as in the known-good copy.',
    '',
    'Test only Moon (zm_moon): start a match and check whether the Area 51 Speed Cola and Juggernog perk machines are powered from the beginning. The module exits immediately on all other maps. This package makes no world-map art or UI changes.',
    '',
    'If the game black-screens, hangs, or behaves incorrectly, restore both backed-up patch_zm.ff and patch_zm.ipak together. Do not use this package over your original install.',
    '',
    'This is an experimental candidate. The script compiles, fits its existing slots, has no reported missing imports or argument mismatches, and round-trips exactly. The rebuilt FastFile has not yet passed a runtime test on the console.',
    '',
    'Verify the two game-root files with SHA256SUMS.txt before testing.'
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'INSTALL.txt'), ($install -join "`r`n") + "`r`n", $utf8NoBom)

foreach ($line in $sumLines) {
    if ($line -match '^([0-9a-f]{64}) \*(.+)$') {
        $expected = $Matches[1]
        $relative = $Matches[2] -replace '/', '\'
        $path = Join-Path $packageRoot $relative
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "Package checksum failed: $relative"
        }
    }
}

Write-Output "Moon Area 51 test distribution created: $packageRoot"
Write-Output "Game-root files: $($packageFiles.Count); logical size: $logicalBytes bytes"
Write-Output 'SHA-256 checks passed for both game-root files.'
