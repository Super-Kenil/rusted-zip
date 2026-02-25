#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Rusted ZIP Windows Explorer context menu entries.

.PARAMETER ExePath
    Full path to rustedzip.exe. Defaults to C:\Tools\rustedzip\rustedzip.exe

.PARAMETER Uninstall
    Switch to REMOVE all Rusted ZIP context menu entries.

.EXAMPLE
    .\Install-RustedZip.ps1
    .\Install-RustedZip.ps1 -ExePath "D:\bin\rustedzip.exe"
    .\Install-RustedZip.ps1 -Uninstall
#>
param(
    [string]$ExePath = "C:\Tools\rustedzip\rustedzip.exe",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# All registry work via .NET Microsoft.Win32.Registry — avoids PowerShell
# registry provider wildcard issues with the literal '*' key name.
# ---------------------------------------------------------------------------

function CreateKey([string]$subPath) {
    return [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($subPath, $true)
}

function DeleteTree([string]$subPath) {
    $parent = Split-Path $subPath -Parent
    $child  = Split-Path $subPath -Leaf
    $pk = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($parent, $true)
    if ($pk) { $pk.DeleteSubKeyTree($child, $false); $pk.Close() }
}

function S([Microsoft.Win32.RegistryKey]$key, [string]$name, [string]$value) {
    # name="" sets the (Default) unnamed value
    $key.SetValue($name, $value, [Microsoft.Win32.RegistryValueKind]::String)
}

$classes = "SOFTWARE\Classes"

$verbPaths = @(
    "$classes\*\shell\RustedZip_Compress",
    "$classes\*\shell\RustedZip_Extract",
    "$classes\Directory\shell\RustedZip_Compress",
    "$classes\Directory\Background\shell\RustedZip_CompressBg",
    "$classes\RustedZip.zip"
)

# ---------------------------------------------------------------------------
# Uninstall — also cleans up any old TurboZip leftovers
# ---------------------------------------------------------------------------
if ($Uninstall) {
    Write-Host "Removing Rusted ZIP context menu entries..." -ForegroundColor Yellow

    foreach ($path in $verbPaths) {
        DeleteTree $path
        Write-Host "  Removed: HKLM\$path" -ForegroundColor Gray
    }

    # Clean up any old TurboZip keys from previous install attempts
    $oldPaths = @(
        "$classes\*\shell\TurboZip",
        "$classes\*\shell\TurboZip_Compress",
        "$classes\*\shell\TurboZip_Extract",
        "$classes\Directory\shell\TurboZip",
        "$classes\Directory\shell\TurboZip_Compress",
        "$classes\Directory\Background\shell\TurboZip",
        "$classes\Directory\Background\shell\TurboZip_CompressBg",
        "$classes\TurboZip.zip"
    )
    $oldCommandStore = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell"
    $oldStoreVerbs = @("TurboZip.Compress", "TurboZip.Extract", "TurboZip.CompressBgFolder")

    foreach ($path in $oldPaths) { DeleteTree $path }
    foreach ($v in $oldStoreVerbs) { DeleteTree "$oldCommandStore\$v" }

    # .zip progid associations
    $zipKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$classes\.zip\OpenWithProgids", $true)
    if ($zipKey) {
        $zipKey.DeleteValue("RustedZip.zip", $false)
        $zipKey.DeleteValue("TurboZip.zip", $false)
        $zipKey.Close()
    }

    Write-Host "[OK] Rusted ZIP uninstalled." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Warning "rustedzip.exe not found at: $ExePath"
    Write-Warning "Context menu will be registered; copy the .exe there to activate it."
}

Write-Host "Installing Rusted ZIP context menu entries..." -ForegroundColor Cyan
Write-Host "  Executable: $ExePath" -ForegroundColor Gray

# Files (*) — Compress
$k = CreateKey "$classes\*\shell\RustedZip_Compress"
S $k "" "Rusted ZIP: Compress"
S $k "Icon" "$ExePath,0"
$k.Close()
$k = CreateKey "$classes\*\shell\RustedZip_Compress\command"
S $k "" "`"$ExePath`" zip `"%1`""
$k.Close()
Write-Host "  [+] Files -> Compress" -ForegroundColor Gray

# Files (*) — Extract Here
$k = CreateKey "$classes\*\shell\RustedZip_Extract"
S $k "" "Rusted ZIP: Extract Here"
S $k "Icon" "$ExePath,0"
$k.Close()
$k = CreateKey "$classes\*\shell\RustedZip_Extract\command"
S $k "" "`"$ExePath`" unzip `"%1`""
$k.Close()
Write-Host "  [+] Files -> Extract Here" -ForegroundColor Gray

# Folders — Compress Folder
$k = CreateKey "$classes\Directory\shell\RustedZip_Compress"
S $k "" "Rusted ZIP: Compress Folder"
S $k "Icon" "$ExePath,0"
$k.Close()
$k = CreateKey "$classes\Directory\shell\RustedZip_Compress\command"
S $k "" "`"$ExePath`" zip `"%1`""
$k.Close()
Write-Host "  [+] Directories -> Compress Folder" -ForegroundColor Gray

# Folder background — Compress Current Folder
$k = CreateKey "$classes\Directory\Background\shell\RustedZip_CompressBg"
S $k "" "Rusted ZIP: Compress Current Folder"
S $k "Icon" "$ExePath,0"
$k.Close()
$k = CreateKey "$classes\Directory\Background\shell\RustedZip_CompressBg\command"
S $k "" "`"$ExePath`" zip `"%V`""
$k.Close()
Write-Host "  [+] Directory background -> Compress Current Folder" -ForegroundColor Gray

# .zip file-type association
$k = CreateKey "$classes\.zip\OpenWithProgids"
S $k "RustedZip.zip" ""
$k.Close()
$k = CreateKey "$classes\RustedZip.zip"
S $k "" "Rusted ZIP Archive"
$k.Close()
$k = CreateKey "$classes\RustedZip.zip\shell\extract"
S $k "" "Rusted ZIP: Extract Here"
S $k "Icon" "$ExePath,0"
$k.Close()
$k = CreateKey "$classes\RustedZip.zip\shell\extract\command"
S $k "" "`"$ExePath`" unzip `"%1`""
$k.Close()
Write-Host "  [+] .zip file type -> Extract Here" -ForegroundColor Gray

Write-Host ""
Write-Host "[OK] Rusted ZIP context menu installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "What you will see in Explorer:" -ForegroundColor Yellow
Write-Host "  Right-click any FILE   -> 'Rusted ZIP: Compress' and 'Rusted ZIP: Extract Here'"
Write-Host "  Right-click any FOLDER -> 'Rusted ZIP: Compress Folder'"
Write-Host "  Right-click empty SPACE-> 'Rusted ZIP: Compress Current Folder'"
Write-Host "  Right-click a .zip     -> 'Rusted ZIP: Extract Here'"
Write-Host ""
Write-Host "To uninstall: .\Install-RustedZip.ps1 -Uninstall" -ForegroundColor Gray
