#!/usr/bin/env python3
"""Update YASB theme colors based on the current wallpaper palette.

This script invokes `wal` (from pywal/wpgtk) to generate a color palette for the
current desktop wallpaper, then maps the accent and background colors into
YASB's stylesheet (`styles.css`) and widget configuration (`config.yaml`).

Requirements:
- pywal / wal CLI (installed automatically with wpgtk or via `pip install pywal`)
- Wallpaper path readable through the standard Windows API
- YASB configuration located under `%USERPROFILE%/.config/yasb`
"""

from __future__ import annotations

import json
import os
import ctypes
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, Tuple

SPI_GETDESKWALLPAPER = 0x0073
MAX_PATH = 260
YASB_DIR = Path.home() / ".config" / "yasb"
CSS_PATH = YASB_DIR / "styles.css"
CONFIG_PATH = YASB_DIR / "config.yaml"
ACCENT_PRIORITY = (
    "color4",
    "color5",
    "color2",
    "color6",
    "color3",
    "color1",
    "color7",
)
LUMINANCE_TARGET = 0.45
LUMINANCE_TOLERANCE = 0.25
MIN_CONTRAST = 0.25


class PaletteError(RuntimeError):
    """Custom error for palette-related failures."""


def debug(msg: str) -> None:
    """Print a message prefixed for easier tracing."""
    print(f"[yasb-theme] {msg}")


def ensure_paths() -> None:
    """Confirm that expected paths exist before continuing."""
    missing = [str(path) for path in (CSS_PATH, CONFIG_PATH) if not path.exists()]
    if missing:
        raise PaletteError(f"Missing expected YASB files: {', '.join(missing)}")


def get_wallpaper_path() -> Path:
    """Fetch the active wallpaper path via the Windows API."""
    buffer = ctypes.create_unicode_buffer(MAX_PATH)
    result = ctypes.windll.user32.SystemParametersInfoW(
        SPI_GETDESKWALLPAPER, MAX_PATH, buffer, 0
    )
    if not result:
        raise PaletteError("Unable to read current wallpaper path from Windows.")
    wallpaper = Path(buffer.value).expanduser()
    if not wallpaper.exists():
        raise PaletteError(f"Wallpaper path does not exist: {wallpaper}")
    return wallpaper


def _wal_cache_dir() -> Path:
    """Return the path to pywal's cache directory."""

    try:
        from pywal import settings as wal_settings
    except ImportError as exc:
        raise PaletteError("pywal is not installed. Install via `pip install pywal`.") from exc

    env_override = os.environ.get("WAL_CACHE_DIR")
    if env_override:
        return Path(env_override)
    return Path(wal_settings.CACHE_DIR)


def _load_palette_json(colors_path: Path) -> Dict[str, Dict[str, str]]:
    """Load and decode pywal's colors.json, attempting light sanitation if needed."""

    try:
        raw = colors_path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise PaletteError(f"pywal did not produce colors.json at {colors_path}.") from exc

    try:
        palette = json.loads(raw)
    except json.JSONDecodeError:
        sanitized = re.sub(r",\s*([}\]])", r"\1", raw)
        sanitized = re.sub(
            r'("wallpaper"\s*:\s*")([^\"]+)(")',
            lambda match: f'{match.group(1)}{match.group(2).replace("\\", "\\\\")}{match.group(3)}',
            sanitized,
        )
        try:
            palette = json.loads(sanitized)
        except json.JSONDecodeError as exc:
            debug(f"Failed to parse colors.json. Contents were:\n{raw}")
            raise PaletteError("pywal produced an invalid colors.json file.") from exc

    if not isinstance(palette, dict):
        raise PaletteError("pywal returned an unexpected palette format.")

    debug(f"Loaded palette JSON from {colors_path}.")
    return palette


