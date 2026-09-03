param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = "1.0.10"
$releaseBase = "https://github.com/link1345/gua/releases/download/gua-v$version"
$packages = @(
    @{
        Name = "gua-godot-addon-v$version.zip"
        Sha256 = "8549c2dff5906981b4efedecb6a09316d05943e58f8fb2c12e607501a2900ec7"
    }
)

$missingChecksums = @($packages | Where-Object { [string]::IsNullOrWhiteSpace($_.Sha256) })
if ($missingChecksums.Count -gt 0) {
    $missingNames = ($missingChecksums | ForEach-Object { $_.Name }) -join ", "
    throw "Gua v$version release assets are not published yet, so their SHA-256 checksums cannot be pinned: $missingNames"
}

$addonDirectory = Join-Path $projectRoot "addons/gua"
$versionMarker = Join-Path $addonDirectory ".gua-version"
if (-not $Force -and (Test-Path $versionMarker) -and (Get-Content -Raw $versionMarker).Trim() -eq $version) {
    Write-Host "Gua Godot addon v$version is already installed."
    exit 0
}

$dependencyRoot = Join-Path $projectRoot ".godot/gua-dependencies/gua-v$version"
New-Item -ItemType Directory -Force $dependencyRoot | Out-Null

foreach ($package in $packages) {
    $archive = Join-Path $dependencyRoot $package.Name
    if (-not (Test-Path $archive) -or (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $package.Sha256) {
        Write-Host "Downloading $($package.Name)..."
        Invoke-WebRequest "$releaseBase/$($package.Name)" -OutFile $archive
    }
    $actualHash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $package.Sha256) {
        throw "Checksum mismatch for $($package.Name). Expected $($package.Sha256), got $actualHash."
    }

    $expanded = Join-Path $dependencyRoot ([IO.Path]::GetFileNameWithoutExtension($package.Name))
    if (Test-Path $expanded) {
        Remove-Item -LiteralPath $expanded -Recurse -Force
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $expanded
    $sourceAddon = Join-Path $expanded "addons/gua"
    if (-not (Test-Path $sourceAddon)) {
        throw "The Gua package does not contain addons/gua: $($package.Name)"
    }

    if (Test-Path $addonDirectory) {
        Remove-Item -LiteralPath $addonDirectory -Recurse -Force
    }
    $addonParent = Split-Path -Parent $addonDirectory
    New-Item -ItemType Directory -Force $addonParent | Out-Null
    Copy-Item -LiteralPath $sourceAddon -Destination $addonParent -Recurse
}

Set-Content -LiteralPath $versionMarker -Value $version -NoNewline
$required = @(
    "gua.gdextension",
    "gua_auto_adapter.gd",
    "gua_webmcp_bridge.gd",
    "bin/gua_godot.windows.debug.x86_64.dll",
    "bin/gua_godot.web.debug.wasm32.wasm",
    "bin/gua_godot.web.release.wasm32.wasm"
)
foreach ($relativePath in $required) {
    $path = Join-Path $addonDirectory $relativePath
    if (-not (Test-Path $path) -or (Get-Item $path).Length -eq 0) {
        throw "Gua v$version installation is incomplete: $relativePath"
    }
}

Write-Host "Installed Gua Godot addon v$version for Windows Debug and Web Debug/Release."
