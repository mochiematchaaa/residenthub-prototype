@echo off
title ResidentHub prototype web build (no database)
call flutter pub get
call flutter build web --release --dart-define=PROTOTYPE=true
echo.
echo Done. The web build is in build\web
pause
