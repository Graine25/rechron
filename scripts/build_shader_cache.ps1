# build_shader_cache.ps1
# Extracts PKZ archives and runs XenosRecomp to produce generated/shader_cache.cpp.
#
# Usage:
#   .\scripts\build_shader_cache.ps1
#   .\scripts\build_shader_cache.ps1 -XRBuildDir "C:\my\xenosrecomp_build"
#   .\scripts\build_shader_cache.ps1 -SkipExtract    # reuse existing paks/
#   .\scripts\build_shader_cache.ps1 -SkipBuild      # assume XenosRecomp already built

param(
    [string]$XRBuildDir  = "C:\tmp\xenosrecomp_build",
    [switch]$SkipBuild,
    [switch]$SkipExtract
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot    = Split-Path $PSScriptRoot -Parent
$XRSource    = Join-Path $RepoRoot "thirdparty\XenosRecomp"
$XRExe       = Join-Path $XRBuildDir  "XenosRecomp\XenosRecomp.exe"
$BmsScript   = Join-Path $RepoRoot "thirdparty\quickbms\BeenoxSM_Console.bms"
$QuickBms    = Join-Path $RepoRoot "thirdparty\quickbms\quickbms.exe"
$PkzDir      = Join-Path $RepoRoot "assets\Data"
$PaksDir     = Join-Path $RepoRoot "paks"
$ShaderCommon= Join-Path $XRSource  "XenosRecomp\shader_common.h"
$OutputCpp   = Join-Path $RepoRoot "generated\shader_cache.cpp"

# ── 1. Build XenosRecomp ────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Host "[1/3] Building XenosRecomp..."

    $clang = "C:\Program Files\LLVM\bin\clang.exe"
    $clangpp = "C:\Program Files\LLVM\bin\clang++.exe"
    if (-not (Test-Path $clang)) {
        Write-Error "clang not found at '$clang'. Install LLVM or set the path manually."
    }

    if (Test-Path $XRBuildDir) { Remove-Item $XRBuildDir -Recurse -Force }

    cmake -S $XRSource -B $XRBuildDir -G Ninja `
        -DCMAKE_C_COMPILER=$clang `
        -DCMAKE_CXX_COMPILER=$clangpp `
        -DCMAKE_BUILD_TYPE=Release | Out-Null

    cmake --build $XRBuildDir --config Release --parallel
    if ($LASTEXITCODE -ne 0) { Write-Error "XenosRecomp build failed." }
    Write-Host "  Built: $XRExe"
} else {
    Write-Host "[1/3] Skipping XenosRecomp build (using $XRExe)"
    if (-not (Test-Path $XRExe)) { Write-Error "XenosRecomp.exe not found at '$XRExe'." }
}

# ── 2. Extract PKZ → paks/ ──────────────────────────────────────────────────
if (-not $SkipExtract) {
    Write-Host "[2/3] Extracting PKZ files with quickbms..."
    if (Test-Path $PaksDir) { Remove-Item "$PaksDir\*" -Force -ErrorAction SilentlyContinue }
    else { New-Item -ItemType Directory -Path $PaksDir | Out-Null }

    $pkzFiles = Get-ChildItem "$PkzDir\*.pkz"
    $total = $pkzFiles.Count
    $i = 0
    foreach ($f in $pkzFiles) {
        $i++
        $proc = Start-Process -FilePath $QuickBms `
            -ArgumentList @("-o", $BmsScript, $f.FullName, $PaksDir) `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput "$env:TEMP\qbms_out.txt" `
            -RedirectStandardError  "$env:TEMP\qbms_err.txt"
        if ($i % 20 -eq 0 -or $i -eq $total) {
            Write-Host "  [$i/$total] $($f.Name)"
        }
    }
    $pakCount = (Get-ChildItem "$PaksDir\*.pak" -ErrorAction SilentlyContinue).Count
    Write-Host "  $pakCount .pak files extracted."
} else {
    $pakCount = (Get-ChildItem "$PaksDir\*.pak" -ErrorAction SilentlyContinue).Count
    Write-Host "[2/3] Skipping extraction (using $pakCount existing .pak files in paks/)"
}

# ── 3. Run XenosRecomp → generated/shader_cache.cpp ────────────────────────
Write-Host "[3/3] Running XenosRecomp shader recompiler..."

$proc = Start-Process -FilePath $XRExe `
    -ArgumentList @($PaksDir, $OutputCpp, $ShaderCommon) `
    -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput "$env:TEMP\xr_out.txt" `
    -RedirectStandardError  "$env:TEMP\xr_err.txt"

$stderr = Get-Content "$env:TEMP\xr_err.txt" -Raw -ErrorAction SilentlyContinue
if ($stderr) { Write-Host $stderr }

$stdout = Get-Content "$env:TEMP\xr_out.txt" -Raw -ErrorAction SilentlyContinue
if ($stdout) { Write-Host $stdout }

if ($proc.ExitCode -ne 0) {
    Write-Error "XenosRecomp failed with exit code $($proc.ExitCode)."
}

$size = [math]::Round((Get-Item $OutputCpp).Length / 1MB, 1)
Write-Host ""
Write-Host "Done. generated/shader_cache.cpp  ($size MB)"
