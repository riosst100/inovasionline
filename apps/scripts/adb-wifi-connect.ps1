# Finds/connects an Android phone over Wi-Fi adb and prints its serial on stdout (progress goes to stderr).
# Used by run-wifi.bat. Order tried:
#   1. the ip[:port] passed in (port defaults to 5555)
#   2. a network device that is already connected
#   3. wireless-debugging devices advertised over mDNS (Android 11+, after "adb pair" once)
#   4. the last phone IP that worked, and every default gateway (= the phone when the laptop is on its hotspot)
#   5. a phone plugged in over USB: switch it to "adb tcpip 5555" and retry 1+4 plus the phone's own IPs.
#      tcpip mode stays on until the phone reboots, so after that one USB run no cable is needed.
param([string]$Target)

$ErrorActionPreference = 'SilentlyContinue'
$lastFile = Join-Path $env:LOCALAPPDATA 'inovasionline-adb-wifi-last.txt'

function Log($msg) { [Console]::Error.WriteLine("==> $msg") }

function Get-Devices {
    # serial -> state, from "adb devices"
    $list = @{}
    foreach ($line in (& adb devices 2>$null | Select-Object -Skip 1)) {
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2 -and $parts[0]) { $list[$parts[0]] = $parts[1] }
    }
    $list
}

function Test-Network($serial) { $serial -match ':' -or $serial -match '_adb-tls' }

function Try-Connect($addr) {
    if (-not $addr) { return $null }
    if ($addr -notmatch ':') { $addr = "${addr}:5555" }
    Log "adb connect $addr"
    $out = & adb connect $addr 2>&1 | Out-String
    if ($out -notmatch 'connected to') { return $null }
    $state = (& adb -s $addr get-state 2>$null | Out-String).Trim()
    if ($state -eq 'device') {
        Set-Content -Path $lastFile -Value ($addr -replace ':\d+$', '') -Encoding ascii
        return $addr
    }
    # Stale entry (phone rebooted / changed network): drop it so the next attempt starts clean.
    & adb disconnect $addr *> $null
    $null
}

function Get-Candidates {
    $c = @()
    if (Test-Path $lastFile) { $c += (Get-Content $lastFile -TotalCount 1).Trim() }
    $c += Get-NetIPConfiguration | ForEach-Object { $_.IPv4DefaultGateway.NextHop } | Where-Object { $_ }
    $c | Where-Object { $_ } | Select-Object -Unique
}

& adb start-server *> $null

if ($Target) {
    if ($serial = Try-Connect $Target) { Write-Output $serial; exit 0 }
} else {
    $devices = Get-Devices
    $serial = $devices.Keys | Where-Object { $devices[$_] -eq 'device' -and (Test-Network $_) } | Select-Object -First 1
    if ($serial) { Log "already connected: $serial"; Write-Output $serial; exit 0 }

    # "adb mdns services" lines: <name>  _adb-tls-connect._tcp  <ip>:<port>
    foreach ($line in (& adb mdns services 2>$null)) {
        if ($line -match '_adb-tls-connect\S*\s+(\d+\.\d+\.\d+\.\d+:\d+)') {
            if ($serial = Try-Connect $Matches[1]) { Write-Output $serial; exit 0 }
        }
    }
    foreach ($ip in Get-Candidates) {
        if ($serial = Try-Connect $ip) { Write-Output $serial; exit 0 }
    }
}

# Fallback: a phone on USB -> enable adb over TCP, then retry with its IPs.
$devices = Get-Devices
$usb = $devices.Keys | Where-Object { $devices[$_] -eq 'device' -and -not (Test-Network $_) } | Select-Object -First 1
if ($usb) {
    Log "USB device $usb found, enabling adb over Wi-Fi (adb tcpip 5555)"
    $phoneIps = (& adb -s $usb shell ip -4 -o addr 2>$null | Out-String) -split "`n" |
        Where-Object { $_ -notmatch '\slo\s' -and $_ -notmatch 'rmnet|ccmni|dummy' } |
        ForEach-Object { if ($_ -match 'inet (\d+\.\d+\.\d+\.\d+)') { $Matches[1] } }
    & adb -s $usb tcpip 5555 *> $null
    Start-Sleep -Seconds 3
    $retry = @($Target) + @(Get-Candidates) + @($phoneIps) | Where-Object { $_ } | Select-Object -Unique
    foreach ($ip in $retry) {
        if ($serial = Try-Connect $ip) {
            Log "connected over Wi-Fi; the USB cable can be unplugged now"
            Write-Output $serial
            exit 0
        }
    }
}

[Console]::Error.WriteLine('[ERROR] No Wi-Fi device found. Either:')
[Console]::Error.WriteLine('  - plug the phone in over USB once and rerun (adb tcpip 5555 is done automatically; lasts until the phone reboots), or')
[Console]::Error.WriteLine('  - Android 11+: Developer options > Wireless debugging > Pair device, run "adb pair ip:port" once, then rerun.')
exit 1
