param(
    [string]$OutputDirectory,
    [switch]$HardLinkFiles,
    [switch]$AllowUnverifiedSignature
)

$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$localRoot = Join-Path $repoRoot 'local-input'
$scanRoot = Join-Path $localRoot 'crybaby-test\beta2_script_backport_moonplus_20261012l'
$candidate = Join-Path $localRoot 'crybaby-test\candidates\patch_zm_beta2_moonplus_l_xmem.ff'
$candidateManifest = Join-Path $scanRoot 'beta2_script_backport_manifest_xmem.json'
$decodedZone = Join-Path $localRoot 'crybaby-test\verify_beta2_moonplus_l_xmem\zone_decompressed.dat'
$baselineFastFile = Join-Path $localRoot 'dlc5-alpha\shared-support-candidates\patch_zm.ff'
$baselineIpak = Join-Path $localRoot 'dlc5-alpha\shared-support-candidates\patch_zm.ipak'
$expectedBaselineFastFileHash = '0a21ac956b5d87a314d1a4aca753eeb39d5e1c8f7837f8baa9cffe92546b557c'
$expectedBaselineIpakHash = '84cea61461d03ada2278762ff686069639ca076aefeb4d9017c807d7f7f4dcc3'
$expectedModules = @(
    'zzz_zm_moona51perks.gsc',
    'zzz_zm_moongravfix.gsc',
    'zzz_zm_moonhackammo.gsc',
    'zzz_zm_moonsky.csc'
)
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'dist')).TrimEnd('\')

if (-not $AllowUnverifiedSignature) {
    throw 'This exploratory package reuses the August FastFile signature bytes without re-signing. Pass -AllowUnverifiedSignature only when intentionally creating a disposable console test package.'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $distRoot 'ZombiesDeclassified-Xbox360-Moon-4Fix-LZX-Test-20261012'
}
$packageRoot = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\')
if (-not $packageRoot.StartsWith($distRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must be a new folder under dist: $packageRoot"
}
if (Test-Path -LiteralPath $packageRoot) {
    throw "Refusing to overwrite an existing package: $packageRoot"
}

foreach ($path in @($candidate, $candidateManifest, $decodedZone, $baselineFastFile, $baselineIpak)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required package input not found: $path"
    }
}

$manifest = Get-Content -LiteralPath $candidateManifest -Raw | ConvertFrom-Json
$candidateBytes = [System.IO.File]::ReadAllBytes($candidate)
$candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
$zoneHash = (Get-FileHash -LiteralPath (Join-Path $scanRoot 'zone_decompressed.dat') -Algorithm SHA256).Hash.ToLowerInvariant()
$decodedHash = (Get-FileHash -LiteralPath $decodedZone -Algorithm SHA256).Hash.ToLowerInvariant()
$baselineFastFileHash = (Get-FileHash -LiteralPath $baselineFastFile -Algorithm SHA256).Hash.ToLowerInvariant()
$baselineIpakHash = (Get-FileHash -LiteralPath $baselineIpak -Algorithm SHA256).Hash.ToLowerInvariant()
$candidateMagic = [System.Text.Encoding]::ASCII.GetString($candidateBytes, 0, 8)
$candidateSignatureBytes = [byte[]]::new(0x100)
[System.Array]::Copy($candidateBytes, 0x38, $candidateSignatureBytes, 0, $candidateSignatureBytes.Length)
$candidateSignatureHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new($candidateSignatureBytes)) -Algorithm SHA256).Hash.ToLowerInvariant()
$actualModules = @($manifest.included_modules | Sort-Object)
$sortedExpectedModules = @($expectedModules | Sort-Object)

