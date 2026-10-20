@echo off
setlocal
cd /d "%~dp0"

REM Run the admin app on a physical Android phone connected via USB.
REM Usage: run-usb.bat [device-id] [extra flutter args]
REM   (without device-id, the first physical USB device is used)

where adb >nul 2>&1 || (echo [ERROR] adb not found in PATH & exit /b 1)

set "DEVICE=%~1"
if defined DEVICE (
  shift
) else (
  for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
    if "%%b"=="device" if not defined DEVICE (
      echo %%a | findstr /b "emulator-" >nul || set "DEVICE=%%a"
    )
  )
)
if not defined DEVICE (
  echo [ERROR] No USB device found. Enable USB debugging, connect the phone, and accept the RSA prompt.
  adb devices -l
  exit /b 1
)
echo ==^> Using device: %DEVICE%

REM pubspec.yaml bundles .env, .env.dev and .env.prod as assets, so all three must exist
REM (gitignored). 127.0.0.1 reaches the PC backend through adb reverse.
if not exist ".env"      (echo API_BASE_URL=http://127.0.0.1:8001/api>".env")
if not exist ".env.dev"  (echo API_BASE_URL=http://127.0.0.1:8001/api>".env.dev")
if not exist ".env.prod" (echo API_BASE_URL=http://127.0.0.1:8001/api>".env.prod")

REM adb reverse resets on every USB reconnect, so set it up before each run.
for %%p in (8001 8002 8080) do adb -s %DEVICE% reverse tcp:%%p tcp:%%p
REM Backend APP_URL is http://localhost:8000, so image/storage URLs point at device port 8000.
REM The container is published on PC port 8001, so map device 8000 -> PC 8001.
adb -s %DEVICE% reverse tcp:8000 tcp:8001
adb -s %DEVICE% reverse --list

call flutter pub get || exit /b 1
flutter run -d %DEVICE% -t lib/main_dev.dart %1 %2 %3 %4 %5 %6 %7 %8 %9
endlocal
