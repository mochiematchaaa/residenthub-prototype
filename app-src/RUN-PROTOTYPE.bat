@echo off
title ResidentHub app (front-end prototype, no database)
echo Starting the ResidentHub prototype. Front end only, no database.
echo The first start takes a few minutes.
echo.
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Install Flutter first and open a new terminal.
  pause
  exit /b 1
)
call flutter clean
call flutter pub get
call flutter run -d chrome --dart-define=PROTOTYPE=true
pause
