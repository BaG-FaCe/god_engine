#Requires -Version 5.1
<#
.SYNOPSIS
  Startet die Verkaufspreis-Kalkulationsplattform (Rails-API + Vite-SPA).

.DESCRIPTION
  - Backend : cd api  -> bundle install, rails db:prepare, rails db:seed,
              dann Puma auf http://127.0.0.1:3000 (SQLite + Solid Queue/Cache,
              kein Docker / PostgreSQL / Redis noetig).
              Auf Windows laeuft der Job-Worker im Web-Prozess
              (BACKGROUND_JOB_ADAPTER=async), da Solid Queue `fork` braucht.
  - Frontend: cd web  -> npm install (falls noetig), vite dev auf
              http://127.0.0.1:5173 mit API-Proxy nach :3000.
  Beide Prozesse laufen in eigenen Fenstern. Dieses Fenster bleibt als
  Status-Fenster offen und wartet auf den API-Healthcheck.

.PARAMETER ApiPort
  Port der Rails-API. Default 3000.

.PARAMETER WebPort
  Port des Vite-Dev-Servers. Default 5173.

.PARAMETER SkipInstall
  Ueberspringt `bundle install` / `npm install` / `db:prepare` / `db:seed`
  (fuer den schnellen Neustart).

.PARAMETER NoBrowser
  Oeffnet den Browser nicht automatisch.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\start-dev.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\start-dev.ps1 -SkipInstall
#>
[CmdletBinding()]
param(
  [int]$ApiPort = 3000,
  [int]$WebPort = 5173,
  [switch]$SkipInstall,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ApiDir = Join-Path $Root 'api'
$WebDir = Join-Path $Root 'web'

function Assert-Command([string]$Name, [string]$Hint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Write-Host "FEHLT: '$Name' wurde nicht gefunden. $Hint" -ForegroundColor Red
    exit 1
  }
}

Write-Host '== GodEngine Launcher ==' -ForegroundColor Cyan
Write-Host "Root: $Root"

Assert-Command 'ruby'   'Ruby 3.3+ installieren (https://rubyinstaller.org).'
Assert-Command 'bundle' 'Bundler via `gem install bundler` installieren.'
Assert-Command 'node'   'Node.js LTS installieren (https://nodejs.org).'
Assert-Command 'npm'    'Wird mit Node.js mitgeliefert.'

if (-not (Test-Path (Join-Path $ApiDir 'Gemfile'))) { Write-Host "FEHLT: $ApiDir\Gemfile nicht gefunden." -ForegroundColor Red; exit 1 }
if (-not (Test-Path (Join-Path $WebDir 'package.json'))) { Write-Host "FEHLT: $WebDir\package.json nicht gefunden." -ForegroundColor Red; exit 1 }

# --- 1. Backend vorbereiten -------------------------------------------------
Push-Location $ApiDir
try {
  if (-not $SkipInstall) {
    Write-Host '[1/4] bundle install ...' -ForegroundColor Yellow
    bundle install
    Write-Host '[2/4] rails db:prepare ...' -ForegroundColor Yellow
    bundle exec rails db:prepare
    Write-Host '[3/4] rails db:seed (idempotent) ...' -ForegroundColor Yellow
    bundle exec rails db:seed
  } else {
    Write-Host '[1-3/4] uebersprungen (-SkipInstall).' -ForegroundColor DarkGray
  }
} finally { Pop-Location }

# --- 2. API in eigenem Fenster starten --------------------------------------
$ApiCmd = "cd '$ApiDir'; `$env:PORT='$ApiPort'; `$env:BACKGROUND_JOB_ADAPTER='async'; Write-Host 'GodEngine API startet auf http://127.0.0.1:$ApiPort ...' -ForegroundColor Cyan; bundle exec rails server -b 127.0.0.1 -p $ApiPort"
Write-Host '[4/4] Starte API-Fenster ...' -ForegroundColor Yellow
Start-Process powershell -ArgumentList @('-NoExit', '-NoProfile', '-Command', $ApiCmd) | Out-Null

# --- 3. Auf API-Health warten ------------------------------------------------
$HealthUrl = "http://127.0.0.1:$ApiPort/up"
Write-Host "Warte auf API ($HealthUrl) ..." -ForegroundColor DarkGray
$Ready = $false
for ($i = 1; $i -le 60; $i++) {
  try {
    $r = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -eq 200) { $Ready = $true; break }
  } catch { Start-Sleep -Seconds 2 }
}
if ($Ready) { Write-Host 'API ist bereit.' -ForegroundColor Green }
else { Write-Host 'WARNUNG: API antwortet noch nicht - Web wird trotzdem gestartet (Logs im API-Fenster pruefen).' -ForegroundColor Yellow }

# --- 4. Frontend in eigenem Fenster starten ----------------------------------
if (-not (Test-Path (Join-Path $WebDir 'node_modules'))) {
  if ($SkipInstall) { Write-Host 'WARNUNG: web/node_modules fehlt, trotz -SkipInstall wird `npm install` ausgefuehrt.' -ForegroundColor Yellow }
  Write-Host 'npm install ...' -ForegroundColor Yellow
  Push-Location $WebDir; try { npm install } finally { Pop-Location }
}
$WebCmd = "cd '$WebDir'; Write-Host 'GodEngine Web startet auf http://127.0.0.1:$WebPort ...' -ForegroundColor Cyan; npm run dev -- --port $WebPort --host 127.0.0.1"
Write-Host 'Starte Web-Fenster ...' -ForegroundColor Yellow
Start-Process powershell -ArgumentList @('-NoExit', '-NoProfile', '-Command', $WebCmd) | Out-Null

Start-Sleep -Seconds 4

Write-Host ''
Write-Host 'Laeuft:' -ForegroundColor Green
Write-Host "  API : http://127.0.0.1:$ApiPort  (Health: $HealthUrl)"
Write-Host "  Web : http://127.0.0.1:$WebPort  (App im Browser)"
Write-Host '  Login (Seed): admin@god-engine.local / GodEngine-Admin-123'
Write-Host '  Stoppen mit:  .\stop-dev.ps1  (oder Fenster schliessen)'
Write-Host ''

if (-not $NoBrowser) {
  try { Start-Process "http://127.0.0.1:$WebPort" } catch { Write-Host 'Browser konnte nicht automatisch geoeffnet werden.' -ForegroundColor Yellow }
}
