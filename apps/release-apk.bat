@echo off
REM Build the prod-flavor release APK, upload it to the production server,
REM and update the version/last-updated metadata read by the /download page.
setlocal enabledelayedexpansion

set SSH_KEY=%USERPROFILE%\.ssh\remote_recorder_vps
set SERVER=root@173.212.232.54
set REMOTE_DIR=/var/www/html/inovasionline/inovasionline-frontend-nextjs/public/downloads
set REMOTE_APK_NAME=inovasionline.apk
set LOCAL_APK=build\app\outputs\flutter-apk\app-prod-release.apk

REM --- Bump the build number in pubspec.yaml (1.0.0+1 -> 1.0.0+2), keep versionName as-is ---
for /f "usebackq delims=" %%r in (`powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\bump-build-number.ps1"`) do set PUBSPEC_RESULT=%%r

if "%PUBSPEC_RESULT%"=="" (
    echo Could not read/bump version in pubspec.yaml
    exit /b 1
)
for /f "tokens=1,2 delims=;" %%a in ("%PUBSPEC_RESULT%") do (
    set APP_VERSION=%%a
    set BUILD_NUMBER=%%b
)

REM --- Current timestamp as ISO 8601 (locale independent, includes time) ---
for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-ddTHH:mm:sszzz"') do set RELEASE_DATE=%%d

echo.
echo === Building release APK (prod flavor) v%APP_VERSION%+%BUILD_NUMBER% ===
call flutter build apk --flavor prod -t lib/main_prod.dart --release
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

if not exist "%LOCAL_APK%" (
    echo Built APK not found at %LOCAL_APK%
    exit /b 1
)

echo.
echo === Uploading APK to server ===
scp -i "%SSH_KEY%" "%LOCAL_APK%" "%SERVER%:%REMOTE_DIR%/%REMOTE_APK_NAME%"
if errorlevel 1 (
    echo Upload failed.
    exit /b 1
)

echo.
echo === Updating release.json on server ===
set LOCAL_JSON=%TEMP%\inovasionline_release.json
> "%LOCAL_JSON%" (
    echo {
    echo   "version": "%APP_VERSION%",
    echo   "buildNumber": %BUILD_NUMBER%,
    echo   "date": "%RELEASE_DATE%",
    echo   "filename": "%REMOTE_APK_NAME%"
    echo }
)

scp -i "%SSH_KEY%" "%LOCAL_JSON%" "%SERVER%:%REMOTE_DIR%/release.json"
if errorlevel 1 (
    echo Failed to update release.json.
    del "%LOCAL_JSON%" >nul 2>&1
    exit /b 1
)
del "%LOCAL_JSON%" >nul 2>&1

echo.
echo === Restarting frontend so the new file is served ===
ssh -i "%SSH_KEY%" %SERVER% "pm2 restart inovasionline"
if errorlevel 1 (
    echo Failed to restart frontend on server.
    exit /b 1
)

echo.
echo === Done ===
echo Version %APP_VERSION% (build %BUILD_NUMBER%) released on %RELEASE_DATE%
echo pubspec.yaml updated to version: %APP_VERSION%+%BUILD_NUMBER%
echo Live at https://inovasionline.com/download

endlocal
