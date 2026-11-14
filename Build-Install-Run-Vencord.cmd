@echo off
setlocal
cd /d "%~dp0"
echo Building and installing your current Vencord source...
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Install-Run-Vencord.ps1"
set "result=%ERRORLEVEL%"
echo.
if not "%result%"=="0" (
    echo The Vencord build or installation failed. See the error above.
) else (
    echo Finished successfully.
)
pause
exit /b %result%
