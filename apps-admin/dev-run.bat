@echo off
REM Forward the backend port from PC to the connected Android device via USB,
REM then launch the admin app against the local API (.env.dev).
adb reverse tcp:8000 tcp:8000
flutter run -t lib/main_dev.dart %*
