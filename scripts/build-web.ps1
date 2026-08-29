param(
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $command = Get-Command Godot_v4.7-stable_win64_console.exe, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        throw "Godot 4.7 was not found. Pass -GodotExecutable with the console executable path."
    }
    $GodotExecutable = $command.Source
}

& (Join-Path $PSScriptRoot "install-gua.ps1")
$templateDirectory = Join-Path $projectRoot ".godot/web-build-appdata/Godot/export_templates/4.7.stable"
if (-not (Test-Path (Join-Path $templateDirectory "web_dlink_nothreads_release.zip"))) {
    throw "Godot Web templates are missing. Run scripts/install-godot-web-templates.ps1 once, then retry."
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $projectRoot ".godot/web-build-appdata"
$env:LOCALAPPDATA = Join-Path $projectRoot ".godot/web-build-localappdata"
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
New-Item -ItemType Directory -Force $env:LOCALAPPDATA | Out-Null
Push-Location $projectRoot
try {
    bun install --frozen-lockfile
    $webOutput = Join-Path $projectRoot "build/web"
    if (Test-Path -LiteralPath $webOutput) {
        Remove-Item -LiteralPath $webOutput -Recurse -Force
    }
    New-Item -ItemType Directory -Force $webOutput | Out-Null
    & $GodotExecutable --headless --path $projectRoot --export-release Web (Join-Path $projectRoot "build/web/index.html")
    if ($LASTEXITCODE -ne 0) {
        throw "Godot Web export failed with exit code $LASTEXITCODE."
    }
    bun run build:webmcp
    if ($LASTEXITCODE -ne 0) {
        throw "gua-webmcp bundle failed with exit code $LASTEXITCODE."
    }

    $indexPath = Join-Path $projectRoot "build/web/index.html"
    $html = Get-Content -Raw $indexPath
    $bootstrap = '<script type="module" src="gua-webmcp.js"></script>'
    if (-not $html.Contains($bootstrap)) {
        $html = $html.Replace("</body>", "    $bootstrap`n</body>")
        Set-Content -LiteralPath $indexPath -Value $html -NoNewline
    }
    if (-not (Test-Path "build/web/index.wasm") -or -not (Test-Path "build/web/gua-webmcp.js")) {
        throw "Web output is incomplete."
    }
}
finally {
    Pop-Location
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

Write-Host "Web build ready: $(Join-Path $projectRoot 'build/web/index.html')"
