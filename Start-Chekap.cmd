@echo off
setlocal
set "CHEKAP_HOME=%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "Import-Module (Join-Path $env:CHEKAP_HOME 'Chekap\Chekap.psd1'); Start-Chekap"
if errorlevel 1 pause