def _wal_runner() -> tuple[list[str], str, dict[str, str]]:
    """Determine the most suitable command invocation for pywal."""

    env = os.environ.copy()

    wal_executable = shutil.which("wal")
    candidates: list[Path] = []
    if wal_executable:
        return [wal_executable], wal_executable, env

    base_candidates = [
        Path.home() / "AppData" / "Roaming" / "Python",
        Path.home() / "AppData" / "Local" / "Programs" / "Python",
    ]
    for base in base_candidates:
        if not base.exists():
            continue
        for script_dir in base.glob("Python*/Scripts"):
            exe_name = "wal.exe" if os.name == "nt" else "wal"
            candidate = script_dir / exe_name
            if candidate.exists():
                candidates.append(candidate)

    if candidates:
        candidate = str(candidates[0])
        return [candidate], candidate, env

    python_launcher = shutil.which("py")
    if python_launcher:
        env.setdefault("PY_PYTHON", "3.11")
        return [python_launcher, "-m", "pywal"], f"{python_launcher} -m pywal", env

    python_cmd = shutil.which("python")
    if python_cmd:
        return [python_cmd, "-m", "pywal"], f"{python_cmd} -m pywal", env

    raise PaletteError("Unable to locate 'wal' or a Python launcher to invoke pywal.")


def generate_palette(wallpaper: Path) -> Dict[str, Dict[str, str]]:
    """Invoke pywal, preferring colorthief while falling back to other backends."""

    runner, runner_name, env = _wal_runner()
    cache_dir = _wal_cache_dir()
    colors_path = cache_dir / "colors.json"

    def invoke_backend(backend: str) -> Dict[str, Dict[str, str]]:
        if colors_path.exists():
            try:
                colors_path.unlink()
            except OSError:
                pass

        debug(f"Invoking pywal via {runner_name!r} (backend={backend}).")
        command = [
            *runner,
            "-n",
            "-i",
            str(wallpaper),
            "--backend",
            backend,
        ]

        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

        if result.stdout.strip():
            debug(f"wal stdout: {result.stdout.strip()}")
        if result.stderr.strip():
            debug(f"wal stderr: {result.stderr.strip()}")

        if result.returncode != 0:
            raise PaletteError(
                f"pywal backend '{backend}' failed with exit code {result.returncode}."
            )

        if not colors_path.exists():
            raise PaletteError(
                f"pywal backend '{backend}' did not produce colors.json at {colors_path}."
            )

        try:
            palette = _load_palette_json(colors_path)
        except PaletteError as exc:
            raise PaletteError(
                f"pywal backend '{backend}' produced invalid palette data."
            ) from exc

        debug(f"pywal backend '{backend}' succeeded.")
        return palette

    errors: list[str] = []
    for backend in ("colorthief", "wal", "haishoku"):
        try:
            return invoke_backend(backend)
        except PaletteError as exc:
            errors.append(str(exc))
            debug(str(exc))

    raise PaletteError(
        "pywal was unable to generate a palette. " + " | ".join(errors)
    )


def hex_to_rgb(hex_color: str) -> Tuple[int, int, int]:
    """Convert a hex color (e.g. #aabbcc) to an RGB tuple."""
    cleaned = hex_color.lstrip("#")
    if len(cleaned) != 6:
        raise PaletteError(f"Unexpected color format: {hex_color}")
    return tuple(int(cleaned[i : i + 2], 16) for i in (0, 2, 4))


