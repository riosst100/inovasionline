# Auto-sync D:\inovasionline -> WSL setiap file disimpan (FileSystemWatcher + debounce).
# Jalankan: powershell -ExecutionPolicy Bypass -File scripts\wsl-watch.ps1
param(
  [string]$Distro = 'Ubuntu-24.04',
  [string]$Dest = '$HOME/projects/inovasionline',
  [int]$DebounceMs = 400
)
$root = (Resolve-Path "$PSScriptRoot\..").Path
$srcWsl = ((wsl -d $Distro -- wslpath -a $root.Replace([string][char]92, '/')) | Out-String).Trim()
if (-not $srcWsl -or -not $srcWsl.StartsWith('/mnt/')) { throw "wslpath gagal: '$srcWsl'" }
$skip = '[\\/](\.git|node_modules|\.next|vendor|apps|logs|framework)([\\/]|$)|[\\/]storage[\\/]app([\\/]|$)|[\\/]\.env$'

function Sync-Now {
  $cmd = "mkdir -p $Dest && rsync -a --delete --exclude='.git/' --exclude='node_modules/' --exclude='.next/' --exclude='backend/vendor/' --exclude='backend/.env' --exclude='backend/storage/logs/' --exclude='backend/storage/framework/' --exclude='backend/storage/app/' --exclude='backend/public/storage' --exclude='apps/' --exclude='.env' '$srcWsl/' $Dest/"
  wsl -d $Distro -- bash -lc $cmd
  Write-Host ("[{0}] synced" -f (Get-Date -Format HH:mm:ss))
}

$fsw = New-Object IO.FileSystemWatcher $root
$fsw.IncludeSubdirectories = $true
$fsw.NotifyFilter = 'FileName, DirectoryName, LastWrite, Size'
$fsw.EnableRaisingEvents = $true
$ev = 'Changed','Created','Deleted','Renamed' | ForEach-Object { Register-ObjectEvent $fsw $_ -SourceIdentifier "w$_" }

Sync-Now
Write-Host "Watching $root (Ctrl+C untuk stop)"
try {
  while ($true) {
    $e = Wait-Event -Timeout 5
    if (-not $e) { continue }
    $dirty = $false
    do {
      foreach ($x in @($e)) {
        if ($x.SourceEventArgs.FullPath -notmatch $skip) { $dirty = $true }
        Remove-Event -EventIdentifier $x.EventIdentifier
      }
      Start-Sleep -Milliseconds $DebounceMs
      $e = Get-Event
    } while ($e)
    if ($dirty) { Sync-Now }
  }
} finally {
  Get-EventSubscriber | Unregister-Event
  $fsw.Dispose()
}
