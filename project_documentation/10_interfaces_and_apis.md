# 10 — Schnittstellen & APIs

## REST-API (extern, JSON)

Basis-URL: `http://127.0.0.1:3000/api/v1`. Vollständige Routen in
`api/config/routes.rb`. Auszug:

```text
# Auth
POST /auth/login                      GET /auth/me
# Projekte
GET  /projects                        POST /projects
PATCH/DELETE /projects/:id
POST /projects/:id/duplicate|archive|restore
GET  /projects/:id/export?format=json|csv
POST /projects/:id/import
# Unterressourcen
GET/POST /projects/:id/materials … /suppliers … /monthly_costs … /sales_forecasts …
/labor_costs … /fixed_costs … /overhead_rules … /pricing_scenarios …
# Komposition
GET  /projects/:id/pricing            POST /projects/:id/pricing/optimize
GET  /projects/:id/dashboard          GET  /projects/:id/risk_summary
GET  /projects/:id/risk_events
# Material-Risiko
GET  /materials/:id/risk_assessment   POST /materials/:id/risk_assessment/manual
POST /materials/:id/risk_assessment/refresh
GET  /materials/:id/risk_events       GET  /materials/:id/card
# Provider
GET  /risk_providers                  POST /risk_providers/:key/configure
POST /risk_providers/:key/probe
# Benachrichtigungen (+ Alias /notifications)
GET  /risk_notifications              POST /risk_notifications/:id/acknowledge|dismiss
PATCH /risk_notifications/:id/read    POST /risk_notifications/read_all
# Jobs
GET  /jobs/:id                        GET  /jobs
# Health
GET  /api/v1/health                   GET  /up
```

## Konventionen

- **camelCase** im JSON, **snake_case** in der DB.
- **Cent** als Integer für Geldbeträge.
- **Fehler-Envelope:** `{ "error": { "code", "message", "details?" } }`.
- **Pagination:** `{ data, meta: { page, perPage, total, totalPages } }`.
- **Auth:** `Authorization: Bearer <JWT>` (SPA) bzw. `?token=` (Smoke-Tests).

## Interne Schnittstelle: `RiskDataProvider`

Der zentrale Vertrag, den jede Risikoquelle implementiert:

```ruby
class RiskDataProvider
  def self.descriptor; end                 # ProviderDescriptor (Metadaten)
  def assess(subject) -> AssessmentDraft|nil
  def events(since:) -> [EventDraft]       # Default []
  def probe -> { ok:, message:, latencyMs:, sampleScore: }
  def available? -> Boolean
end
```

- Provider sind **zustandslos pro Aufruf** und sollen bei erwarteten Upstream-
  Problemen `nil` zurückgeben (statt zu werfen).
- Tier ist nur Metadaten; die Berechnung gewichtet lediglich über `confidence`.

## Interne Schnittstelle: `AggregateProductRisk`

```ruby
AggregateProductRisk.call(project:)       # → Produkt-Risiko-Hash
AggregateProductRisk.material_view(material)  # → Materialkarten-View
```

Dies ist der einzige Weg, über den der Kalkulator Risikodaten liest.

## Provider-Katalog (komplett, 35 Quellen)

**Free / Open Data (14):** `world_bank_lpi`, `gdacs`, `usgs_earthquake`, `open_meteo`,
`ecb_fx`, `eu_sanctions`, `eu_taric`, `port_congestion`, `freightos_fbx`,
`fred_economic`, `openweather_alerts`, `reliefweb`, `un_comtrade`, `ofac_sdn`.

**Paid (19):** `project44`, `fourkites`, `maersk`, `flexport`, `shippeo`,
`ocean_insights`, `vizion` (Visibility/Tracking) · `everstream`, `resilinc`,
`riskmethods`, `interos`, `prewave` (Risk Intelligence) · `dun_bradstreet`, `moodys`,
`rapid_ratings` (Financial) · `descartes`, `amber_road`, `oneclear` (Customs).

**Internal (2):** `heuristic` (interne Heuristik), `manual` (manuelle Ampel).

## Frontend-HTTP-Client (`shared/api/http.ts`)

- Basis-URL: `VITE_API_BASE_URL` oder `/api/v1` (Dev-Proxy).
- Token aus `localStorage` (`god-engine.auth.token`).
- Timeout via `AbortController`, Fehler-Mapping auf `AppError`, binäre Downloads.
