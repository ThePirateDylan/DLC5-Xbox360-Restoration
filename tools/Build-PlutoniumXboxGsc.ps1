param(
    [Parameter(Mandatory = $true)]
    [string]$GscToolPath,

    [string]$SourcePath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Join-Path $repoRoot 'local-input\plutonium-beta2-source'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot 'local-input\plutonium-beta2-xb2-script-objects'
}

if (-not (Test-Path -LiteralPath $GscToolPath -PathType Leaf)) {
    throw "GSC Tool executable not found: $GscToolPath"
}
if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
    throw "Plutonium script source folder not found: $SourcePath"
}

$sourceFiles = @(
    Get-ChildItem -LiteralPath $SourcePath -File |
        Where-Object { $_.Extension -in '.gsc', '.csc' } |
        Sort-Object Name
)
if ($sourceFiles.Count -ne 72) {
    throw "Expected the 72 hash-verified Beta 2 GSC/CSC files; found $($sourceFiles.Count)."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Dlc5GscBuild-' + [guid]::NewGuid().ToString('N'))
$inputRoot = Join-Path $tempRoot 'source'
$runRoot = Join-Path $tempRoot 'run'
New-Item -ItemType Directory -Path $inputRoot, $runRoot | Out-Null

try {
    foreach ($sourceFile in $sourceFiles) {
        $inputPath = Join-Path $inputRoot $sourceFile.Name
        if ($sourceFile.Name -eq 'zzz_zm_exertvoice.gsc') {
            $text = [System.IO.File]::ReadAllText($sourceFile.FullName)
            $originalCondition = 'if ( getdvarint( "killvox" ) == 0 && getdvar( "killvox" ) != "" )'
            $xb2Condition = 'if ( getdvar( "killvox" ) == "0" )'
            if (-not $text.Contains($originalCondition)) {
                throw 'The upstream exertvoice toggle changed; review it before applying the Xbox compile compatibility rewrite.'
            }
            $text = $text.Replace($originalCondition, $xb2Condition)
            [System.IO.File]::WriteAllText($inputPath, $text, [System.Text.UTF8Encoding]::new($false))
        }
        else {
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $inputPath
        }
    }

    Push-Location -LiteralPath $runRoot
    try {
        foreach ($sourceFile in $sourceFiles) {
            $inputPath = Join-Path $inputRoot $sourceFile.Name
            $instance = if ($sourceFile.Extension -eq '.csc') { 'client' } else { 'server' }
            $compilerOutput = & $GscToolPath -m comp -g t6 -s xb2 -i $instance $inputPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "GSC Tool failed for $($sourceFile.Name): $($compilerOutput -join ' ')"
            }
        }
    }
    finally {
        Pop-Location
    }

    $compiledPath = Join-Path $runRoot 'compiled\t6'
    $compiledFiles = @(Get-ChildItem -LiteralPath $compiledPath -File | Sort-Object Name)
    if ($compiledFiles.Count -ne 72) {
        throw "Expected 72 compiled objects; found $($compiledFiles.Count)."
    }

    foreach ($compiledFile in $compiledFiles) {
        $bytes = [System.IO.File]::ReadAllBytes($compiledFile.FullName)
        $hasT6XboxHeader = $bytes.Length -ge 8 -and
            $bytes[0] -eq 0x80 -and $bytes[1] -eq 0x47 -and $bytes[2] -eq 0x53 -and $bytes[3] -eq 0x43 -and
            $bytes[4] -eq 0x0D -and $bytes[5] -eq 0x0A -and $bytes[7] -eq 0x06
        if (-not $hasT6XboxHeader) {
            throw "Unexpected T6/Xbox 360 VM header in $($compiledFile.Name)."
        }
    }

    $conflicts = [System.Collections.Generic.List[string]]::new()
    foreach ($compiledFile in $compiledFiles) {
        $existingPath = Join-Path $OutputPath $compiledFile.Name
        if (Test-Path -LiteralPath $existingPath -PathType Leaf) {
            $newHash = (Get-FileHash -LiteralPath $compiledFile.FullName -Algorithm SHA256).Hash
            $existingHash = (Get-FileHash -LiteralPath $existingPath -Algorithm SHA256).Hash
            if ($newHash -ne $existingHash) {
                $conflicts.Add($compiledFile.Name)
            }
        }
    }
    if ($conflicts.Count -gt 0) {
        throw "Refusing to overwrite compiled objects that differ: $($conflicts -join ', ')"
    }

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $added = 0
    foreach ($compiledFile in $compiledFiles) {
        $existingPath = Join-Path $OutputPath $compiledFile.Name
        if (-not (Test-Path -LiteralPath $existingPath -PathType Leaf)) {
            Copy-Item -LiteralPath $compiledFile.FullName -Destination $existingPath
            $added++
        }
    }

    $totalBytes = ($compiledFiles | Measure-Object -Property Length -Sum).Sum
    Write-Output "Verified $($compiledFiles.Count) T6/Xbox 360 VM revision 6 script objects ($totalBytes bytes); added $added new file(s) under $OutputPath."
    Write-Output 'These are FastFile inputs, not a ready-to-install package; runtime compatibility and FastFile integration remain unverified.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
