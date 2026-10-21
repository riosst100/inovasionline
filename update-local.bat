@echo off
REM Setelah git pull: sync ke WSL, lalu docker exec migrate / composer / npm install untuk
REM semua project (backend, frontend-admin, frontend). apps* (Flutter) tidak disentuh.
REM Terakhir menyalakan wsl-watch (auto sync) jika belum jalan.
REM   update-local.bat            -> pull + sync + migrate + install + watch
REM   update-local.bat nopull     -> lewati git pull
setlocal
cd /d "%~dp0"

set DISTRO=Ubuntu-24.04
set DEST=$HOME/projects/inovasionline
set DC=cd %DEST% ^&^& docker compose

if /i not "%~1"=="nopull" (
  echo.
  echo ==^> git pull
  git pull --ff-only || goto :fail
)

echo.
echo ==^> Sync Windows -^> WSL
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync.ps1" sync || goto :fail

echo.
echo ==^> Docker: start container
wsl -d %DISTRO% -- bash -lc "%DC% up -d" || goto :fail

echo.
echo ==^> Backend: tunggu setup selesai
wsl -d %DISTRO% -- bash -lc "%DC% exec -T backend sh -c 'until test -f storage/framework/.inovasionline-ready; do sleep 2; done'" || goto :fail

echo.
echo ==^> Backend: composer install
wsl -d %DISTRO% -- bash -lc "%DC% exec -T backend composer install --no-interaction --prefer-dist" || goto :fail

echo.
echo ==^> Backend: migrate
wsl -d %DISTRO% -- bash -lc "%DC% exec -T backend php artisan migrate --force" || goto :fail

echo.
echo ==^> Backend: clear cache + restart queue
wsl -d %DISTRO% -- bash -lc "%DC% exec -T backend php artisan optimize:clear && %DC% exec -T backend php artisan queue:restart" || goto :fail

echo.
echo ==^> Next.js: npm install (admin)
wsl -d %DISTRO% -- bash -lc "%DC% exec -T admin npm install --no-audit --no-fund" || goto :fail

echo.
echo ==^> Next.js: npm install (frontend)
wsl -d %DISTRO% -- bash -lc "%DC% exec -T frontend npm install --no-audit --no-fund" || goto :fail

echo.
echo ==^> Restart reverb
wsl -d %DISTRO% -- bash -lc "%DC% restart reverb" || goto :fail

echo.
echo ==^> Auto sync (wsl-watch)
powershell -NoProfile -Command "if (Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*wsl-watch.ps1*' }) { 'wsl-watch sudah jalan' } else { Start-Process powershell -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File','%~dp0scripts\wsl-watch.ps1'; 'wsl-watch dinyalakan di jendela baru' }"

echo.
echo ==^> Selesai
wsl -d %DISTRO% -- bash -lc "%DC% ps"
endlocal
exit /b 0

:fail
echo.
echo [GAGAL] langkah di atas error, update dihentikan.
endlocal
exit /b 1
