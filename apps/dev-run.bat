@echo off
REM Forward backend ports from PC to the connected Android device via USB,
REM then launch the app. adb reverse resets on every USB reconnect/adb
REM restart, so this must run before each `flutter run`.
adb reverse tcp:8001 tcp:8001
adb reverse tcp:8080 tcp:8080
flutter run --flavor dev -t lib/main_dev.dart -v %*
