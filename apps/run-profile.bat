@echo off
setlocal
cd /d "%~dp0"

REM Run the app in PROFILE mode on a physical Android phone connected over Wi-Fi (adb connect /
REM wireless debugging), for measuring performance: open DevTools > Performance from the link
REM flutter prints. Debug mode is much slower than a real build and gives misleading numbers;
REM profile mode is close to release but still lets DevTools attach. It does not run on emulators.
REM Usage: run-profile.bat [ip[:port]] [extra flutter args]
REM   (with ip, runs "adb connect" first; port defaults to 5555. Without ip, the first
REM    already-connected network device is used.)
REM Laptop on the phone's hotspot: the phone's IP is the Wi-Fi "Default Gateway" in ipconfig.
REM Hot reload is not available in profile mode; press "R" to restart or "q" to quit.

where adb >nul 2>&1 || (echo [ERROR] adb not found in PATH & exit /b 1)

set "DEVICE=%~1"
if defined DEVICE (
  shift
  echo %DEVICE% | findstr ":" >nul || set "DEVICE=%DEVICE%:5555"
)
if defined DEVICE (
  adb connect %DEVICE% | findstr /i "connected" >nul || (
    echo [ERROR] adb connect %DEVICE% failed. For hotspot: plug in USB once and run "adb tcpip 5555".
    exit /b 1
  )
) else (
  REM Network devices show up as ip:port or adb-<serial>._adb-tls-connect._tcp (wireless debugging).
  for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
    if "%%b"=="device" if not defined DEVICE (
      echo %%a | findstr /r ": _adb-tls" >nul && set "DEVICE=%%a"
    )
  )
)
if not defined DEVICE (
  echo [ERROR] No Wi-Fi device found. Run: run-profile.bat ^<phone-ip^>
  adb devices -l
  exit /b 1
)
echo ==^> Using device: %DEVICE% (profile mode)

REM pubspec.yaml bundles .env, .env.dev and .env.prod as assets, so all three must exist
REM (gitignored). 127.0.0.1 in .env.example works via adb reverse (also over Wi-Fi adb).
if not exist ".env"      copy /y ".env.example" ".env" >nul
if not exist ".env.dev"  copy /y ".env.example" ".env.dev" >nul
if not exist ".env.prod" copy /y ".env.prod.example" ".env.prod" >nul

REM adb reverse resets on every reconnect, so set it up before each run.
for %%p in (8000 8001 8002 8080) do adb -s %DEVICE% reverse tcp:%%p tcp:%%p
adb -s %DEVICE% reverse --list

call flutter pub get || exit /b 1
flutter run --profile -d %DEVICE% --flavor dev -t lib/main_dev.dart %1 %2 %3 %4 %5 %6 %7 %8 %9
endlocal
