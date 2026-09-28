# 09 — Konfiguration

## Konfigurationsdateien

| Datei | Inhalt |
|---|---|
| `api/config/application.rb` | Rails-App-Konfig, Autoload-Pfade, API-only, Zeit/Locale, Verschlüsselungs-Keys |
| `api/config/database.yml` | 3 SQLite-DBs (primary/cache/queue) je Env, WAL-Pragmas |
| `api/config/routes.rb` | REST-Routen (modularer Monolith) |
| `api/config/cache.yml` | Solid Cache (max_age 30 d, max_size 512 MB, Namespace=Env) |
| `api/config/queue.yml` | Solid Queue (dispatchers/workers, Threads, Prozesse) |
| `api/config/recurring.yml` | Cron-artige Jobs (Fugit-Schedules) |
| `api/config/risk_providers.yml` | Provider-Katalog (Daten statt Code) |
| `api/config/risk_country_data.yml` | Länder-/Regionen-Daten |
| `api/config/risk_port_data.yml` | Hafendaten |
| `api/config/puma.rb` | App-Server |
| `api/config/environments/*.rb` | Umgebungs-Konfiguration |
| `api/config/initializers/*` | cors, rack_attack, background_jobs, filter_parameter_logging, inflections |
| `web/vite.config.ts` | Vite, Aliase (`@apps`, `@shared`), Proxy `/api` → :3000, Chunks |
| `web/tsconfig.json` | TypeScript-Konfiguration |

## Wichtige Umgebungsvariablen (`api/.env.example`)

**Core:** `RAILS_ENV`, `RAILS_LOG_LEVEL`, `PORT`, `CORS_ORIGINS`.

**Jobs:** `BACKGROUND_JOB_ADAPTER` (`solid_queue` | `async` | `inline`),
`QUEUE_THREADS`, `JOB_CONCURRENCY`.

**Secrets (Produktion Pflicht):** `SECRET_KEY_BASE`, `AR_ENCRYPTION_PRIMARY_KEY`,
`AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT`, `JWT_SECRET`.

**SQL Server (optional, siehe [18_sql_server.md](18_sql_server.md)):**
`DB_ADAPTER` (`sqlite` | `sqlserver`), `SQL_SERVER`, `SQL_PORT`, `SQL_USER`,
`SQL_PASSWORD`, `SQL_DATABASE`, `SQL_LOG_DATABASE`, `SQL_USERS_DATABASE`,
`SQL_ENCRYPT`, `SQL_TIMEOUT`. Die primäre Anwendungsdatenbank (`app_data`) sowie
`log` und `users` werden bei der Ersteinrichtung automatisch angelegt.

**Risiko-Zuschlag (kalibrierbar):** `RISK_SURCHARGE_MAX_PCT`,
`RISK_SURCHARGE_CRITICAL_BONUS_PCT`, `RISK_SURCHARGE_CRITICAL_CAP_PCT`,
`RISK_SURCHARGE_SINGLE_SOURCE_BONUS_PCT`, `RISK_SURCHARGE_SINGLE_SOURCE_CAP_PCT`.

**Benachrichtigung:** `RISK_NOTIFICATION_MIN_SEVERITY` (`low|medium|high|critical`).

**HTTP (ausgehend):** `RATE_LIMIT_RESPECT_RETRY_AFTER`, `HTTP_OPEN_TIMEOUT`,
`HTTP_READ_TIMEOUT`, `HTTP_MAX_RETRIES`, `HTTP_USER_AGENT`.

**Provider-Keys:** z. B. `FREIGHTOS_API_KEY`, `FRED_API_KEY`, `OPENWEATHER_API_KEY`,
`RELIEFWEB_APPNAME`, `EU_TARIC_BASE_URL`, sowie alle `*_API_KEY`/`*_API_SECRET` der
Paid-Adapter.

## Provider-Konfiguration & Präzedenz

Jede Quelle kann konfiguriert werden. Auflösungsreihenfolge (höchste zuerst):

1. **Pro-Projekt** `risk_provider_configs` (`config`-JSON + verschlüsselter `api_key`)
2. **Umgebungsvariablen** (`.env` / Prozessumgebung)
3. **Adapter-/Katalog-Defaults** (`risk_providers.yml` + Provider-Klasse)

Der Katalog (`risk_providers.yml`) deklariert je Quelle: `key`, `name`, `tier`
(`free|paid|internal`), `category`, `class`, `docsUrl`, `requiresApiKey`, `envKeys`,
`cacheTtlMinutes`, `rateLimitPerMinute`, `dimensions`, `costNote`.

## Hintergrundjob-Adapter (`JobAdapter`)

- Linux/macOS (fork verfügbar): `solid_queue` (durable, Scheduler).
- Windows (kein fork): `async` (In-Prozess-Threadpool; Jobs gehen bei Neustart
  verloren, kein Scheduler).
- Tests: `:test`-Adapter (deterministisch).

## Datenbank-Strategie

SQLite überall; `storage/<env>.sqlite3` (App), `_cache.sqlite3` (Solid Cache),
`_queue.sqlite3` (Solid Queue). WAL + `busy_timeout` verhindern Lock-Konflikte
zwischen Puma und Worker.
