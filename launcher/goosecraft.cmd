@echo off
setlocal
set "client=goosecraft-client.exe"
if "%~1"=="--headless" set "client=goosecraft-headless.exe"
if not exist "%~dp0%client%" (
  >&2 echo GooseCraft client is missing beside the launcher.
  exit /b 3
)
"%~dp0%client%" %*
exit /b %errorlevel%
