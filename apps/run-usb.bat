@echo off
setlocal
cd /d "%~dp0"

REM Run the app on a physical Android phone connected via USB.
REM Usage: run-usb.bat [device-id] [extra flutter args]
REM   (without device-id, the first physical USB device is used)

where adb >nul 2>&1 || (echo [ERROR] adb not found in PATH & exit /b 1)

REM Pick device: first arg if it looks like a serial, else first "device" that is not an emulator.
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
REM (gitignored). 127.0.0.1 in .env.example works via adb reverse.
if not exist ".env"      copy /y ".env.example" ".env" >nul
if not exist ".env.dev"  copy /y ".env.example" ".env.dev" >nul
if not exist ".env.prod" copy /y ".env.prod.example" ".env.prod" >nul

REM adb reverse resets on every USB reconnect, so set it up before each run.
for %%p in (8000 8001 8002 8080) do adb -s %DEVICE% reverse tcp:%%p tcp:%%p
adb -s %DEVICE% reverse --list

call flutter pub get || exit /b 1
flutter run -d %DEVICE% --flavor dev -t lib/main_dev.dart %1 %2 %3 %4 %5 %6 %7 %8 %9
endlocal
