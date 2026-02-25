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

# ---------------------------------------------------------------------------
# Use .NET Registry API directly so the literal '*' key name is never
# misinterpreted as a PowerShell wildcard glob by the registry provider.
# ---------------------------------------------------------------------------

function Open-HKLMKey([string]$subPath, [bool]$writable = $true) {
    return [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subPath, $writable)
}

function New-RegKey([string]$subPath) {
    # CreateSubKey is idempotent: opens existing or creates new
    $key = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($subPath, $true)
    $key.Close()
}

function Set-RegValue([string]$subPath, [string]$name, [string]$value) {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subPath, $true)
    # PowerShell name "(Default)" maps to the unnamed default value (empty string name)
    $regName = if ($name -eq "(Default)") { "" } else { $name }
    $key.SetValue($regName, $value, [Microsoft.Win32.RegistryValueKind]::String)
    $key.Close()
}

function Remove-RegKey([string]$subPath) {
    $parent = Split-Path $subPath -Parent
    $child  = Split-Path $subPath -Leaf
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($parent, $true)
    if ($key -ne $null) {
        $key.DeleteSubKeyTree($child, $false)   # $false = don't throw if missing
        $key.Close()
    }
}

function Test-RegKey([string]$subPath) {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subPath, $false)
    $exists = $key -ne $null
    if ($key) { $key.Close() }
    return $exists
}

# All paths relative to HKLM (no "HKLM:\" prefix - raw .NET subkey strings)
$base = "SOFTWARE\Classes"

$rootsToRemove = @(
    "$base\*\shell\TurboZip",
    "$base\Directory\shell\TurboZip",
    "$base\Directory\Background\shell\TurboZip",
    "$base\TurboZip.zip"
)

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if ($Uninstall) {
    Write-Host "Removing TurboZip context menu entries..." -ForegroundColor Yellow
    foreach ($subPath in $rootsToRemove) {
        if (Test-RegKey $subPath) {
            Remove-RegKey $subPath
            Write-Host "  Removed: HKLM\$subPath" -ForegroundColor Gray
        }
    }
    # Remove .zip association entry
    $zipAssoc = "$base\.zip\OpenWithProgids"
    if (Test-RegKey $zipAssoc) {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($zipAssoc, $true)
        $key.DeleteValue("TurboZip.zip", $false)
        $key.Close()
    }
    Write-Host "[OK] TurboZip context menu entries removed." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Warning "turbozip.exe not found at: $ExePath"
    Write-Warning "Context menu will still be registered. Place the .exe there before using it."
}

Write-Host "Installing TurboZip context menu entries..." -ForegroundColor Cyan
Write-Host "  Executable: $ExePath" -ForegroundColor Gray

foreach ($scope in @("*", "Directory", "Directory\Background")) {
    $key = "$base\$scope\shell\TurboZip"

    New-RegKey $key
    Set-RegValue $key "(Default)"   "TurboZip"
    Set-RegValue $key "MUIVerb"     "TurboZip"
    Set-RegValue $key "SubCommands" ""
    Set-RegValue $key "Icon"        "$ExePath,0"

    # -- Compress sub-verb --
    $compressLabel = switch ($scope) {
        "Directory"            { "TurboZip: Compress Folder" }
        "Directory\Background" { "TurboZip: Compress Current Folder" }
        default                { "TurboZip: Compress" }
    }
    $compressArg = if ($scope -eq "Directory\Background") { '"%V"' } else { '"%1"' }

    New-RegKey "$key\shell\compress"
    Set-RegValue "$key\shell\compress" "(Default)" $compressLabel
    Set-RegValue "$key\shell\compress" "Icon"      "$ExePath,0"

    New-RegKey "$key\shell\compress\command"
    Set-RegValue "$key\shell\compress\command" "(Default)" "`"$ExePath`" zip $compressArg"

    # -- Extract sub-verb (not available on folder background) --
    if ($scope -ne "Directory\Background") {
        New-RegKey "$key\shell\extract"
        Set-RegValue "$key\shell\extract" "(Default)" "TurboZip: Extract Here"
        Set-RegValue "$key\shell\extract" "Icon"      "$ExePath,0"

        New-RegKey "$key\shell\extract\command"
        Set-RegValue "$key\shell\extract\command" "(Default)" "`"$ExePath`" unzip `"%1`""
    }
}

# -- .zip file-type association --
New-RegKey "$base\.zip\OpenWithProgids"
$zipProgids = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$base\.zip\OpenWithProgids", $true)
$zipProgids.SetValue("TurboZip.zip", "", [Microsoft.Win32.RegistryValueKind]::String)
$zipProgids.Close()

New-RegKey "$base\TurboZip.zip"
Set-RegValue "$base\TurboZip.zip" "(Default)" "TurboZip Archive"

New-RegKey "$base\TurboZip.zip\shell\extract"
Set-RegValue "$base\TurboZip.zip\shell\extract" "(Default)" "TurboZip: Extract Here"
Set-RegValue "$base\TurboZip.zip\shell\extract" "Icon"      "$ExePath,0"

New-RegKey "$base\TurboZip.zip\shell\extract\command"
Set-RegValue "$base\TurboZip.zip\shell\extract\command" "(Default)" "`"$ExePath`" unzip `"%1`""

# -- Refresh shell --
Write-Host ""
Write-Host "[OK] TurboZip context menu installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Place turbozip.exe at: $ExePath"
Write-Host "  2. Right-click any file, folder, or .zip to see TurboZip options"
Write-Host ""
Write-Host "To uninstall: .\Install-TurboZip.ps1 -Uninstall" -ForegroundColor Gray
