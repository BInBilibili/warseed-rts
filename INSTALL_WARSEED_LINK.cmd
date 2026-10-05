@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\register_warseed_protocol.ps1"
if errorlevel 1 (
    echo Could not register the WARSEED launch link.
    pause
    exit /b 1
)
echo.
echo WARSEED launch link registered.
echo You can now use: warseed://launch
pause
