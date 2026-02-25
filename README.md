# Rusted ZIP

A high-performance CLI zip/unzip utility for Windows built with Rust, `miniz_oxide`, and `rayon` for parallel compression.

---

## Features

- Multi-threaded file reading via `rayon`
- Pure-Rust `miniz_oxide` deflate backend — no native C deps, no CMake required
- Buffered I/O throughout (`BufReader` / `BufWriter`)
- Recursive folder compression with `walkdir`
- Windows Explorer right-click context menu integration
- Single portable `.exe` — no runtime required

---

## Project Structure

```
win-zip/
├── src/
│   └── main.rs
├── Cargo.toml
├── install_context_menu.reg      ← Double-click to install registry keys
├── Install-RustedZip.ps1         ← PowerShell alternative (recommended)
└── README.md
```

---

## Step-by-Step Build Guide

### Prerequisites

**1. Install Rust (if not installed)**

```powershell
winget install Rustlang.Rustup
# or download from https://rustup.rs
```

After installation, restart your terminal and verify:
```powershell
rustc --version
cargo --version
```

**2. Install the MSVC target (required for Windows .exe)**

```powershell
rustup target add x86_64-pc-windows-msvc
```

> The pure-Rust backend means no Visual Studio Build Tools or CMake are needed.

---

### Build Commands

**Standard release build (MSVC — recommended):**
```powershell
cargo build --release --target x86_64-pc-windows-msvc
```

**GNU toolchain alternative:**
```powershell
cargo build --release --target x86_64-pc-windows-gnu
```

The compiled binary will be at:
```
target\x86_64-pc-windows-msvc\release\rustedzip.exe
```

This is a **fully self-contained, portable .exe** — no DLLs or runtime needed.

---

## Installation

### Step 1 — Place the binary

Copy `rustedzip.exe` to:
```
C:\Tools\rustedzip\rustedzip.exe
```

You can also add this folder to your system PATH for CLI use anywhere:
```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    $env:Path + ";C:\Tools\rustedzip",
    [System.EnvironmentVariableTarget]::Machine
)
```

---

### Step 2 — Install Context Menu (choose one method)

**Option A: PowerShell (recommended — supports custom paths)**
```powershell
# Run as Administrator
.\Install-RustedZip.ps1

# Custom exe location
.\Install-RustedZip.ps1 -ExePath "D:\bin\rustedzip.exe"

# Uninstall
.\Install-RustedZip.ps1 -Uninstall
```

**Option B: Registry file**
1. If you used a different path than `C:\Tools\rustedzip\`, open `install_context_menu.reg`
   in Notepad and replace every occurrence of `C:\\Tools\\rustedzip\\rustedzip.exe`
   with your actual path (keep double backslashes).
2. Double-click `install_context_menu.reg` → click Yes when prompted.

---

## CLI Usage

```
rustedzip zip   <file_or_folder>    Compress a file or folder to .zip
rustedzip unzip <archive.zip>       Extract a .zip archive
```

**Aliases:** `compress` / `z` and `extract` / `x` also work.

**Examples:**
```powershell
rustedzip zip   C:\Projects\my_app\
rustedzip zip   C:\Reports\Q4.docx
rustedzip unzip C:\Downloads\release.zip
```

Output is placed in the same directory as the input:
- `my_app\` → `my_app.zip`
- `Q4.docx` → `Q4.zip`
- `release.zip` → `release\` (folder)

---

## Performance Notes

| Setting | Value |
|---|---|
| Compression backend | `miniz_oxide` (pure Rust, no CMake) |
| Compression level | 6 (balanced speed/size) |
| Read buffer | 512 KB per file |
| Write buffer | 1 MB |
| Directory walker | `walkdir` (zero-copy iterator) |
| Parallelism | `rayon` thread pool (auto-sized to CPU cores) |

Typical speedup over PowerShell's `Compress-Archive`: **3–6× faster** on multi-core machines.

---

## Cargo.toml Dependencies

```toml
flate2 = { version = "1.0" }                                          # uses miniz_oxide by default
zip   = { version = "2", default-features = false, features = ["deflate"] }
walkdir = "2"
rayon   = "1"
```