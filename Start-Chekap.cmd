@echo off
setlocal
set "CHEKAP_SELF=%~f0"
set "CHEKAP_HOME=%~dp0"
if "%~1"=="elevated" goto menu
fltmc >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:CHEKAP_SELF -ArgumentList 'elevated' -Verb RunAs" && exit /b
)
:menu
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Module (Join-Path $env:CHEKAP_HOME 'Chekap\Chekap.psd1'); Start-Chekap"
if errorlevel 1 pause
