@echo off
setlocal

REM ====== CONFIG ======
set "PROJECT_DIR=C:\yasuki\Sync\output\analyse-sth\sh000-web\sh-publichealth\info-hub\site"
set "PORT=4200"
set "FIREFOX_EXE=C:\Program Files\Mozilla Firefox\firefox.exe"

set "WATCH_DIRS=about-us;assets;downloads;how-we-work;our-data;our-work;whats-new"

REM Temp folder for Quarto preview session assets (keep OUTSIDE synced tree)
set "QUARTO_TMP=C:\quarto-tmp"
REM ====================

REM 0) Basic checks
if not exist "%PROJECT_DIR%\_quarto.yml" (
  echo ERROR: Can't find _quarto.yml in "%PROJECT_DIR%"
  pause
  exit /b 1
)

if not exist "%PROJECT_DIR%\touch-quarto-yaml.ps1" (
  echo ERROR: Can't find touch-quarto-yaml.ps1 in "%PROJECT_DIR%"
  pause
  exit /b 1
)

if not exist "%FIREFOX_EXE%" (
  echo ERROR: Can't find Firefox at "%FIREFOX_EXE%"
  pause
  exit /b 1
)

if not exist "%QUARTO_TMP%" (
  mkdir "%QUARTO_TMP%"
)

REM 1) Open project in VS Code
start "" code "%PROJECT_DIR%"

REM 2) Start the watcher
start "Quarto Touch Watcher" powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%PROJECT_DIR%\touch-quarto-yaml.ps1" ^
  -ProjectRoot "%PROJECT_DIR%" ^
  -WatchDirs "%WATCH_DIRS%"

REM 3) Start Quarto preview (stable TEMP/TMP to prevent missing quarto-session-temp assets)
start "Quarto Preview" cmd /k ^
  "set TEMP=%QUARTO_TMP% && set TMP=%QUARTO_TMP% && cd /d %PROJECT_DIR% && quarto preview --port %PORT% --no-browser"

REM 4) Open Firefox to preview URL
timeout /t 2 /nobreak >nul
start "" "%FIREFOX_EXE%" -new-window "http://localhost:%PORT%/"

endlocal
