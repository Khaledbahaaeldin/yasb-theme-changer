param(
    [string]$WallpaperRoot = "C:\Users\Khaled\Pictures\Wallpapers\Wallpapers"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$statePath = Join-Path $env:USERPROFILE ".config\yasb\theme-state.json"
$paletteScript = Join-Path $env:USERPROFILE ".config\yasb\refresh-yasb-theme.ps1"

function Write-GlitchLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $tag = switch ($Level.ToUpperInvariant()) {
        "WARN"    { "[WARN]" }
        "FAIL"    { "[FAIL]" }
        "SUCCESS" { "[OK]" }
        "DEBUG"  { "[DBG]" }
        default   { "[INFO]" }
    }

    Write-Host ("[{0}] {1} {2}" -f $timestamp, $tag, $Message) -ForegroundColor $Color
}

function Show-Banner {
    Clear-Host
        $banner = @'
    _   _ _       _     _        _     _         ___   ___ ______ ___ ______ 
 | \ | (_)     | |   | |      (_)   | |       |__ \ / _ \____  / _ \____  |
 |  \| |_  __ _| |__ | |_ _ __ _  __| | ___ _ __ ) | | | |  / / (_) |  / / 
 | . ` | |/ _` | '_ \| __| '__| |/ _` |/ _ \ '__/ /| | | | / / \__, | / /  
 | |\  | | (_| | | | | |_| |  | | (_| |  __/ | / /_| |_| |/ /    / / / /   
 |_| \_|_|\__, |_| |_|\__|_|  |_|\__,_|\___|_||____|\___//_/    /_/ /_/    
                     __/ |                                                           
                    |___/                                                            
'@
    $tagline = "nightrider20797 theme changer // chroma orchestrator"
    $banner.TrimEnd().Split("`n") | ForEach-Object {
        Write-Host $_ -ForegroundColor DarkMagenta
    }
    Write-Host $tagline -ForegroundColor DarkCyan
    Write-Host ""
}

function Invoke-HackSequence {
    param(
        [string[]]$Steps,
        [int]$MinDelayMs = 180,
        [int]$MaxDelayMs = 360
    )

    foreach ($step in $Steps) {
        Write-GlitchLog $step "DEBUG" ([ConsoleColor]::DarkGray)
        Start-Sleep -Milliseconds (Get-Random -Minimum $MinDelayMs -Maximum $MaxDelayMs)
    }
}

function Load-State {
    if (Test-Path $statePath) {
        try {
            $raw = Get-Content $statePath -Raw | ConvertFrom-Json
            $table = @{}
            if ($raw) {
                foreach ($prop in $raw.PSObject.Properties) {
                    $table[$prop.Name] = $prop.Value
                }
            }
            return $table
        } catch {
            Write-GlitchLog "State file corrupt; starting fresh." "WARN" ([ConsoleColor]::Yellow)
        }
    }
    return @{}
}

function Save-State($state) {
    $json = $state | ConvertTo-Json -Depth 4
    $json | Set-Content -Path $statePath -Encoding UTF8
}

function Get-ThemeObjects {
    if (-not (Test-Path $WallpaperRoot)) {
        throw "Wallpaper root not found: $WallpaperRoot"
    }

    $themes = @()
    Get-ChildItem -Path $WallpaperRoot -Directory | ForEach-Object {
        $images = @(Get-ChildItem -Path $_.FullName -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension.ToLowerInvariant() -in @('.jpg', '.jpeg', '.png', '.bmp', '.webp') })
        $themes += [pscustomobject]@{
            Name = $_.Name
            Path = $_.FullName
            Images = $images
            Count = $images.Count
        }
    }

    if ($themes.Count -eq 0) {
        throw "No theme folders found inside $WallpaperRoot"
    }

    return $themes | Sort-Object Name
}

function Show-Menu($themes, $state) {
    Write-Host "Select a theme channel:" -ForegroundColor Cyan
    Write-Host "" 

    $index = 1
    foreach ($theme in $themes) {
        $last = $null
        if ($state.ContainsKey($theme.Name)) {
            $last = $state[$theme.Name]
        }

        $status = if ($theme.Count -gt 1) { "$($theme.Count) variants" } elseif ($theme.Count -eq 1) { "single artifact" } else { "no assets" }
        $lastInfo = if ($last) { "last => $(Split-Path $last.wallpaper -Leaf)" } else { "fresh run" }

        $line = "[{0:00}] {1,-18} :: {2,-18} :: {3}" -f $index, $theme.Name, $status, $lastInfo
        Write-Host $line -ForegroundColor ([ConsoleColor]::Gray)
        $index++
    }

    Write-Host "" 
    Write-Host "[R] random tunnel" -ForegroundColor DarkCyan
    Write-Host "[Q] abort mission" -ForegroundColor DarkCyan
    Write-Host "" 
}

function Prompt-Selection($themes) {
    while ($true) {
        $input = Read-Host "Deploy" 
        switch -Regex ($input.Trim()) {
            "^(q|quit|exit)$" { return @{ Type = "Exit" } }
            "^(r|random)$"   {
                $choice = Get-Random -InputObject $themes
                return @{ Type = "Random"; Theme = $choice }
            }
            "^[0-9]+$" {
                $idx = [int]$input
                if ($idx -ge 1 -and $idx -le $themes.Count) {
                    return @{ Type = "Index"; Theme = $themes[$idx - 1] }
                }
            }
        }
        Write-GlitchLog "Invalid input. Target must be an index, R, or Q." "WARN" ([ConsoleColor]::Yellow)
    }
}

