# Sync kode Windows -> WSL lalu jalankan Docker di sana. Wrapper PowerShell untuk scripts/wsl-sync.sh.
# `bash` di PowerShell adalah bash WSL (tanpa wsl/cygpath), jadi script dijalankan lewat Git Bash.
#   .\sync.ps1                # sync sekali
#   .\sync.ps1 watch          # sync otomatis tiap file disimpan (Ctrl+C untuk stop)
#   .\sync.ps1 up             # sync + docker compose up -d --build
#   .\sync.ps1 logs admin     # juga: ps, down
param(
  [ValidateSet('sync', 'up', 'watch', 'down', 'logs', 'ps')]
  [string]$Command = 'sync',
  [string]$Service = ''
)
$ErrorActionPreference = 'Stop'

$git = Get-Command git -ErrorAction SilentlyContinue
$gitBash = if ($git) { Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe' }
if (-not $gitBash -or -not (Test-Path $gitBash)) { $gitBash = "$env:ProgramFiles\Git\bin\bash.exe" }
if (-not (Test-Path $gitBash)) { throw 'Git Bash tidak ditemukan. Install Git for Windows.' }

$script = Join-Path $PSScriptRoot 'scripts\wsl-sync.sh'
$cmdArgs = @($script, $Command)
if ($Service) { $cmdArgs += $Service }
& $gitBash @cmdArgs
exit $LASTEXITCODE
