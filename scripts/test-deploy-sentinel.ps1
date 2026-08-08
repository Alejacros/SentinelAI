$ErrorActionPreference = "Stop"

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "sentinel-deploy-test-" + [guid]::NewGuid().ToString("N")
)
$source = Join-Path $testRoot "source"
$destination = Join-Path $testRoot "destination"
$sourceData = Join-Path $source "data"
$destinationData = Join-Path $destination "data"

try {
    New-Item -ItemType Directory -Path $sourceData -Force | Out-Null
    New-Item -ItemType Directory -Path $destinationData -Force | Out-Null

    [System.IO.File]::WriteAllText(
        (Join-Path $source "fxmanifest.lua"),
        "version 'deploy-test'"
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $sourceData "profiles.json"),
        "{}"
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $destinationData "profiles.json"),
        '{"license:test-masked":{"xp":3200,"completedCases":101,"character":{"created":true}}}'
    )

    & (Join-Path $PSScriptRoot "deploy-sentinel.ps1") `
        -SourceResource $source `
        -DestinationResource $destination

    $result = Get-Content -LiteralPath (
        Join-Path $destinationData "profiles.json"
    ) -Raw | ConvertFrom-Json
    $count = @($result.PSObject.Properties).Count
    $profile = $result.PSObject.Properties.Value | Select-Object -First 1

    if (($count -ne 1) `
        -or ($profile.xp -ne 3200) `
        -or ($profile.completedCases -ne 101)) {

        throw "FAIL: el perfil ficticio fue alterado durante el deploy."
    }

    Write-Host "PASS: profiles.json runtime fue preservado."
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
