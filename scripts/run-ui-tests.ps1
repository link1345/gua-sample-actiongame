param(
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $command = Get-Command Godot_v4.7-stable_win64_console.exe, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        throw "Godot 4.7 was not found. Pass -GodotExecutable or add it to PATH."
    }
    $GodotExecutable = $command.Source
}

& (Join-Path $PSScriptRoot "install-gua.ps1")
$previousGodotExecutable = $env:GODOT_EXECUTABLE
$env:GODOT_EXECUTABLE = $GodotExecutable
try {
    $testProject = Join-Path $projectRoot "tests/GuaSignalRelay.Tests.csproj"
    dotnet restore $testProject --configfile (Join-Path $projectRoot "NuGet.Config")
    if ($LASTEXITCODE -ne 0) {
        throw "Gua.Testing package restore failed with exit code $LASTEXITCODE."
    }
    dotnet test $testProject --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw "Gua.Testing UI tests failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:GODOT_EXECUTABLE = $previousGodotExecutable
}
