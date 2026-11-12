@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Brotato Cheat Helper

set "MARK_PREFIX=; CheatHelper override"
set "MARK=; CheatHelper override - remove with uninstall.bat"
set "SRC=%~dp0src\Local-CheatHelper"
set "MODE=install"
set "GAME_DIR="

if /i "%~1"=="--uninstall" (
    set "MODE=uninstall"
    shift
)
if not "%~1"=="" set "GAME_DIR=%~1"

if not defined GAME_DIR call :find_game
if not defined GAME_DIR (
    echo Could not find Brotato automatically.
    set /p "GAME_DIR=Paste your Brotato install folder and press Enter: "
)
if not defined GAME_DIR goto :fail_nogame
set "GAME_DIR=!GAME_DIR:"=!"
if "!GAME_DIR:~-1!"=="\" set "GAME_DIR=!GAME_DIR:~0,-1!"
if not exist "!GAME_DIR!\Brotato.pck" goto :fail_nogame

set "CFG=!GAME_DIR!\override.cfg"
set "TARGET=!GAME_DIR!\CheatHelper"

echo Brotato folder: !GAME_DIR!
echo.

if exist "!CFG!" (
    set "FIRST="
    set /p FIRST=<"!CFG!"
    if not "!FIRST:~0,22!"=="!MARK_PREFIX!" (
        echo ERROR: !CFG! belongs to something else. It was left untouched.
        goto :end_error
    )
)

if "!MODE!"=="uninstall" goto :uninstall

if not exist "!SRC!\cheat_autoload.gd" (
    echo ERROR: Mod files not found in !SRC!
    goto :end_error
)

if exist "!TARGET!" rmdir /s /q "!TARGET!"
xcopy "!SRC!" "!TARGET!\" /e /i /q /y >nul
if errorlevel 1 (
    echo ERROR: Could not copy mod files to !TARGET!
    echo Try running this file as administrator.
    goto :end_error
)

set "SCRIPT=!TARGET:\=/!/cheat_autoload.gd"
> "!CFG!" (
    echo !MARK!
    echo.
    echo [autoload]
    echo.
    echo CheatHelper="*!SCRIPT!"
)
if errorlevel 1 (
    echo ERROR: Could not write !CFG!
    echo Try running this file as administrator.
    goto :end_error
)

if exist "!GAME_DIR!\mods\Local-CheatHelper.zip" del /q "!GAME_DIR!\mods\Local-CheatHelper.zip"

echo Installed.
echo   Mod files : !TARGET!
echo   Loader    : !CFG!
echo.
echo Start Brotato. You should see "CheatHelper loaded (F5-F9)" in the top-left corner.
goto :end_ok

:uninstall
set "REMOVED="
if exist "!CFG!" (
    del /q "!CFG!"
    set "REMOVED=1"
    echo Removed !CFG!
)
if exist "!TARGET!" (
    rmdir /s /q "!TARGET!"
    set "REMOVED=1"
    echo Removed !TARGET!
)
if not defined REMOVED echo Cheat Helper is not installed. Nothing to do.
if defined REMOVED echo Uninstalled.
goto :end_ok

:find_game
set "STEAM="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| find /i "SteamPath"') do set "STEAM=%%B"
if defined STEAM (
    set "STEAM=!STEAM:/=\!"
    call :try_library "!STEAM!"
    if exist "!STEAM!\steamapps\libraryfolders.vdf" (
        for /f "usebackq tokens=1,*" %%A in (`findstr /c:"\"path\"" "!STEAM!\steamapps\libraryfolders.vdf"`) do (
            set "LIB=%%~B"
            set "LIB=!LIB:\\=\!"
            call :try_library "!LIB!"
        )
    )
)
call :try_library "%ProgramFiles(x86)%\Steam"
call :try_library "%ProgramFiles%\Steam"
exit /b 0

:try_library
if defined GAME_DIR exit /b 0
if exist "%~1\steamapps\common\Brotato\Brotato.pck" set "GAME_DIR=%~1\steamapps\common\Brotato"
exit /b 0

:fail_nogame
echo ERROR: Brotato was not found.
echo Pass the folder that contains Brotato.exe, for example:
echo   install.bat "D:\SteamLibrary\steamapps\common\Brotato"
goto :end_error

:end_ok
echo.
if not defined CHEATHELPER_NOPAUSE pause
endlocal
exit /b 0

:end_error
echo.
if not defined CHEATHELPER_NOPAUSE pause
endlocal
exit /b 1
