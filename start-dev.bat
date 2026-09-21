@echo off
REM ==========================================================================
REM  GodEngine Launcher (CMD-Doppelklick) - Rails-API + Vite-SPA starten
REM
REM  Das ist ein duenner Wrapper um start-dev.ps1. Fuer Optionen
REM  (Ports, -SkipInstall, -NoBrowser) PowerShell direkt nutzen, z. B.:
REM    powershell -ExecutionPolicy Bypass -File start-dev.ps1 -SkipInstall
REM ==========================================================================
setlocal
cd /d "%~dp0"
where powershell >nul 2>nul
if errorlevel 1 (
  echo FEHLT: powershell.exe wurde nicht gefunden.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-dev.ps1" %*
if errorlevel 1 (
  echo.
  echo Start FEHLGESCHLAGEN - Meldungen oben pruefen.
  pause
  exit /b 1
)
endlocal
