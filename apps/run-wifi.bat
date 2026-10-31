@echo off
setlocal
cd /d "%~dp0"

REM Run the app on a physical Android phone connected over Wi-Fi (adb connect / wireless debugging).
REM Usage: run-wifi.bat [ip[:port]] [extra flutter args]
REM Without ip the phone is found automatically (scripts\adb-wifi-connect.ps1): an already-connected
REM device, wireless debugging (mDNS), the last IP used, or the Wi-Fi default gateway (laptop on the phone's
REM hotspot). If none answers and the phone is on USB, "adb tcpip 5555" is run for you; that lasts until the
REM phone reboots, so plug in USB once after each reboot.

where adb >nul 2>&1 || (echo [ERROR] adb not found in PATH & exit /b 1)

set "TARGET=%~1"
if defined TARGET if "%TARGET:~0,1%"=="-" set "TARGET="
if defined TARGET shift

set "DEVICE="
for /f "usebackq delims=" %%d in (`powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\adb-wifi-connect.ps1" "%TARGET%"`) do set "DEVICE=%%d"
if not defined DEVICE (
  adb devices -l
  exit /b 1
)
echo ==^> Using device: %DEVICE%

REM pubspec.yaml bundles .env, .env.dev and .env.prod as assets, so all three must exist
REM (gitignored). 127.0.0.1 in .env.example works via adb reverse (also over Wi-Fi adb).
if not exist ".env"      copy /y ".env.example" ".env" >nul
if not exist ".env.dev"  copy /y ".env.example" ".env.dev" >nul
if not exist ".env.prod" copy /y ".env.prod.example" ".env.prod" >nul

REM adb reverse resets on every reconnect, so set it up before each run.
for %%p in (8000 8001 8002 8080) do adb -s %DEVICE% reverse tcp:%%p tcp:%%p
adb -s %DEVICE% reverse --list

call flutter pub get || exit /b 1
flutter run -d %DEVICE% --flavor dev -t lib/main_dev.dart %1 %2 %3 %4 %5 %6 %7 %8 %9
endlocal