def relative_luminance(rgb: Tuple[int, int, int]) -> float:
    """Return perceived luminance (0-1) for an RGB tuple."""
    r, g, b = (channel / 255.0 for channel in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def choose_accent(
    colors: Dict[str, str], special: Dict[str, str], background_rgb: Tuple[int, int, int]
) -> str:
    """Select an accent color with optional overrides and fallbacks."""

    env_slot = os.environ.get("YASB_ACCENT_SLOT")
    if env_slot:
        candidate = colors.get(env_slot)
        if candidate:
            debug(f"Using accent slot from env YASB_ACCENT_SLOT={env_slot} -> {candidate}")
            return candidate
        debug(f"Env accent slot {env_slot} not present in palette; falling back.")

    def candidate_colors() -> Iterable[str]:
        for key in ACCENT_PRIORITY:
            hex_color = colors.get(key)
            if hex_color:
                yield hex_color
        foreground = special.get("foreground")
        if foreground:
            yield foreground

    ranked = []
    background_lum = relative_luminance(background_rgb)
    for hex_color in candidate_colors():
        rgb = hex_to_rgb(hex_color)
        lum = relative_luminance(rgb)
        contrast = abs(lum - background_lum)
        ranked.append((hex_color, lum, contrast))

    if not ranked:
        raise PaletteError("Palette did not contain any usable accent colors.")

    target_low = max(0.0, LUMINANCE_TARGET - LUMINANCE_TOLERANCE)
    target_high = min(1.0, LUMINANCE_TARGET + LUMINANCE_TOLERANCE)

    for hex_color, lum, contrast in ranked:
        if target_low <= lum <= target_high and contrast >= MIN_CONTRAST:
            debug(f"Selected accent {hex_color} (luminance {lum:.2f}).")
            return hex_color

    best_hex, best_lum, _ = min(ranked, key=lambda item: abs(item[1] - LUMINANCE_TARGET))
    debug(
        "Using accent %s with luminance %.2f (closest to target)" % (best_hex, best_lum)
    )
    return best_hex


def update_css(accent_hex: str, background_rgb: Tuple[int, int, int]) -> None:
    """Inject accent and background colors into the stylesheet."""
    css = CSS_PATH.read_text(encoding="utf-8")

    accent_rgb = hex_to_rgb(accent_hex)
    replacements = {
        r"--accent:\s*#[0-9a-fA-F]{6};": f"--accent: {accent_hex};",
        r"--accent-rgb:\s*[0-9\s,]+;": f"--accent-rgb: {accent_rgb[0]}, {accent_rgb[1]}, {accent_rgb[2]};",
        r"--yasb-background:\s*rgba\([^;]+;": f"--yasb-background: rgba({background_rgb[0]}, {background_rgb[1]}, {background_rgb[2]}, 0.72);",
    }

    for pattern, replacement in replacements.items():
        css, count = re.subn(pattern, replacement, css, count=1)
        if count != 1:
            raise PaletteError(f"Failed to apply CSS replacement for pattern: {pattern}")

    CSS_PATH.write_text(css, encoding="utf-8")
    debug(f"Updated {CSS_PATH.name} with accent {accent_hex}.")


def update_config(accent_hex: str) -> None:
    """Replace progress indicator colors inside config.yaml."""
    yaml_text = CONFIG_PATH.read_text(encoding="utf-8")
    yaml_text, count = re.subn(r"'color': '#[0-9a-fA-F]{6}'", f"'color': '{accent_hex}'", yaml_text)
    if count == 0:
        raise PaletteError("No color entries updated in config.yaml; expected at least one.")
    CONFIG_PATH.write_text(yaml_text, encoding="utf-8")
    debug(f"Updated {count} config color entr{'y' if count == 1 else 'ies'}.")


def main() -> int:
    try:
        ensure_paths()
        wallpaper = get_wallpaper_path()
        debug(f"Detected wallpaper: {wallpaper}")
        palette = generate_palette(wallpaper)

        colors = palette.get("colors", {})
        special = palette.get("special", {})
        if not colors:
            raise PaletteError("Palette colors collection empty.")
        background_hex = special.get("background")
        if not background_hex:
            raise PaletteError("Could not determine background color from wal palette.")

        background_rgb = hex_to_rgb(background_hex)

        accent_hex = choose_accent(colors, special, background_rgb)

        update_css(accent_hex.lower(), background_rgb)
        update_config(accent_hex.lower())

        debug("Theme refresh complete. YASB watchers should reload automatically.")
        return 0
    except PaletteError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
