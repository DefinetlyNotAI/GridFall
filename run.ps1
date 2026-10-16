param(
    [switch]$Editor,
    [switch]$Benchmark,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs
)

$ErrorActionPreference = 'Stop'
$engine = $env:GODOT_BIN
if (-not $engine) {
    $installed = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { $engine = $installed.Source }
}
if (-not $engine) {
    $cached = Join-Path $env:USERPROFILE '.cache\gridfall-godot'
    if (Test-Path -LiteralPath $cached) {
        $engine = Get-ChildItem -LiteralPath $cached -Filter 'Godot*_win64.exe' |
            Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $engine -or -not (Test-Path -LiteralPath $engine)) {
    throw 'Godot 4.4 or newer is required. Install Godot, add it to PATH, or set GODOT_BIN to its executable.'
}
$launchArgs = @('--path', $PSScriptRoot)
if ($Editor) { $launchArgs += '--editor' }
if ($Benchmark) { $launchArgs += @('--', '--benchmark') }
if ($GameArgs) {
    if (-not $Benchmark) { $launchArgs += '--' }
    $launchArgs += $GameArgs
}
& $engine @launchArgs
exit $LASTEXITCODE
