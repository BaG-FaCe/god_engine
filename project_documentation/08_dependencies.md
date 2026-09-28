# 08 — Dependencies

## Backend (`api/Gemfile`)

| Gem | Version | Zweck |
|---|---|---|
| rails | ~> 8.0 | Framework (API-only) |
| sqlite3 | ~> 2.6 | Datenbank |
| puma | >= 6.4 | App-Server |
| solid_cache | ~> 1.0 | DB-basiertes Caching (statt Redis) |
| solid_queue | ~> 1.0 | DB-basierte Jobs (statt Sidekiq/Redis) |
| bcrypt | ~> 3.1 | Passwort-Hashing |
| jwt | ~> 3.1 | JSON Web Token |
| rack-attack | ~> 6.7 | eingehendes Rate-Limiting / Brute-Force-Schutz |
| rack-cors | ~> 2.0 | CORS |
| faraday | ~> 2.12 | ausgehender HTTP-Client |
| faraday-follow_redirects | ~> 0.4 | Redirects |
| faraday-retry | ~> 2.3 | Retries mit Backoff |
| json_schemer | ~> 2.4 | Validierung externer Payloads/Import-Dokumente |
| caxlsx | ~> 4.1 | XLSX-Export |
| csv | ~> 3.3 | CSV-Export |
| prawn / prawn-table | ~> 2.5 / 0.2 | PDF-Export |
| json | ~> 2.9 | **gepinnt** (json 3.0 bricht `JSON.parse(str, opts)`) |
| bootsnap | — | Boot-Beschleunigung |
| tzinfo-data | — | Zeitzonen (Windows/JRuby) |

**development/test:** brakeman, debug, dotenv-rails, factory_bot_rails, faker,
rspec-rails, rubocop-rails-omakase, vcr, webmock.
**test:** simplecov.

## Frontend (`web/package.json`)

**dependencies:** `@emotion/react`, `@emotion/styled`, `@mui/icons-material`,
`@mui/material`, `@mui/x-date-pickers`, `@tanstack/react-query` (+ devtools),
`dayjs`, `react`, `react-dom`, `react-router-dom`, `recharts`, `zustand`.

**devDependencies:** `@playwright/test`, `@testing-library/*`, `@types/*`,
`@vitejs/plugin-react`, `@vitest/coverage-v8`, `eslint` (+plugins), `globals`,
`jsdom`, `typescript`, `typescript-eslint`, `vite`, `vitest`.

## Ruby-/Node-Versionen

- `api/.ruby-version`: Ruby 3.3+ (Gemfile verlangt `>= 3.3.0`).
- Frontend: Node.js 20+ (laut README).

## Versionshinweise

- `Gemfile.lock` und `package-lock.json` sind eingecheckt (reproduzierbare Builds).
- `json` wird bewusst auf 2.x gehalten (Kommentar in der Gemfile dokumentiert den
  Rails-8.1-/json-3.0-Konflikt).
