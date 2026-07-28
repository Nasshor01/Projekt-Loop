# Apply Windows exe icon after Godot export (when rcedit isn't configured in Editor).
# Usage: powershell -ExecutionPolicy Bypass -File tools/apply_windows_icon.ps1 [optional-path-to-exe]

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$rcedit = Join-Path $root "tools\rcedit-x64.exe"
$ico = Join-Path $root "art\icons\game\logo.ico"

$exe = $args[0]
if (-not $exe) {
	$exe = "C:\SPB_Data\hra\builds\0.3.2\Projekt_LOOP_v0.3.2.exe"
}

if (-not (Test-Path $rcedit)) { throw "Missing rcedit: $rcedit" }
if (-not (Test-Path $ico)) { throw "Missing icon: $ico  (run: python tools/make_logo_ico.py)" }
if (-not (Test-Path $exe)) { throw "Missing exe: $exe" }

& $rcedit $exe `
	--set-icon $ico `
	--set-file-version "0.3.2.0" `
	--set-product-version "0.3.2.0" `
	--set-version-string CompanyName "Nasshor's Games" `
	--set-version-string ProductName "Projekt LOOP"

if ($LASTEXITCODE -ne 0) { throw "rcedit failed with exit $LASTEXITCODE" }

Write-Host "OK: icon applied to $exe"
Write-Host "If Explorer still shows old icon: press F5, or rename the file once."
