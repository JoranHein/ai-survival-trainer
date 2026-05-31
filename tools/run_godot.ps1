param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $GodotArgs
)

$ErrorActionPreference = "Stop"

# Usage: powershell -ExecutionPolicy Bypass -File tools/run_godot.ps1 --headless --quit-after 2
$GodotExe = "D:\downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$ProjectPath = Join-Path $RepoRoot "godot_game"

if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    [Console]::Error.WriteLine("Godot executable not found at configured path: $GodotExe")
    exit 127
}

& $GodotExe --path $ProjectPath @GodotArgs
exit $LASTEXITCODE