function Choose-Wallpaper($theme, [hashtable]$state) {
    $images = $theme.Images
    if ($images.Count -eq 0) {
        throw "Theme '$($theme.Name)' contains no usable images."
    }

    $lastPath = $null
    if ($state.ContainsKey($theme.Name)) {
        $lastPath = $state[$theme.Name].wallpaper
    }

    if ($images.Count -eq 1) {
        if ($lastPath) {
            Write-GlitchLog "Single wallpaper detected; reusing same artifact." "WARN" ([ConsoleColor]::Yellow)
        }
        return $images[0].FullName
    }

    $pool = @($images | Where-Object { $_.FullName -ne $lastPath })
    if ($pool.Count -eq 0) {
        $pool = $images
    }

    return (Get-Random -InputObject $pool).FullName
}

function Set-Wallpaper($path) {
    if (-not ("Wallpaper" -as [type])) {
        Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    }
    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDWININICHANGE = 0x02

    Write-GlitchLog "Applying wallpaper vector: $(Split-Path $path -Leaf)" "INFO" ([ConsoleColor]::Cyan)
    [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $path, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE) | Out-Null
}

function Invoke-AsyncOperation {
    param(
        [Parameter(Mandatory = $true)] $Operation,
        [Type] $ResultType
    )

    Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop

    $methods = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object { $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 }

    if ($ResultType) {
        $method = $methods |
            Where-Object { $_.IsGenericMethodDefinition -and $_.GetParameters()[0].ParameterType.Name.StartsWith("IAsyncOperation") } |
            Select-Object -First 1
        if (-not $method) {
            throw "Unable to locate AsTask overload for IAsyncOperation with result type $ResultType."
        }
        $method = $method.MakeGenericMethod($ResultType)
    }
    else {
        $method = $methods |
            Where-Object { -not $_.IsGenericMethodDefinition -and $_.GetParameters()[0].ParameterType.Name -eq "IAsyncAction" } |
            Select-Object -First 1
        if (-not $method) {
            throw "Unable to locate AsTask overload for IAsyncAction."
        }
    }

    $task = $method.Invoke($null, @($Operation))

    try {
        $task.GetAwaiter().GetResult() | Out-Null
    }
    catch {
        if ($task.Exception -and $task.Exception.InnerExceptions.Count -gt 0) {
            throw $task.Exception.InnerExceptions[0]
        }
        throw
    }

    if ($ResultType) {
        return $task.Result
    }

    return $null
}

function Set-LockScreenImage($path) {
    if (-not (Test-Path $path)) {
        throw "Lock screen image not found: $path"
    }

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
        $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
        $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType=WindowsRuntime]

        $storageFile = Invoke-AsyncOperation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
        Invoke-AsyncOperation ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($storageFile)) | Out-Null
        Write-GlitchLog "Lock screen wallpaper synchronized." "INFO" ([ConsoleColor]::Cyan)
    }
    catch {
        Write-GlitchLog "Lock screen sync failed: $($_.Exception.Message)" "WARN" ([ConsoleColor]::Yellow)
    }
}

function Invoke-PaletteRefresh {
    if (-not (Test-Path $paletteScript)) {
        throw "Palette script missing: $paletteScript"
    }

    Write-GlitchLog "Recalibrating YASB matrix" "INFO" ([ConsoleColor]::Cyan)
    $output = & powershell -NoLogo -ExecutionPolicy Bypass -File $paletteScript 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-GlitchLog $_ "DEBUG" ([ConsoleColor]::DarkGreen) }
    }

    if ($exitCode -ne 0) {
        throw "Palette refresh exited with code $exitCode"
    }
}

function Update-State([hashtable]$state, $themeName, $wallpaperPath) {
    $state[$themeName] = @{ wallpaper = $wallpaperPath; timestamp = (Get-Date).ToString("o") }
    Save-State $state
}

function Main {
    Show-Banner

    $state = [hashtable](Load-State)
    $themes = Get-ThemeObjects
    Show-Menu -themes $themes -state $state

    $selection = Prompt-Selection -themes $themes
    if ($selection.Type -eq "Exit") {
        Write-GlitchLog "Mission aborted." "WARN" ([ConsoleColor]::Yellow)
        return
    }

    $theme = $selection.Theme
    Write-GlitchLog "Channel locked: $($theme.Name)" "INFO" ([ConsoleColor]::Cyan)

    $wallpaper = Choose-Wallpaper -theme $theme -state $state
    Write-GlitchLog "Selected payload: $wallpaper" "DEBUG" ([ConsoleColor]::DarkGray)

    Invoke-HackSequence @(
        "Decrypting texture matrix",
        "Transmitting to desktop compositor",
        "Syncing shader cores"
    )

    Set-Wallpaper -path $wallpaper
    Write-GlitchLog "Syncing lock screen artifact" "DEBUG" ([ConsoleColor]::DarkGray)
    Set-LockScreenImage -path $wallpaper
    Update-State -state $state -themeName $theme.Name -wallpaperPath $wallpaper

    Invoke-HackSequence @(
        "Capturing spectral histogram",
        "Rebuilding palette blueprint"
    ) -MinDelayMs 120 -MaxDelayMs 240

    Invoke-PaletteRefresh

    Invoke-HackSequence @(
        "Finalizing theme graft",
        "Deploy complete"
    ) -MinDelayMs 120 -MaxDelayMs 200

    Write-GlitchLog "Theme $($theme.Name) deployed successfully." "SUCCESS" ([ConsoleColor]::Green)
    exit 0
}

try {
    Main
} catch {
    Write-GlitchLog $_.Exception.Message "FAIL" ([ConsoleColor]::Red)
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        Write-GlitchLog $_.InvocationInfo.PositionMessage "DEBUG" ([ConsoleColor]::DarkYellow)
    }
    exit 1
}
