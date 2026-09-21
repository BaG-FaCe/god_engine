#Requires -Version 5.1
<#
.SYNOPSIS
  Stoppt die per start-dev.ps1 gestartete Entwicklungsumgebung.

.DESCRIPTION
  Beendet die Puma- (Rails-API) und Vite-Prozesse (node), die zu diesem
  Projektverzeichnis gehoeren, und loescht die stale Puma-PID-Datei.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ApiDir = Join-Path $Root 'api'

Write-Host '== GodEngine Stop ==' -ForegroundColor Cyan

$killed = 0

# 1. Gezielt Prozesse beenden, deren Kommandozeile auf api/ bzw. web/ zeigt.
foreach ($proc in Get-CimInstance Win32_Process -Filter "Name='ruby.exe' OR Name='node.exe'") {
  $cmd = $proc.CommandLine
  if ($null -ne $cmd -and ($cmd -like "*$Root*" -or $cmd -like '*god_engine*')) {
    Write-Host "Beende $($proc.Name) (PID $($proc.ProcessId)): $($cmd.Substring(0, [Math]::Min(120, $cmd.Length)))..."
    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    $killed++
  }
}

if ($killed -eq 0) {
  Write-Host 'Keine laufenden god_engine-Prozesse gefunden (Fallback: alle ruby/node-Prozesse bleiben unangetastet).' -ForegroundColor DarkGray
  Write-Host 'Tipp: Falls API/Web trotzdem laufen, Fenster manuell schliessen.'
} else {
  Write-Host "$killed Prozess(e) beendet." -ForegroundColor Green
}

# 2. Stale Puma-PID entfernen, damit der naechste Start nicht blockiert.
$PidFile = Join-Path $ApiDir 'tmp\pids\server.pid'
if (Test-Path $PidFile) {
  Remove-Item $PidFile -Force
  Write-Host 'Stale tmp/pids/server.pid entfernt.' -ForegroundColor DarkGray
}
