@echo off
REM Build the prod-flavor release App Bundle (.aab) for upload to the Google Play Console.
REM Play rejects debug-signed bundles, so this refuses to build without android\key.properties.
setlocal enabledelayedexpansion

set KEY_PROPERTIES=android\key.properties
set LOCAL_AAB=build\app\outputs\bundle\prodRelease\app-prod-release.aab

if not exist "%KEY_PROPERTIES%" (
    echo %KEY_PROPERTIES% not found - the bundle would be signed with the debug key and Play would reject it.
    echo.
    echo 1. Create an upload keystore ^(once; back it up and keep the passwords safe^):
    echo    keytool -genkey -v -keystore "%USERPROFILE%\inovasionline-upload.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    echo.
    echo 2. Create %KEY_PROPERTIES% with:
    echo    storePassword=^<store password^>
    echo    keyPassword=^<key password^>
    echo    keyAlias=upload
    echo    storeFile=%USERPROFILE:\=/%/inovasionline-upload.jks
    exit /b 1
)

findstr /r /c:"^admobAppIdAndroid=..*" android\gradle.properties >nul
if errorlevel 1 (
    echo WARNING: admobAppIdAndroid is empty in android\gradle.properties - this bundle will only serve AdMob test ads.
    choice /m "Continue anyway"
    if errorlevel 2 exit /b 1
)

REM --- Bump the build number in pubspec.yaml (1.0.0+1 -> 1.0.0+2); Play requires a higher versionCode per upload ---
for /f "usebackq delims=" %%r in (`powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\bump-build-number.ps1"`) do set PUBSPEC_RESULT=%%r

if "%PUBSPEC_RESULT%"=="" (
    echo Could not read/bump version in pubspec.yaml
    exit /b 1
)
for /f "tokens=1,2 delims=;" %%a in ("%PUBSPEC_RESULT%") do (
    set APP_VERSION=%%a
    set BUILD_NUMBER=%%b
)

echo.
echo === Building release App Bundle (prod flavor) v%APP_VERSION%+%BUILD_NUMBER% ===
call flutter build appbundle --flavor prod -t lib/main_prod.dart --release
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

if not exist "%LOCAL_AAB%" (
    echo Built bundle not found at %LOCAL_AAB%
    exit /b 1
)

echo.
echo === Done ===
echo Version %APP_VERSION% (build %BUILD_NUMBER%)
echo Upload this file in Play Console:
echo   %CD%\%LOCAL_AAB%

endlocal
