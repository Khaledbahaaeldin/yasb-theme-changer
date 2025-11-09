$ErrorActionPreference = "Stop"

function Write-HackLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $glyphMap = @{
        "SUCCESS" = "[OK]"
        "WARN"    = "[!!]"
        "FAIL"    = "[XX]"
        "DEBUG"   = "[>>]"
        "INFO"    = "[**]"
    }
    $glyph = $glyphMap[$Level.ToUpperInvariant()]
    if (-not $glyph) { $glyph = "[**]" }

    Write-Host ("[{0}] {1} {2}" -f $timestamp, $glyph, $Message) -ForegroundColor $Color
}

function Show-Banner {
    Write-Host "================================================" -ForegroundColor DarkGray
    Write-Host "==  YASB Chroma Sync  //  infiltration mode  ==" -ForegroundColor Magenta
    Write-Host "================================================" -ForegroundColor DarkGray
}

function Invoke-HackSequence {
    param(
        [string[]]$Steps,
        [int]$MinDelayMs = 160,
        [int]$MaxDelayMs = 340
    )

    foreach ($step in $Steps) {
        Write-HackLog $step "DEBUG" ([ConsoleColor]::DarkGray)
        Start-Sleep -Milliseconds (Get-Random -Minimum $MinDelayMs -Maximum $MaxDelayMs)
    }
}

function Show-Diagnostics {
    $cssPath = Join-Path $env:USERPROFILE ".config\yasb\styles.css"
    if (-not (Test-Path $cssPath)) { return }

    $css = Get-Content $cssPath
    $accent = ($css | Where-Object { $_ -match "--accent:" } | Select-Object -First 1)
    $accent = if ($accent) { ($accent -replace ".*--accent:\s*", "") -replace ";.*", "" } else { "unknown" }

    $background = ($css | Where-Object { $_ -match "--yasb-background:" } | Select-Object -First 1)
    $background = if ($background) { ($background -replace ".*--yasb-background:\s*", "").Trim() } else { "unknown" }

    Write-HackLog "Accent vector locked to $accent" "SUCCESS" ([ConsoleColor]::Green)
    Write-HackLog "Bar background set to $background" "SUCCESS" ([ConsoleColor]::Green)
}

Show-Banner

Invoke-HackSequence @(
    "Scanning local subnet for chroma endpoints",
    "Negotiating session key with wallpaper daemon",
    "Seeding RNG with wallpaper hash",
    "Priming shader cores for palette synthesis"
)

try {
    $scriptPath = Join-Path $env:USERPROFILE ".config\yasb\update_yasb_palette.py"
    Write-HackLog "Locating palette orchestrator at $scriptPath" "DEBUG" ([ConsoleColor]::DarkCyan)

    if (-not (Test-Path $scriptPath)) {
        throw "Could not find update script at $scriptPath"
    }

    $pythonCmd = $null
    foreach ($candidate in @("py", "python", "python3")) {
        Write-HackLog "Probing interpreter '$candidate'" "DEBUG" ([ConsoleColor]::DarkGray)
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.CommandType -in 'Application','ExternalScript') {
            $pythonCmd = $cmd.Source
            break
        }
    }

    if (-not $pythonCmd) {
        throw "Python interpreter not found in PATH. Install Python or adjust this script."
    }

    Write-HackLog "Python console secured: $pythonCmd" "INFO" ([ConsoleColor]::Green)
    Write-HackLog "Spawning chroma daemon..." "INFO" ([ConsoleColor]::Yellow)

    $pythonOutput = & $pythonCmd $scriptPath @args 2>&1
    $exitCode = $LASTEXITCODE
    $pythonOutput | ForEach-Object { Write-HackLog $_ "DEBUG" ([ConsoleColor]::DarkGreen) }

    if ($exitCode -ne 0) {
        throw "update_yasb_palette.py exited with code $exitCode"
    }

    Invoke-HackSequence @(
        "Stabilizing luminous flux",
        "Injecting accent pigments into HUD",
        "Recompiling widget shaders"
    )

    Show-Diagnostics

    Write-HackLog "Palette uplink complete. Bask in the glow." "SUCCESS" ([ConsoleColor]::Green)
}
catch {
    Write-HackLog $_.Exception.Message "FAIL" ([ConsoleColor]::Red)
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        Write-HackLog $_.InvocationInfo.PositionMessage "DEBUG" ([ConsoleColor]::DarkYellow)
    }
    exit 1
}
