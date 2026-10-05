@echo off
setlocal

set "ROOT=%~dp0"
set "PROJECT_ROOT=%ROOT:~0,-1%"
set "GODOT="
set "BUNDLED=%ROOT%Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64.exe"
set "RUNTIME=%TEMP%\WARSEED\Godot_v4.6.3-stable_mono_win64"

if exist "%BUNDLED%" set "GODOT=%BUNDLED%"

if not defined GODOT if exist "%RUNTIME%\Godot_v4.6.3-stable_mono_win64.exe" set "GODOT=%RUNTIME%\Godot_v4.6.3-stable_mono_win64.exe"

if not defined GODOT if exist "%ROOT%Godot_v4.6.3-stable_mono_win64.rar" (
    echo Preparing the bundled Godot runtime. This happens once.
    if not exist "%TEMP%\WARSEED" mkdir "%TEMP%\WARSEED"
    tar.exe -xf "%ROOT%Godot_v4.6.3-stable_mono_win64.rar" -C "%TEMP%\WARSEED"
    if exist "%RUNTIME%\Godot_v4.6.3-stable_mono_win64.exe" set "GODOT=%RUNTIME%\Godot_v4.6.3-stable_mono_win64.exe"
)

if not defined GODOT for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
if not defined GODOT for /f "delims=" %%G in ('where godot4.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"

if not defined GODOT (
    echo Could not find Godot 4.6.3 .NET.
    echo Keep Godot_v4.6.3-stable_mono_win64.rar beside this script, or install Godot and add it to PATH.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT%tools\launch_warseed.ps1" -GodotPath "%GODOT%" -ProjectRoot "%PROJECT_ROOT%"
exit /b 0
