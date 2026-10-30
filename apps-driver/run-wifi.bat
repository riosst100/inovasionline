@echo off
setlocal
cd /d "%~dp0"

REM Run the driver app on a physical Android phone over Wi-Fi (wireless debugging).
REM Usage: run-wifi.bat [device-id | ip:port] [extra flutter args]
REM   - ip:port          -> runs "adb connect" first (Android 10 and below, or after pairing)
REM   - no device-id     -> first already-connected wireless device is used
REM   - set PC_IP=x.x.x.x before running to override the auto-detected PC LAN address
REM First-time setup (Android 11+): Developer options > Wireless debugging > "Pair device with pairing code",
REM then run once:  adb pair <ip>:<pairing-port>
REM The phone and this PC must be on the same Wi-Fi, and the Windows firewall must allow ports 8001/8080.
REM Note: backend APP_URL is http://localhost:8000, so image/storage URLs will not load on the phone over Wi-Fi
REM unless APP_URL in the backend .env is changed to the PC LAN address.

where adb >nul 2>&1 || (echo [ERROR] adb not found in PATH & exit /b 1)

set "DEVICE=%~1"
if defined DEVICE (
  shift
  echo %DEVICE% | findstr /r "^[0-9][0-9.]*:[0-9][0-9]*$" >nul && adb connect %DEVICE%
) else (
  for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
    if "%%b"=="device" if not defined DEVICE (
      echo %%a | findstr /c:":" /c:"_adb-" >nul && set "DEVICE=%%a"
    )
  )
)
if not defined DEVICE (
  echo [ERROR] No wireless device found. Pair/connect first, e.g.  adb pair ip:port  then  run-wifi.bat ip:port
  adb devices -l
  exit /b 1
)
echo ==^> Using device: %DEVICE%

REM The phone reaches the backend through the PC's LAN address (no adb reverse over Wi-Fi).
if not defined PC_IP (
  for /f %%i in ('powershell -NoProfile -Command "$u=New-Object Net.Sockets.UdpClient; $u.Connect('8.8.8.8',53); $u.Client.LocalEndPoint.Address.ToString()"') do set "PC_IP=%%i"
)
if not defined PC_IP (
  echo [ERROR] Could not detect the PC LAN IP. Set it manually:  set PC_IP=192.168.x.x
  exit /b 1
)
echo ==^> Backend host: %PC_IP%

REM pubspec.yaml bundles .env, .env.dev and .env.prod as assets, so all three must exist (gitignored).
if not exist ".env"      (echo API_BASE_URL=http://127.0.0.1:8001/api>".env")
if not exist ".env.dev"  (echo API_BASE_URL=http://127.0.0.1:8001/api>".env.dev")
if not exist ".env.prod" (echo API_BASE_URL=http://127.0.0.1:8001/api>".env.prod")

REM Temporarily point .env.dev at the PC LAN IP. The original is kept in .env.dev.usb-bak and restored after the run
REM (if the run was killed with Ctrl+C, the next run-wifi.bat still starts from the backup; copy it back for USB).
if not exist ".env.dev.usb-bak" copy /y ".env.dev" ".env.dev.usb-bak" >nul
powershell -NoProfile -Command "(Get-Content -Raw '.env.dev.usb-bak') -replace '(127\.0\.0\.1|10\.0\.2\.2|localhost)','%PC_IP%' | Set-Content -NoNewline -Encoding ascii '.env.dev'"

call flutter pub get || (move /y ".env.dev.usb-bak" ".env.dev" >nul & exit /b 1)
flutter run -d %DEVICE% -t lib/main_dev.dart %1 %2 %3 %4 %5 %6 %7 %8 %9

move /y ".env.dev.usb-bak" ".env.dev" >nul
endlocal
