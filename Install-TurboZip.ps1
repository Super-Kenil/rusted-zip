#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs TurboZip Windows Explorer context menu entries (flat, no cascading).

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
# All registry work via .NET Microsoft.Win32.Registry — avoids PowerShell
# registry provider wildcard issues with the literal '*' key name.
# ---------------------------------------------------------------------------

function CreateKey([string]$subPath) {
    $k = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($subPath, $true)
    return $k
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

# Verb key paths to clean up on uninstall
$verbPaths = @(
    "$classes\*\shell\TurboZip_Compress",
    "$classes\*\shell\TurboZip_Extract",
    "$classes\Directory\shell\TurboZip_Compress",
    "$classes\Directory\Background\shell\TurboZip_CompressBg",
    "$classes\TurboZip.zip"
)

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if ($Uninstall) {
    Write-Host "Removing TurboZip context menu entries..." -ForegroundColor Yellow
    foreach ($path in $verbPaths) {
        DeleteTree $path
        Write-Host "  Removed: HKLM\$path" -ForegroundColor Gray
    }
    # Remove CommandStore verbs if present from previous install attempts
    $store = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell"
    foreach ($v in @("TurboZip.Compress","TurboZip.Extract","TurboZip.CompressBgFolder")) {
        DeleteTree "$store\$v"
    }
    # .zip progid association
    $zipKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$classes\.zip\OpenWithProgids", $true)
    if ($zipKey) { $zipKey.DeleteValue("TurboZip.zip", $false); $zipKey.Close() }

    Write-Host "[OK] TurboZip uninstalled." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Warning "turbozip.exe not found at: $ExePath"
    Write-Warning "Context menu will be registered; copy the .exe there to activate it."
}

Write-Host "Installing TurboZip context menu entries..." -ForegroundColor Cyan
Write-Host "  Executable: $ExePath" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# All files (*) — Compress
# ---------------------------------------------------------------------------
$k = CreateKey "$classes\*\shell\TurboZip_Compress"
S $k "" "TurboZip: Compress"
S $k "Icon" "$ExePath,0"
$k.Close()

$k = CreateKey "$classes\*\shell\TurboZip_Compress\command"
S $k "" "`"$ExePath`" zip `"%1`""
$k.Close()
Write-Host "  [+] Files -> Compress" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# All files (*) — Extract Here
# ---------------------------------------------------------------------------
$k = CreateKey "$classes\*\shell\TurboZip_Extract"
S $k "" "TurboZip: Extract Here"
S $k "Icon" "$ExePath,0"
$k.Close()

$k = CreateKey "$classes\*\shell\TurboZip_Extract\command"
S $k "" "`"$ExePath`" unzip `"%1`""
$k.Close()
Write-Host "  [+] Files -> Extract Here" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Folders (right-click on folder icon) — Compress Folder
# ---------------------------------------------------------------------------
$k = CreateKey "$classes\Directory\shell\TurboZip_Compress"
S $k "" "TurboZip: Compress Folder"
S $k "Icon" "$ExePath,0"
$k.Close()

$k = CreateKey "$classes\Directory\shell\TurboZip_Compress\command"
S $k "" "`"$ExePath`" zip `"%1`""
$k.Close()
Write-Host "  [+] Directories -> Compress Folder" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# Folder background (right-click on empty space) — Compress Current Folder
# ---------------------------------------------------------------------------
$k = CreateKey "$classes\Directory\Background\shell\TurboZip_CompressBg"
S $k "" "TurboZip: Compress Current Folder"
S $k "Icon" "$ExePath,0"
$k.Close()

$k = CreateKey "$classes\Directory\Background\shell\TurboZip_CompressBg\command"
S $k "" "`"$ExePath`" zip `"%V`""
$k.Close()
Write-Host "  [+] Directory background -> Compress Current Folder" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# .zip file-type association
# ---------------------------------------------------------------------------
$k = CreateKey "$classes\.zip\OpenWithProgids"
S $k "TurboZip.zip" ""
$k.Close()

$k = CreateKey "$classes\TurboZip.zip"
S $k "" "TurboZip Archive"
$k.Close()

$k = CreateKey "$classes\TurboZip.zip\shell\extract"
S $k "" "TurboZip: Extract Here"
S $k "Icon" "$ExePath,0"
$k.Close()

$k = CreateKey "$classes\TurboZip.zip\shell\extract\command"
S $k "" "`"$ExePath`" unzip `"%1`""
$k.Close()
Write-Host "  [+] .zip file type -> Extract Here" -ForegroundColor Gray

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[OK] TurboZip context menu installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "What you will see in Explorer:" -ForegroundColor Yellow
Write-Host "  Right-click any FILE   -> 'TurboZip: Compress' and 'TurboZip: Extract Here'"
Write-Host "  Right-click any FOLDER -> 'TurboZip: Compress Folder'"
Write-Host "  Right-click empty SPACE-> 'TurboZip: Compress Current Folder'"
Write-Host "  Right-click a .zip     -> 'TurboZip: Extract Here'"
Write-Host ""
Write-Host "To uninstall: .\Install-TurboZip.ps1 -Uninstall" -ForegroundColor Gray
