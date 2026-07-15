@echo off
cd /d "%~dp0"

REM ── 1. Try bundled tclkit first (works without Tcl installed) ────────────────
if exist "%~dp0tclkit.exe" (
    start "" "%~dp0tclkit.exe" main.tcl
    exit /b
)

REM ── 2. Try system-installed wish ────────────────────────────────────────────
where wish >nul 2>nul
if %errorlevel%==0 (
    start "" wish main.tcl
    exit /b
)

REM ── 3. Try common Tcl installation paths ────────────────────────────────────
if exist "C:\Tcl\bin\wish.exe" (
    start "" "C:\Tcl\bin\wish.exe" main.tcl
    exit /b
)
if exist "C:\Program Files\Tcl\bin\wish.exe" (
    start "" "C:\Program Files\Tcl\bin\wish.exe" main.tcl
    exit /b
)
if exist "C:\Program Files (x86)\Tcl\bin\wish.exe" (
    start "" "C:\Program Files (x86)\Tcl\bin\wish.exe" main.tcl
    exit /b
)

REM ── 4. Nothing found ────────────────────────────────────────────────────────
echo.
echo  Tcl/Tk was not found on this computer.
echo.
echo  To fix this, do ONE of the following:
echo.
echo  OPTION A (Recommended - No Install):
echo    Run build_exe\SETUP_TCLKIT.bat
echo    It will download tclkit.exe automatically.
echo    After that, double-click this .bat file again.
echo.
echo  OPTION B (Full Install):
echo    Download Tcl from https://www.activestate.com/products/tcl/
echo    Install it, then run this file again.
echo.
pause
