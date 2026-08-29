param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = "4.7.stable"
$archiveName = "Godot_v4.7-stable_export_templates.tpz"
$archiveUrl = "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/$archiveName"
$archiveSha256 = "9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec"
$cacheDirectory = Join-Path $projectRoot ".godot/export-template-cache"
$archivePath = Join-Path $cacheDirectory $archiveName
$templateDirectory = Join-Path $projectRoot ".godot/web-build-appdata/Godot/export_templates/$version"
$requiredTemplates = @("web_dlink_nothreads_debug.zip", "web_dlink_nothreads_release.zip")

$complete = -not $Force
foreach ($template in $requiredTemplates) {
    if (-not (Test-Path (Join-Path $templateDirectory $template))) {
        $complete = $false
    }
}
if ($complete) {
    Write-Host "Godot 4.7 Web export templates are already installed."
    exit 0
}

New-Item -ItemType Directory -Force $cacheDirectory | Out-Null
New-Item -ItemType Directory -Force $templateDirectory | Out-Null
if (-not (Test-Path $archivePath) -or (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $archiveSha256) {
    Write-Host "Downloading the official Godot 4.7 export template archive (about 1.2 GB)..."
    Invoke-WebRequest $archiveUrl -OutFile $archivePath
}
$actualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $archiveSha256) {
    throw "Godot export template checksum mismatch. Expected $archiveSha256, got $actualHash."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($template in $requiredTemplates) {
        $entry = $archive.Entries | Where-Object { $_.FullName -eq "templates/$template" } | Select-Object -First 1
        if ($null -eq $entry) {
            throw "Template not found in official archive: $template"
        }
        $target = Join-Path $templateDirectory $template
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    }
}
finally {
    $archive.Dispose()
}
Write-Host "Installed Godot 4.7 Web Debug/Release export templates."

