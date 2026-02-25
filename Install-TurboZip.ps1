#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs TurboZip Windows Explorer context menu entries.

.PARAMETER ExePath
    Full path to turbozip.exe. Defaults to C:\Tools\turbozip\turbozip.exe

.PARAMETER Uninstall
    Switch to REMOVE all TurboZip context menu entries.

.EXAMPLE
    .\Install-TurboZip.ps1
    .\Install-TurboZip.ps1 -ExePath "D:\bin\turbozip.exe"
    .\Install-TurboZip.ps1 -Uninstall
#>
param(
    [string]$ExePath = "C:\Tools\turbozip\turbozip.exe",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$registryRoots = @(
    "HKLM:\SOFTWARE\Classes\*\shell\TurboZip",
    "HKLM:\SOFTWARE\Classes\Directory\shell\TurboZip",
    "HKLM:\SOFTWARE\Classes\Directory\Background\shell\TurboZip",
    "HKLM:\SOFTWARE\Classes\TurboZip.zip"
)

if ($Uninstall) {
    Write-Host "Removing TurboZip context menu entries..." -ForegroundColor Yellow
    foreach ($root in $registryRoots) {
        if (Test-Path $root) {
            Remove-Item -Path $root -Recurse -Force
            Write-Host "  Removed: $root" -ForegroundColor Gray
        }
    }
    $zipAssoc = "HKLM:\SOFTWARE\Classes\.zip\OpenWithProgids"
    if (Test-Path $zipAssoc) {
        Remove-ItemProperty -Path $zipAssoc -Name "TurboZip.zip" -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] TurboZip context menu entries removed." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $ExePath)) {
    Write-Warning "turbozip.exe not found at: $ExePath"
    Write-Warning "Context menu will still be registered. Place the .exe there before using it."
}

$exeEscaped = $ExePath.Replace("\", "\\")

function New-RegKey($path) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
}

Write-Host "Installing TurboZip context menu entries..." -ForegroundColor Cyan
Write-Host "  Executable: $ExePath" -ForegroundColor Gray

$base = "HKLM:\SOFTWARE\Classes"

foreach ($scope in @("*", "Directory", "Directory\Background")) {
    $key = "$base\$scope\shell\TurboZip"
    New-RegKey $key
    Set-ItemProperty -Path $key -Name "(Default)"  -Value "TurboZip"
    Set-ItemProperty -Path $key -Name "MUIVerb"    -Value "TurboZip"
    Set-ItemProperty -Path $key -Name "SubCommands" -Value ""
    Set-ItemProperty -Path $key -Name "Icon"        -Value "$ExePath,0"

    $compress = "$key\Shell\Compress"
    New-RegKey $compress
    $compressLabel = if ($scope -eq "Directory") { "TurboZip: Compress Folder" } `
                     elseif ($scope -eq "Directory\Background") { "TurboZip: Compress Current Folder" } `
                     else { "TurboZip: Compress" }
    Set-ItemProperty -Path $compress -Name "(Default)" -Value $compressLabel
    Set-ItemProperty -Path $compress -Name "Icon"      -Value "$ExePath,0"

    $compressTarget = if ($scope -eq "Directory\Background") { '"%V"' } else { '"%1"' }
    New-RegKey "$compress\command"
    Set-ItemProperty -Path "$compress\command" -Name "(Default)" `
        -Value "`"$ExePath`" zip $compressTarget"

    if ($scope -ne "Directory\Background") {
        $extract = "$key\Shell\Extract"
        New-RegKey $extract
        $extractLabel = if ($scope -eq "Directory") { "TurboZip: Extract Here" } else { "TurboZip: Extract Here" }
        Set-ItemProperty -Path $extract -Name "(Default)" -Value $extractLabel
        Set-ItemProperty -Path $extract -Name "Icon"      -Value "$ExePath,0"
        New-RegKey "$extract\command"
        Set-ItemProperty -Path "$extract\command" -Name "(Default)" `
            -Value "`"$ExePath`" unzip `"%1`""
    }
}

New-RegKey "$base\.zip\OpenWithProgids"
Set-ItemProperty -Path "$base\.zip\OpenWithProgids" -Name "TurboZip.zip" -Value ""

New-RegKey "$base\TurboZip.zip"
Set-ItemProperty -Path "$base\TurboZip.zip" -Name "(Default)" -Value "TurboZip Archive"
New-RegKey "$base\TurboZip.zip\shell\Extract"
Set-ItemProperty -Path "$base\TurboZip.zip\shell\Extract" -Name "(Default)" -Value "TurboZip: Extract Here"
Set-ItemProperty -Path "$base\TurboZip.zip\shell\Extract" -Name "Icon"      -Value "$ExePath,0"
New-RegKey "$base\TurboZip.zip\shell\Extract\command"
Set-ItemProperty -Path "$base\TurboZip.zip\shell\Extract\command" -Name "(Default)" `
    -Value "`"$ExePath`" unzip `"%1`""

Write-Host ""
Write-Host "[OK] TurboZip context menu installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Place turbozip.exe at: $ExePath"
Write-Host "  2. Right-click any file, folder, or .zip to see TurboZip options"
Write-Host ""
Write-Host "To uninstall: .\Install-TurboZip.ps1 -Uninstall" -ForegroundColor Gray
