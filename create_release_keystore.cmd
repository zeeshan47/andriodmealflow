@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

echo.
echo FASTPOS Android release signing setup
echo.
echo This creates a local signing key and key.properties file.
echo Keep both files safe. Future app updates must use the same key.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\create_release_keystore.ps1"

echo.
pause
