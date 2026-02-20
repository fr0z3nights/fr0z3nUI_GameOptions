@echo off
setlocal

REM Double-click to regenerate textures\textures.lua from textures\*.tga

set "ROOT=%~dp0"
set "SCRIPT=%ROOT%texturesUpdater.ps1"

if not exist "%SCRIPT%" (
  echo ERROR: Generator script not found:
  echo   %SCRIPT%
  echo.
  pause
  exit /b 1
)

echo Regenerating texture list...
echo   %SCRIPT%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "EC=%ERRORLEVEL%"

echo.
if not "%EC%"=="0" (
  echo FAILED with exit code %EC%
) else (
  echo Done.
)

pause
exit /b %EC%
