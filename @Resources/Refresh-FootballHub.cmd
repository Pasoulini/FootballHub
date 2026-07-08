@echo off
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SCRIPT=%~dp0Generate-FootballHub.ps1"

if /I "%~1"=="auto" (
    start "" /min "%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%" -RefreshRainmeter -ThrottleSeconds 55
) else (
    start "" /min "%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%" -RefreshRainmeter
)
