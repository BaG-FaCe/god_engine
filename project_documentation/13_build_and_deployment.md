# 13 — Build, Start & Deployment

## Schnellstart (Windows, empfohlen)

```powershell
.\start-dev.bat                                   # alles in einem Schritt
powershell -ExecutionPolicy Bypass -File .\start-dev.ps1 -SkipInstall
powershell -ExecutionPolicy Bypass -File .\start-dev.ps1 -ApiPort 3001 -WebPort 5174 -NoBrowser
.\stop-dev.ps1                                    # beide Prozesse sauber beenden
```

| Dienst | URL |
|---|---|
| SPA | http://127.0.0.1:5173 |
| API | http://127.0.0.1:3000/api/v1 |
| Health | http://127.0.0.1:3000/up |

## Manuell

```bash
# Backend
cd api
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server                  # :3000

# Frontend
cd ../web
npm install
npm run dev                       # :5173, Proxy /api → :3000
```

## Hintergrundjobs

```bash
cd api
bin/jobs                          # Solid-Queue-Worker (Linux/macOS)
# Windows: BACKGROUND_JOB_ADAPTER=async (kein separater Prozess)
```

## Build (Frontend)

```bash
cd web
npm run build                     # tsc -b && vite build → dist/ (Code-Splitting)
npm run preview                   # Vorschau des Production-Builds
```

## Deployment-Konfiguration

- `config/environments/production.rb` — Produktions-Einstellungen.
- `database.yml` (production) liest `DATABASE_PATH`, `CACHE_DATABASE_PATH`,
  `QUEUE_DATABASE_PATH` aus ENV.
- `cache.yml`/`queue.yml` — Solid Cache/Queue-Produktionswerte (Threads/Prozesse via
  `QUEUE_THREADS`, `JOB_CONCURRENCY`).
- Pflicht-Secrets in Produktion: `SECRET_KEY_BASE`, `AR_ENCRYPTION_*`.
- **Kein Docker/PostgreSQL/Redis** erforderlich — Bereitstellung = Ruby + Node +
  drei SQLite-Dateien.

## Windows-Besonderheiten

- `start-dev.ps1`/`start-dev.bat` starten API + SPA gemeinsam.
- `.dev-tools/fix-ca.ps1` + `ca-bundle.pem` beheben TLS/Zertifikatsprobleme (z. B.
  für `bundle install`/`npm install`).
- `JobAdapter` degradiert auf `async`, weil Solid Queue `fork` benötigt.

## Versionierung / Fortschritt

- `versioning.md` dokumentiert Meilensteine (Projekt-Archivieren/Löschen,
  Provider-Config, Notification-Lifecycle u. a.).
- Referenzspezifikation: `orignal_app_structure_ref.md` (21.800 B);
  `original_app_structure.md` ist leer (0 B).
