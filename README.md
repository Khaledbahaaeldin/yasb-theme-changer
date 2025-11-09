# nightrider20797 Theme Changer for YASB

```text
  _   _ _       _     _        _     _         ___   ___ ______ ___ ______ 
 | \ | (_)     | |   | |      (_)   | |       |__ \ / _ \____  / _ \____  |
 |  \| |_  __ _| |__ | |_ _ __ _  __| | ___ _ __ ) | | | |  / / (_) |  / / 
 | . ` | |/ _` | '_ \| __| '__| |/ _` |/ _ \ '__/ /| | | | / / \__, | / /  
 | |\  | | (_| | | | | |_| |  | | (_| |  __/ | / /_| |_| |/ /    / / / /   
 |_| \_|_|\__, |_| |_|\__|_|  |_|\__,_|\___|_||____|\___//_/    /_/ /_/    
           __/ |                                                           
          |___/                                                            
```

- A neon-soaked control center for [YASB](https://github.com/amnweb/yasb) that weaponizes your wallpaper library, remixes your bar palette in real time, and keeps both desktop and lock screen perfectly in sync—no clicks, no fuss, just chromatic swagger.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [1. Install YASB](#1-install-yasb)
  - [2. Install Python 3.11 with pywal](#2-install-python-311-with-pywal)
  - [3. Install PowerShell modules (optional)](#3-install-powershell-modules-optional)
  - [4. Clone & Copy Assets](#4-clone--copy-assets)
- [Configuration](#configuration)
  - [Wallpaper Library](#wallpaper-library)
  - [YASB Styles](#yasb-styles)
  - [Theme State](#theme-state)
- [Running the Theme Switcher](#running-the-theme-switcher)
  - [Interactive Menu](#interactive-menu)
  - [Command-line Flags](#command-line-flags)
  - [Desktop Shortcut](#desktop-shortcut)
- [How It Works](#how-it-works)
  - [refresh-yasb-theme.ps1](#refresh-yasb-themeps1)
  - [update_yasb_palette.py](#update_yasb_palettepy)
  - [Lock Screen Sync](#lock-screen-sync)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- Dynamic wallpaper-driven color palettes via `pywal`, with automatic fallbacks across `colorthief`, `wal`, and `haishoku` backends.
- YASB stylesheet (`styles.css`) and widget configuration (`config.yaml`) patched in-place for each run.
- Hacker-flair terminal logging with cinematic sequences and timestamps.
- Menu-driven PowerShell theme selector with stateful wallpaper rotation per theme folder.
- Windows lock screen wallpaper synchronization using WinRT APIs.
- Automatic exit-on-success to avoid lingering PowerShell windows when launched via shortcut.
- Marketing-grade theatrics: every run plays out like a covert ops briefing, perfect for stream overlays or bragging rights.

## Requirements

| Component | Purpose | Notes |
|-----------|---------|-------|
| Windows 10/11 | Operating system | Required for YASB and lock screen APIs |
| [YASB](https://github.com/DenBot/YASB) | Status bar | Install first and verify it runs |
| Python 3.11 (64-bit) | Palette scripting | Required for `pywal` and Windows lock screen WinRT bindings |
| `pywal` 3.3.0 | Palette generation | Installed into Python 3.11 user environment |
| PowerShell 5.1/7+ | Automation scripts | Scripts use standard cmdlets, no extra modules |
| [ImageMagick](https://imagemagick.org/script/download.php) (optional) | Additional pywal backend | If installed, `wal` backend will leverage it |

### Python Dependencies

Install these into Python 3.11:

- `pywal`
- `colorthief`
- `haishoku`
- `Pillow` (pulled automatically)

All included in the setup steps below.

---

## Installation

### 1. Install YASB

1. Follow the official YASB installation instructions: [YASB GitHub](https://github.com/DenBot/YASB).
2. Confirm `%USERPROFILE%\.config\yasb` exists and YASB runs without errors.
3. Stop YASB before replacing configuration files to avoid conflicts.

### 2. Install Python 3.11 with pywal

1. Download Python 3.11 (64-bit) from [python.org](https://www.python.org/downloads/release/python-3110/) and install it.
   - Tick “Add Python to PATH” during setup.
2. Install required packages **for Python 3.11** (other versions may cause numpy WinRT warnings):

   ```powershell
   py -3.11 -m pip install --user pywal colorthief haishoku
   ```

3. Optional: verify the CLI is available

   ```powershell
   %APPDATA%\Python\Python311\Scripts\wal.exe --help
   ```

   If `wal.exe` is missing, ensure `pywal` installed without errors.

### 3. Install PowerShell modules (optional)

The project uses built-in cmdlets only; no extra modules required. PowerShell 5.1 or 7+ works.

### 4. Clone & Copy Assets

1. Clone this repository:

   ```powershell
   git clone https://github.com/<your-account>/yasb-nightrider20797.git
   cd yasb-nightrider20797
   ```

2. Back up existing YASB config (recommended):

   ```powershell
   Copy-Item "$env:USERPROFILE\.config\yasb" "$env:USERPROFILE\.config\yasb.backup" -Recurse
   ```

3. Copy the repo contents **directly** into your YASB config directory (this ships the tested `config.yaml` + `styles.css` theme, along with the automation scripts):

   ```powershell
   Copy-Item .\* "$env:USERPROFILE\.config\yasb" -Recurse -Force
   ```

4. Confirm the following files exist:

   - `styles.css`
   - `config.yaml`
   - `update_yasb_palette.py`
   - `refresh-yasb-theme.ps1`
   - `theme-switcher.ps1`
   - `theme-state.json` (auto-generated after first run)

---

## Configuration

### Wallpaper Library

- Organize wallpapers under `C:\Users\<you>\Pictures\Wallpapers\Wallpapers`.
- Each subfolder represents a “theme” (e.g., `Nord`, `catppuccin`).
- The PowerShell switcher rotates through wallpapers in each folder, avoiding immediate repeats.

To customize the root path, edit the `param` section at the top of `theme-switcher.ps1`:

```powershell
param(
   [string]$WallpaperRoot = "D:\Wallpapers\Curated"
)
```

### YASB Styles

`styles.css` is rewritten on every theme refresh. Ensure YASB widgets reference the `--accent` CSS variable.

### Included Bar Theme

The repository ships with the exact YASB bar theme used for all testing—*Dots Windows* by **shawanGIT**—tuned to ride the accent waves generated here:

- **Background**: smoky glass `rgba(8, 10, 13, 0.72)` for a low-profile HUD that lets wallpapers punch through.
- **Foreground**: neutral grays tuned for legibility against rapid accent swaps.
- **Accent wiring**: every widget, badge, and progress indicator reads the single `--accent` variable, meaning one color change propagates everywhere.
- **Palette source**: accents generally come from `pywal` slots `color4`/`color5`, giving saturated highlights while the bar surface stays moody.

Drop in your own layout if you prefer, just preserve the CSS variables (`--accent`, `--accent-rgb`, `--yasb-background`) and YAML hooks that reference them.

> **Hint:** If your YASB config lives somewhere other than `%USERPROFILE%\.config\yasb`, edit the `YASB_DIR` constant near the top of `update_yasb_palette.py` to match your path before running the scripts.

### Theme State

`theme-state.json` tracks the last wallpaper used per folder to avoid repetitions. Delete the file to reset history.

---

## Running the Theme Switcher

### Interactive Menu

1. Launch PowerShell.
2. Run the theme switcher script:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\yasb\theme-switcher.ps1"
   ```

3. Use the menu:
   - Enter a number to pick a specific theme.
   - Enter `R` for a randomized selection.
   - Enter `Q` to quit.

On success the window closes automatically.

### Command-line Flags

Currently the script is fully interactive; advanced automation can be added by piping an index, e.g.:

```powershell
echo 3 | powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\yasb\theme-switcher.ps1"
```

### Desktop Shortcut

1. Right-click the desktop → **New > Shortcut**.
2. Paste the command (including quotes):

   ```text
   powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%USERPROFILE%\.config\yasb\theme-switcher.ps1"
   ```

3. Name it `Nightrider Theme Switcher`.
4. (Optional) Assign a hotkey in the shortcut’s **Properties > Shortcut key**.
5. Change the icon to something cyberpunk if desired.

When activated, the script runs, updates wallpaper/YASB/lock screen, and exits automatically.

---

## How It Works

### refresh-yasb-theme.ps1

- Acts as the central orchestration point.
- Logs hacker-themed status messages.
- Invokes `update_yasb_palette.py` to regenerate the color scheme from the current wallpaper.
- Updates YASB CSS and YAML files.

### update_yasb_palette.py

- Reads the active wallpaper path through Windows API.
- Runs `pywal` via CLI:
  - Prefers `colorthief` backend for x-platform consistency.
  - Falls back to `wal` (ImageMagick) and `haishoku` if needed.
- Sanitizes `colors.json`, picks an accent color, and patches YASB assets.

### Lock Screen Sync

- `theme-switcher.ps1` calls Windows Runtime APIs (`Windows.System.UserProfile.LockScreen`) to set the lock screen image to match the chosen wallpaper.
- Uses reflection helpers to bridge async WinRT calls from PowerShell.
- Adds "mission-complete" polish by keeping desktop, bar, and lock screen perfectly synchronized whenever the vibe changes.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `pywal CLI exited with status 1` | Ensure Python 3.11 has `pywal`, `colorthief`, and `haishoku` installed. Run `py -3.11 -m pip list`. |
| ImageMagick warning about `convert` | Install ImageMagick 7 and ensure `magick.exe` is on PATH. |
| PowerShell window stays open | Check for errors in the log. When successful, the script exits with code 0 and closes the window. |
| Lock screen sync warning | Make sure Windows Spotlight is disabled; the WinRT API cannot override Spotlight-managed lock screens. Running PowerShell as administrator may be required on some systems. |
| YASB not updating | Confirm YASB is monitoring `styles.css` for changes and that no conflicting theme reloaders are running. |

---

## Contributing

PRs welcome! Open issues for:

- Additional backend support (e.g., Vibrancy translations).
- Multi-monitor wallpaper syncing.
- Packaging the workflow as a YASB plug-in.

Please lint scripts and run a round of `theme-switcher.ps1` before submitting changes.

---

## License

MIT License – see [LICENSE](LICENSE) for details.
