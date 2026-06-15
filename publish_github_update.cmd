@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

echo.
echo FASTPOS Android GitHub update publisher
echo.
set /p VERSION_NAME=Enter new version number, for example 1.1: 

if "%VERSION_NAME%"=="" (
    echo Version number is required.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\publish_github_update.ps1" -VersionName "%VERSION_NAME%"

echo.
pause
