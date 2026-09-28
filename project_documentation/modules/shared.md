# Modul: `shared`

## Rolle

Querschnitts-Infrastruktur, die von beiden Fachkontexten (`calculator`,
`supply_chain_risk`) genutzt wird.

## Dateien

```
app/modules/shared/
├── domain/
│   └── money.rb
└── infrastructure/
    ├── http/
    │   ├── json_client.rb
    │   └── rate_limiter.rb
    ├── audit/
    │   └── recorder.rb
    └── jobs/
        ├── job_adapter.rb
        └── job_status.rb
```

## `Money`

- Unveränderlicher Geldbetrag als **ganze Cent**.
- `from`, `to_cents`, `percentage_of`, `allocate` (Größte-Reste-Verfahren),
  Operatoren (`+ - * / <=>`), kaufmännische Rundung (`:half_up`).

## `Http::JsonClient`

- Einziger ausgehender HTTP-Client (Faraday).
- Bündelt: Timeouts, Retries (exponentieller Backoff, idempotente Methoden),
  Rate-Limits, Caching.
- Fehler-Normalisierung auf fünf Typen: `Error`, `Timeout`, `Unauthorized`,
  `RateLimited`, `Unavailable`, `BadRequest`.
- Credential-Redaktion in Logs (`redact`).

## `Http::RateLimiter`

- Fixed-Window-Zähler (60 s) je Provider-Key, im gemeinsamen Cache (Solid Cache)
  → gilt prozessübergreifend.
- `acquire!` blockiert bis zum nächsten Fenster; `used`/`remaining` für Monitoring.

## `Audit::Recorder`

- Zentrale Schreibung von `AuditLog`-Zeilen.
- Helfer: `record_change`, `record_export`, `record_import`, `record_provider_config`,
  `record_refresh`.
- Fehler werden geloggt, brechen aber nie die Business-Transaktion.

## `Jobs::JobAdapter`

- Plattformabhängige Active-Job-Adapter-Wahl:
  `solid_queue` (durable, Scheduler) | `async` (Windows) | `inline` | `test`.
- `fork_available?` erkennt Windows; `install!` setzt den Adapter beim Boot.

## `Jobs::JobStatus`

- Einheitliche Status-Abfrage (`pending/scheduled/running/finished/failed`).
- Bei `async` (nicht queryable) → `status: "unknown"`, SPA fällt auf Refetch zurück.
