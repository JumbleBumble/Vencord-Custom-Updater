@echo off
setlocal
cd /d "%~dp0"
echo Setting up Vencord Updater...
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
set "result=%ERRORLEVEL%"
echo.
if not "%result%"=="0" echo Setup was not completed. See the error above.
pause
exit /b %result%
