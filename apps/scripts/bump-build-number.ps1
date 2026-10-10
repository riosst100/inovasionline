$ErrorActionPreference = "Stop"

$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
$match = Select-String -Path $pubspecPath -Pattern '^version:\s*(\S+)\+(\d+)'
if (-not $match) {
    Write-Error "Could not find a 'version: x.y.z+N' line in pubspec.yaml"
    exit 1
}

$versionName = $match.Matches[0].Groups[1].Value
$buildNumber = [int]$match.Matches[0].Groups[2].Value + 1

$content = Get-Content $pubspecPath
$content = $content -replace '^version:\s*\S+\+\d+', "version: $versionName+$buildNumber"
Set-Content -Path $pubspecPath -Value $content

Write-Output "$versionName;$buildNumber"
