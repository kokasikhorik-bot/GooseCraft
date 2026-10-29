@echo off
setlocal
if not exist "%~dp0goosecraft-client.exe" (
  >&2 echo GooseCraft client is missing beside the launcher.
  exit /b 3
)
"%~dp0goosecraft-client.exe" %*
exit /b %errorlevel%
