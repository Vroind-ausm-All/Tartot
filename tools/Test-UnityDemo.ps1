param(
    [int]$Width = 540,
    [int]$Height = 960,
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$playerPath = Join-Path $repoPath 'unity/Build/Windows/Tartot.exe'
$logPath = Join-Path $repoPath "unity/Logs/smoke-$Width-$Height.log"
if (!(Test-Path -LiteralPath $playerPath)) { throw 'Build first: Tartot > Windows-Demo bauen' }
New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
$player = Start-Process -FilePath $playerPath -WindowStyle Hidden -PassThru -ArgumentList @(
    '-batchmode', '-screen-fullscreen', '0', '-screen-width', $Width,
    '-screen-height', $Height, '-tartot-smoke-test', '-logFile', ('"' + $logPath + '"')
)
if (!$player.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $player.Id
    throw "Demo timed out after $TimeoutSeconds seconds. Log: $logPath"
}
$player.Refresh()
if ($player.ExitCode -ne 0 -or !(Select-String -LiteralPath $logPath -Pattern '^TARTOT_SMOKE_PASS$' -Quiet)) {
    throw "Demo smoke failed (exit $($player.ExitCode)). Log: $logPath"
}
Select-String -LiteralPath $logPath -Pattern '^TARTOT_SMOKE_' | ForEach-Object Line
