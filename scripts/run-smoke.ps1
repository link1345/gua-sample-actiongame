param(
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $command = Get-Command Godot_v4.7-stable_win64_console.exe, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        throw "Godot 4.7 was not found."
    }
    $GodotExecutable = $command.Source
}

& (Join-Path $PSScriptRoot "install-gua.ps1")
$artifactDirectory = Join-Path $projectRoot "build/smoke"
New-Item -ItemType Directory -Force $artifactDirectory | Out-Null
$logPath = Join-Path $artifactDirectory "godot.log"
$smokeAppData = Join-Path $projectRoot ".godot/smoke-appdata"
$smokeLocalAppData = Join-Path $projectRoot ".godot/smoke-localappdata"
New-Item -ItemType Directory -Force $smokeAppData | Out-Null
New-Item -ItemType Directory -Force $smokeLocalAppData | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = $smokeAppData
$env:LOCALAPPDATA = $smokeLocalAppData
try {
& $GodotExecutable --headless --disable-crash-handler --path $projectRoot --quit-after 15 --log-file $logPath
if ($LASTEXITCODE -ne 0) {
    throw "Godot smoke run failed with exit code $LASTEXITCODE. See $logPath"
}
if (Select-String -Path $logPath -Pattern "SCRIPT ERROR|Parse Error|Failed to load script|GDExtension library not found" -Quiet) {
    throw "Godot reported script or GDExtension errors. See $logPath"
}
}
finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
Write-Host "Godot smoke passed."
