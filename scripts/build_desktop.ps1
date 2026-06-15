# Builds the OmniTune desktop app on Windows: compiles the C++ core to a DLL,
# then builds the Flutter Windows app and bundles the DLL next to the runner.
#
# Prerequisites:
#   - CMake + Visual Studio 2022 (MSVC) for the C++ core
#   - Flutter SDK on PATH for the app
#
# One-time setup (generates the Windows runner; Flutter must be installed):
#   cd app; flutter create --platforms=windows .
#
# Usage:
#   pwsh scripts/build_desktop.ps1            # release build
#   pwsh scripts/build_desktop.ps1 -Config Debug

param(
    [string]$Config = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "==> Building C++ core ($Config)..." -ForegroundColor Cyan
cmake -S "$root\core" -B "$root\core\build" | Out-Null
cmake --build "$root\core\build" --config $Config

$dll = "$root\core\build\$Config\TTPlayerCore.dll"
if (-not (Test-Path $dll)) { throw "Core DLL not found at $dll" }
Write-Host "    Core DLL: $dll" -ForegroundColor Green

if (-not (Test-Path "$root\app\windows")) {
    Write-Warning "app/windows runner not found. Run:  cd app; flutter create --platforms=windows ."
    Write-Warning "Then re-run this script."
    exit 1
}

Write-Host "==> Building Flutter Windows app..." -ForegroundColor Cyan
Push-Location "$root\app"
try {
    if ($Config -eq "Debug") { flutter build windows --debug } else { flutter build windows --release }
} finally {
    Pop-Location
}

# Bundle the DLL next to the runner exe so the FFI loader finds it (it searches
# the executable directory first).
$runnerDir = Get-ChildItem "$root\app\build\windows" -Recurse -Filter "app.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1 | ForEach-Object { $_.DirectoryName }
if ($runnerDir) {
    Copy-Item $dll -Destination $runnerDir -Force
    Write-Host "==> Bundled TTPlayerCore.dll into $runnerDir" -ForegroundColor Green
    Write-Host "Done. Launch: $runnerDir\app.exe" -ForegroundColor Green
} else {
    Write-Warning "Could not locate the built runner exe; copy $dll next to it manually."
}
