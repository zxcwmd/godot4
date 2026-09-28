@echo off
setlocal
chcp 65001 >nul
if not exist "%~dp0tools\check_project.ps1" (
  echo INCOMPLETE EXTRACTION: tools\check_project.ps1 is missing.
  echo Extract the entire ZIP, not just this file.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\check_project.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
echo Copy any MISSING, CHANGED or FAILED lines when reporting a problem.
pause
exit /b %RESULT%
