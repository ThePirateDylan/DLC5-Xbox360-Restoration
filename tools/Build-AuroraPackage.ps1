param(
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Join-Path $repoRoot 'package\staging'
}

if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "Package staging folder not found: $SourcePath"
}

$sourceRoot = (Resolve-Path -LiteralPath $SourcePath).Path.TrimEnd('\')
$sourceRootItem = Get-Item -LiteralPath $sourceRoot
if (($sourceRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw 'Package staging cannot be a symbolic link or other reparse point.'
}

$items = @(Get-ChildItem -LiteralPath $sourceRoot -Force -Recurse -ErrorAction Stop)
$reparseItems = @($items | Where-Object {
    ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
})
if ($reparseItems.Count -gt 0) {
    throw 'Package staging cannot contain symbolic links or other reparse points.'
}

$files = @($items | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName)
if ($files.Count -eq 0) {
    throw 'Package staging is empty. Add the finished Xbox 360 files before building.'
}

$outputRoot = Join-Path $repoRoot 'dist'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$packageRoot = Join-Path $outputRoot "ZombiesDeclassified-Xbox360-$stamp"
if (Test-Path -LiteralPath $packageRoot) {
    throw "Output already exists; refusing to overwrite it: $packageRoot"
}

$gameRoot = Join-Path $packageRoot 'game-root'
New-Item -ItemType Directory -Path $gameRoot -Force | Out-Null

$manifestLines = [System.Collections.Generic.List[string]]::new()
$totalBytes = [int64]0
foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
    $destination = Join-Path $gameRoot $relativePath
    $destinationDirectory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination

    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestPath = ('game-root/' + $relativePath.Replace('\', '/'))
    $manifestLines.Add("$hash *$manifestPath")
    $totalBytes += $file.Length
}

$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines(
    (Join-Path $packageRoot 'SHA256SUMS.txt'),
    [string[]]$manifestLines.ToArray(),
    $encoding
)
[System.IO.File]::WriteAllText(
    (Join-Path $packageRoot 'INSTALL.txt'),
    "Copy the contents of 'game-root' into the corresponding paths of your existing Xbox 360 Black Ops II installation with Aurora File Manager.`r`n`r`nThis package contains project files only; it is not a full game or DLC installer. Confirm the target game layout and back up your own files before copying. The package builder does not modify the console or choose a destination for you.`r`n",
    $encoding
)

Write-Output "Package created: $packageRoot"
Write-Output ("Files: {0}; payload: {1:N2} MB" -f $files.Count, ($totalBytes / 1MB))
