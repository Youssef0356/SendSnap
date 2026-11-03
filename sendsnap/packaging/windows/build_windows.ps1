# SendSnap Windows Release & Installer Builder
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   SendSnap Windows Builder (x64)      " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Flutter Release Build
Write-Host "[1/2] Building Flutter Windows Release..." -ForegroundColor Yellow
Set-Location (Join-Path $PSScriptRoot "..\..")
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed!" -ForegroundColor Red
    exit 1
}

# Step 2: Check for Inno Setup Compiler (ISCC.exe)
Write-Host "[2/2] Checking for Inno Setup Compiler..." -ForegroundColor Yellow
$isccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

$iscc = $isccPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($iscc) {
    Write-Host "Compiling setup wizard with Inno Setup..." -ForegroundColor Green
    & $iscc (Join-Path $PSScriptRoot "installer.iss")
    Write-Host "Installer created successfully in dist/windows/SendSnap-Setup-x64.exe!" -ForegroundColor Green
} else {
    Write-Host "Inno Setup (ISCC.exe) not found on PATH." -ForegroundColor Yellow
    Write-Host "Standalone release files are ready at: build\windows\x64\runner\Release\" -ForegroundColor Cyan
    Write-Host "To produce SendSnap-Setup-x64.exe, install Inno Setup 6 (https://jrsoftware.org/isdl.php) and run this script again." -ForegroundColor Gray
}
