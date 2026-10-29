@echo off
if "%~1"=="elevated" goto menu
fltmc >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs" && exit /b
)
:menu
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -Command "Import-Module '%~dp0Chekap\Chekap.psd1'; Start-Chekap"
