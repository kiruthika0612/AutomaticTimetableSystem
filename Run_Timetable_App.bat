@echo off
cd /d "%~dp0"

where wish >nul 2>nul
if %errorlevel%==0 (
    start "" wish main.tcl
    exit /b
)

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

echo Tcl/Tk was not found on this computer.
echo Please install Tcl/Tk, then run this file again.
pause
