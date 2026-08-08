[CmdletBinding()]
param(
    [Parameter()]
    [string] $SourceResource = "D:\SentinelAI\resources\sentinel_core",

    [Parameter()]
    [string] $DestinationResource = "D:\FXServer\resources\[sentinel]\sentinel_core"
)

$ErrorActionPreference = "Stop"

function Get-ProfileCount {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    $decoded = $raw | ConvertFrom-Json

    if ($null -eq $decoded) {
        return 0
    }

    return @($decoded.PSObject.Properties).Count
}

$source = (Resolve-Path -LiteralPath $SourceResource).Path
$destination = if (Test-Path -LiteralPath $DestinationResource) {
    (Resolve-Path -LiteralPath $DestinationResource).Path
} else {
    New-Item -ItemType Directory -Path $DestinationResource -Force | Select-Object -ExpandProperty FullName
}

$runtimeProfile = Join-Path $destination "data\profiles.json"
$runtimeBackup = Join-Path $destination "data\profiles.backup.json"
$profilesBefore = Get-ProfileCount -Path $runtimeProfile

if ($null -ne $profilesBefore) {
    $backupDirectory = Split-Path -Parent $runtimeBackup
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    Copy-Item -LiteralPath $runtimeProfile -Destination $runtimeBackup -Force
    Write-Host "[Sentinel Deploy] Backup runtime actualizado: $runtimeBackup"
}

$excludedFiles = @(
    "profiles.json",
    "profiles.backup.json",
    "*.tmp",
    "*.log"
)
$excludedDirectories = @(
    "logs",
    "runtime",
    "storage"
)
$arguments = @(
    $source,
    $destination,
    "/MIR",
    "/R:2",
    "/W:1",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/NP",
    "/XF"
) + $excludedFiles + @("/XD") + $excludedDirectories

& robocopy @arguments
$robocopyExitCode = $LASTEXITCODE

if ($robocopyExitCode -ge 8) {
    throw "Robocopy fallo con codigo $robocopyExitCode."
}

$profilesAfter = Get-ProfileCount -Path $runtimeProfile

if (($null -ne $profilesBefore) `
    -and ($null -eq $profilesAfter -or $profilesAfter -lt $profilesBefore)) {

    Copy-Item -LiteralPath $runtimeBackup -Destination $runtimeProfile -Force
    throw "La verificacion detecto perdida de perfiles. Se restauro el backup runtime."
}

Write-Host "[Sentinel Deploy] Codigo sincronizado correctamente."
$profileSummary = if ($null -eq $profilesAfter) {
    "sin archivo previo"
} else {
    $profilesAfter
}

Write-Host ("[Sentinel Deploy] Perfiles runtime preservados: {0}" -f $profileSummary)