if ($candidateMagic -ne 'TAffx100' -or $manifest.container_provenance.compression -ne 'XMem LZX') {
    throw "Expected TAffx100 XMem/LZX candidate; found $candidateMagic / $($manifest.container_provenance.compression)."
}
if ($manifest.container_provenance.signature_state -ne 'copied_from_original_not_regenerated' -or $manifest.container_provenance.signature_validity -ne 'unverified') {
    throw 'Manifest signature state is not the expected unverified, copied-original state.'
}
if ($manifest.console_fastfile_validation -ne 'pending' -or -not $manifest.roundtrip_exact -or $manifest.candidate_sha256 -ne $candidateHash -or $manifest.candidate_bytes -ne $candidateBytes.Length) {
    throw 'Candidate bytes, round-trip, or validation status do not match the XMem manifest.'
}
if ($zoneHash -ne $decodedHash -or $zoneHash -ne $manifest.roundtrip_zone_sha256) {
    throw 'The XMem FastFile does not decode to the exact four-module candidate zone.'
}
if (($actualModules -join "`n") -cne ($sortedExpectedModules -join "`n")) {
    throw 'The candidate module list does not match the four expected Moon fixes.'
}
if ($baselineFastFileHash -ne $expectedBaselineFastFileHash -or $baselineIpakHash -ne $expectedBaselineIpakHash) {
    throw 'The August baseline patch pair hash changed; refusing to package.'
}
if ($candidateSignatureHash -ne $manifest.container_provenance.original_signature_sha256 -or $candidateSignatureHash -ne $manifest.container_provenance.output_signature_sha256) {
    throw 'Candidate signature bytes no longer match the provenance record.'
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
    'EXPERIMENTAL Xbox 360 BO2 DLC5 test — Moon four-fix XMem/LZX candidate',
    '',
    'This package changes four Moon-only Beta 2 script behaviors:',
    '1. Area 51 Speed Cola and Juggernog are powered at match start.',
    '2. Moon gravity correction is enabled to address frame-rate-dependent physics.',
    '3. The hacked wall-buy state is bridged to stock Xbox trigger objects so the reduced ammo price can apply.',
    '4. The Moon client sky-transition fix resends the normal-side sky state when the expected event is missing.',
    '',
    'Container: TAffx100 with Microsoft XMem/LZX compression and Salsa20 chunk encryption. The candidate decodes byte-for-byte to the intended four-module zone.',
    'Signature: the August source signature bytes were copied unchanged and were NOT regenerated or validated for the modified zone. Console acceptance is unknown. This package can still black-screen; it is a disposable test candidate, not a verified release.',
    "Candidate patch_zm.ff SHA-256: $candidateHash",
    "Matching August patch_zm.ipak SHA-256: $baselineIpakHash",
    "Game-root files: $($packageFiles.Count); logical bytes: $logicalBytes",
    "Modified script assets: $($manifest.modified_sources -join ', ')",
    "Minimum remaining script slot space: $(($manifest.fit_report.PSObject.Properties | ForEach-Object { $_.Value.remaining_bytes } | Measure-Object -Minimum).Minimum) bytes",
    "Static missing imports / arity mismatches: $((@($manifest.link_reports.PSObject.Properties | ForEach-Object { @($_.Value.missing).Count + @($_.Value.arity).Count }) | Measure-Object -Sum).Sum)",
    "Exact zone round trip: $($manifest.roundtrip_exact); zone SHA-256: $zoneHash",
    '',
    'No map art, menu UI, map FastFiles/IPaks, base.ipak, XEX launcher, or title update is included.'
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'CANDIDATE-NOTES.txt'), ($notes -join "`r`n") + "`r`n", $utf8NoBom)
$install = @(
    'EXPERIMENTAL TEST PACKAGE — four Moon script changes; FastFile signature unverified',
    '',
    'Use only a separate copy of the complete Xbox 360 BO2 installation that currently boots the known-good merged DLC5 build. Keep your original and known-good copy unchanged.',
    '',
    'Back up both current patch_zm.ff and patch_zm.ipak in the test copy. Copy both files from game-root into that same game root, replacing the pair together. Keep the launcher, title-update setup, other map files, and base.ipak unchanged.',
    '',
    'Test Moon (zm_moon): check the Area 51 perks, high-frame-rate gravity, hacked wall-buy price, and sky transition. This package makes no UI or world-map art change.',
    '',
    'The FastFile uses the Xbox LZX/XMem container layout, but its signature bytes were copied from the original file and not regenerated. If it black-screens, hangs, or behaves incorrectly, restore both backed-up patch_zm.ff and patch_zm.ipak together. Do not use it over your original install.',
    '',
    'Verify both game-root files against SHA256SUMS.txt before testing.'
)
[System.IO.File]::WriteAllText((Join-Path $packageRoot 'INSTALL.txt'), ($install -join "`r`n") + "`r`n", $utf8NoBom)

foreach ($line in $sumLines) {
    if ($line -match '^([0-9a-f]{64}) \*(.+)$') {
        $relative = $Matches[2] -replace '/', '\'
        $path = Join-Path $packageRoot $relative
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $Matches[1]) {
            throw "Package checksum failed: $relative"
        }
    }
}

Write-Output "Moon four-fix LZX test distribution created: $packageRoot"
Write-Output "Game-root files: $($packageFiles.Count); logical size: $logicalBytes bytes"
Write-Output 'Checksums passed. Signature validity and console runtime remain unverified.'
