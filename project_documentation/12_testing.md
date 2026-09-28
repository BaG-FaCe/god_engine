# 12 — Tests & Qualitätssicherung

## Backend (RSpec)

**Ausführung:**
```bash
cd api
bin/rails spec          # gesamte Suite
bin/rails smoke:api     # End-to-End gegen laufende API (SMOKE_BASE_URL)
```

**Struktur (`api/spec/`):**

| Ordner | Inhalt |
|---|---|
| `spec/models` / `spec/factories` | Modell-Tests + Factory-Bot-Factories (`core.rb`, `calculator.rb`, `risk.rb`) |
| `spec/domain/` | `risk_scoring_spec`, `event_draft_spec`, `notification_policy_spec`, `provider_context_spec` |
| `spec/application/` | `aggregate_product_risk_spec`, `notify_risk_alert_spec`, `refresh_material_risk_spec` |
| `spec/contracts/` | `risk_provider_contract_spec` (Contract-Harness) |
| `spec/requests/` | `projects_spec`, `material_risk_spec`, `risk_notifications_spec`, `risk_events_spec`, `risk_providers_spec` |
| `spec/jobs/` | `poll_disaster_alerts_job_spec`, `refresh_sanctions_list_job_spec`, `sync_freight_index_job_spec`, `refresh_risk_assessments_job_spec`, `purge_expired_assessments_job_spec`, `recurring_schedule_spec` |
| `spec/infrastructure/` | `poll_schedule_spec` |
| `spec/integration/` | `solid_infrastructure_spec` |

**Support:** `webmock.rb`, `vcr.rb`, `cache.rb`, `factory_bot.rb`,
`risk_provider_contract.rb` (Contract-Harness), `request_helpers.rb`.

**Fixtures:** `spec/fixtures/risk/*.json` (15 Provider-Antworten, z. B. GDACS, USGS,
Freightos, project44, …).

**Stand (laut `versioning.md`):** ~329 RSpec-Beispiele grün (Stand des letzten
dokumentierten Meilensteins).

## Frontend (Vitest + Playwright)

**Ausführung:**
```bash
cd web
npm run typecheck         # tsc -b --noEmit
npm run test              # Vitest (Unit-Tests)
npm run test:coverage     # Abdeckung
npm run build             # Production-Build
npm run test:e2e          # Playwright
```

**Unit-Tests:** `web/src/**/*.{test,spec}.{ts,tsx}` (z. B. `calculator-store.test.ts`,
`notification-store.test.ts`, `money.test.ts`, `RiskAmpel.test.tsx`).
Stand: ~13 Vitest-Tests grün (laut `versioning.md`).

## Smoke-Test (`api/lib/tasks/smoke.rake`)

End-to-End-Checks gegen eine laufende API (via `SMOKE_BASE_URL`), inkl. Token-Handling.

## Qualitätswerkzeuge

- **RuboCop** (`rubocop-rails-omakase`) — Linting Backend.
- **Brakeman** — Sicherheits-Scan (Rails).
- **SimpleCov** — Backend-Abdeckung.
- **ESLint** (`npm run lint`) — Linting Frontend.
- **Vitest Coverage (v8)** — Frontend-Abdeckung.
- **Contract-Tests** — jeder Provider gegen `RiskDataProvider`-Vertrag geprüft
  (via `spec/support/risk_provider_contract.rb` + Fixtures).
