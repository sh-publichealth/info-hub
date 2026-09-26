@echo off
setlocal EnableExtensions
REM ============================================================
REM SHG Info-Hub edit session launcher
REM Place this file at the root of the local info-hub repository.
REM
REM Double-click:      launch VS Code, Quarto preview, and Firefox.
REM From a terminal:   start-info-hub-edit.bat render
REM                    render the site once, then start preview.
REM ============================================================

REM Resolve the repository from this file, not the current directory.
set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "SITE=%REPO%\site"
set "VENV=%REPO%\.venv"
set "PYTHON=%VENV%\Scripts\python.exe"
set "ACTIVATE=%VENV%\Scripts\activate.bat"
set "PORT=4200"
set "URL=http://127.0.0.1:%PORT%/"

REM SHG private workspace is a sibling of the repository's parent folder.
REM Example: ...\analyse-sth\sh003-diabetes-registry-private
for %%I in ("%REPO%\..\..\sh003-diabetes-registry-private") do set "PRIVATE=%%~fI"
set "QUARTO_TMP=%PRIVATE%\work\quarto-tmp"

REM Internal worker commands run in their own activated Command Prompt.
if /I "%~1"=="_preview" goto :_preview
if /I "%~1"=="_render" goto :_render

REM Fail clearly rather than opening an unrelated folder or Python.
if not exist "%SITE%\_quarto.yml" (
    echo ERROR: Cannot find "%SITE%\_quarto.yml".
    echo Put this BAT file in the info-hub repository root.
    goto :fail
)
if not exist "%PYTHON%" (
    echo ERROR: Python virtual environment not found at "%VENV%".
    echo Create it from the repository root: py -m venv .venv
    goto :fail
)
if not exist "%ACTIVATE%" (
    echo ERROR: Missing virtual environment activation file.
    goto :fail
)
where quarto >nul 2>&1
if errorlevel 1 (
    echo ERROR: Quarto is not on PATH. Install Quarto or add it to PATH.
    goto :fail
)
if not exist "%PRIVATE%\work" mkdir "%PRIVATE%\work"
if not exist "%QUARTO_TMP%" mkdir "%QUARTO_TMP%"
if not exist "%QUARTO_TMP%" (
    echo ERROR: Could not create Quarto temporary directory:
    echo %QUARTO_TMP%
    goto :fail
)

REM Open the whole repository in VS Code, not just the site folder.
where code >nul 2>&1
if not errorlevel 1 (
    start "" code "%REPO%"
) else (
    set "VSCODE=%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe"
    if not exist "%VSCODE%" set "VSCODE=%ProgramFiles%\Microsoft VS Code\Code.exe"
    if exist "%VSCODE%" (
        start "" "%VSCODE%" "%REPO%"
    ) else (
        echo WARNING: VS Code not found; opening the repository in Explorer.
        start "" explorer.exe "%REPO%"
    )
)

REM The Quarto command runs in a separate shell with .venv activated.
REM TEMP and TMP are scoped to that shell, not changed system-wide.
if /I "%~1"=="render" (
    start "SHG Info-Hub Quarto Render" cmd /k ""%REPO%\start-info-hub-edit.bat" _render"
) else if "%~1"=="" (
    start "SHG Info-Hub Quarto Preview" cmd /k ""%REPO%\start-info-hub-edit.bat" _preview"
) else (
    echo ERROR: Unknown option "%~1". Use no option or render.
    goto :fail
)

REM Give preview a short head start; it may take longer on first build.
timeout /t 5 /nobreak >nul
set "FIREFOX=%ProgramFiles%\Mozilla Firefox\firefox.exe"
if not exist "%FIREFOX%" set "FIREFOX=%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe"
if exist "%FIREFOX%" (
    start "" "%FIREFOX%" "%URL%"
) else (
    echo WARNING: Firefox not found. Opening the default browser.
    start "" "%URL%"
)
exit /b 0

:_preview
call "%ACTIVATE%" || exit /b 1
set "TEMP=%QUARTO_TMP%"
set "TMP=%QUARTO_TMP%"
cd /d "%SITE%" || exit /b 1
echo.
echo Python: %PYTHON%
echo Preview: %URL%
echo Press Ctrl+C in this window to stop Quarto.
quarto preview --host 127.0.0.1 --port %PORT% --no-browser
exit /b %errorlevel%

:_render
call "%ACTIVATE%" || exit /b 1
set "TEMP=%QUARTO_TMP%"
set "TMP=%QUARTO_TMP%"
cd /d "%SITE%" || exit /b 1
echo.
echo Rendering SHG Info-Hub before starting preview...
quarto render
if errorlevel 1 (
    echo ERROR: Quarto render failed; preview was not started.
    exit /b 1
)
quarto preview --host 127.0.0.1 --port %PORT% --no-browser
exit /b %errorlevel%

:fail
echo.
pause
exit /b 1
