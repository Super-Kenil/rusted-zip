# TurboZip

A high-performance CLI zip/unzip utility for Windows built with Rust, `zlib-ng`, and `rayon` for parallel compression.

---

## Features

- Multi-threaded compression via `rayon`
- `zlib-ng` backend (faster than stock zlib)
- Buffered I/O throughout (`BufReader` / `BufWriter`)
- Recursive folder compression with `walkdir`
- Windows Explorer right-click context menu integration
- Single portable `.exe` — no runtime required

---

## Project Structure

```
turbozip/
├── src/
│   └── main.rs
├── Cargo.toml
├── install_context_menu.reg      ← Double-click to install registry keys
├── Install-TurboZip.ps1          ← PowerShell alternative (recommended)
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

> zlib-ng requires a C compiler. Install **Visual Studio Build Tools** (free):
> https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
> Select: "Desktop development with C++"

Alternatively, use the GNU toolchain (no VS required):
```powershell
rustup target add x86_64-pc-windows-gnu
# Also requires: winget install StrawberryPerl.StrawberryPerl (for the C linker)
```

---

### Build Commands

**Standard release build (MSVC — recommended):**
```powershell
cd turbozip
cargo build --release --target x86_64-pc-windows-msvc
```

**GNU toolchain alternative:**
```powershell
cargo build --release --target x86_64-pc-windows-gnu
```

The compiled binary will be at:
```
turbozip\target\x86_64-pc-windows-msvc\release\turbozip.exe
```

This is a **fully self-contained, portable .exe** — no DLLs or runtime needed.

---

## Installation

### Step 1 — Place the binary

Copy `turbozip.exe` to:
```
C:\Tools\turbozip\turbozip.exe
```

You can also add this folder to your system PATH for CLI use anywhere:
```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    $env:Path + ";C:\Tools\turbozip",
    [System.EnvironmentVariableTarget]::Machine
)
```

---

### Step 2 — Install Context Menu (choose one method)

**Option A: PowerShell (recommended — supports custom paths)**
```powershell
# Run as Administrator
.\Install-TurboZip.ps1

# Custom exe location
.\Install-TurboZip.ps1 -ExePath "D:\bin\turbozip.exe"

# Uninstall
.\Install-TurboZip.ps1 -Uninstall
```

**Option B: Registry file**
1. If you used a different path than `C:\Tools\turbozip\`, open `install_context_menu.reg`
   in Notepad and replace every occurrence of `C:\\Tools\\turbozip\\turbozip.exe`
   with your actual path (keep double backslashes).
2. Double-click `install_context_menu.reg` → click Yes when prompted.

---

## CLI Usage

```
turbozip zip   <file_or_folder>    Compress a file or folder to .zip
turbozip unzip <archive.zip>       Extract a .zip archive
```

**Aliases:** `compress` / `z` and `extract` / `x` also work.

**Examples:**
```powershell
turbozip zip   C:\Projects\my_app\
turbozip zip   C:\Reports\Q4.docx
turbozip unzip C:\Downloads\release.zip
```

Output is placed in the same directory as the input:
- `my_app\` → `my_app.zip`
- `Q4.docx` → `Q4.zip`
- `release.zip` → `release\` (folder)

---

## Performance Notes

| Setting | Value |
|---|---|
| Compression backend | `zlib-ng` (C, highly optimized) |
| Compression level | 6 (balanced speed/size) |
| Read buffer | 512 KB per file |
| Write buffer | 1 MB |
| Directory walker | `walkdir` (zero-copy iterator) |
| Parallelism | `rayon` thread pool (auto-sized to CPU cores) |

Typical speedup over PowerShell's `Compress-Archive`: **3–8× faster** on multi-core machines.

---

## Cargo.toml Dependency Notes

The key dependency flags that enable `zlib-ng`:

```toml
flate2 = { version = "1.0", features = ["zlib-ng"], default-features = false }
zip   = { version = "0.6", default-features = false, features = ["deflate-zlib-ng"] }
```

This compiles `zlib-ng` from source and statically links it — no separate DLL needed.