# 05 — Klassen, Komponenten & Controller

## ActiveRecord-Modelle (`app/models/`)

Alle Modelle erben von `ApplicationRecord`, der String-UUID-Primärschlüssel
(`SecureRandom.uuid`) setzt.

| Modell | Zweck / Besonderheiten |
|---|---|
| `ApplicationRecord` | Basisklasse; UUID-PK via `before_validation :ensure_uuid` |
| `User` | Rollen `admin/manager/viewer`; `has_secure_password`; `can_write?` |
| `AuditLog` | Audit-Trail (Action, User, IP, User-Agent) → `AuditLogChange` + `AuditLogMetadatum` |
| `Project` | Wurzel-Aggregat des Kalkulators; Status `draft/active/archived` |
| `Supplier` | Lieferant; Sanktionsstatus (`sanctions_*`) |
| `Material` | Stücklistenposition + denormalisiertes Risiko (`risk_score/risk_level`) |
| `MaterialRiskProfile` | Lieferrisiko-Stammdaten (Herkunft, HS-Code, Route, manuelle Ampel) |
| `AlternativeSupplier` | Alternativlieferanten je Material |
| `MaterialDocument` | Dokumente (URL, Content-Type, Größe) |
| `MonthlyCost` | wiederkehrende Monatskosten |
| `SalesForecast` | Verkaufsprognose vs. Realität je Periode |
| `LaborCost` | Arbeitskosten (Stunden × Stundensatz) |
| `FixedCost` | Fixkosten mit Verrechnungsbasis |
| `OverheadRule` | Gemeinkosten-Zuschläge; `DEFAULT_RULES`; `auto_from_risk` |
| `CostTemplate` | wiederverwendbare Kosten-Vorlagen → `CostTemplateItem` |
| `PricingScenario` | benanntes Preisszenario → `PricingScenarioResult` (1:1) + `PricingScenarioWarning` |
| `RiskAssessment` | append-only Provider-Ergebnis je Material → `RiskAssessmentDimension` + `RiskAssessmentDataSource` |
| `RiskEvent` | Frühwarnsignal; `(source, source_event_id)`-Unique-Index → `RiskEventMetadatum` |
| `RiskNotification` | In-App-Benachrichtigung (Lifecycle read/acknowledge/dismiss) |
| `RiskProviderConfig` | Projekt-Provider-Konfiguration; `encrypts :api_key` |
| `RiskProviderRun` | Lauf-Protokoll eines Provider-Polls (Dauer, Fehler, Zähler) |
| `RiskScoreSnapshot` | täglicher Risikoverlauf (Timeline) |
| `SanctionsEntry` | lokale Sanktionsliste (normalisierter Name) → `SanctionsEntryAlias` + `SanctionsEntryIdentifier` |

## Controller (`app/controllers/api/v1/`)

| Controller | Endpunkte (Auszug) |
|---|---|
| `ApplicationController` | Basis: JSON-Format, Bearer-Auth, Fehler-Envelope, Pagination |
| `AuthController` | `POST auth/login`, `GET auth/me` |
| `HealthController` | `GET health` |
| `ProjectsController` | CRUD + `duplicate/archive/restore/export/import` |
| `MaterialsController` | CRUD + `lead_time_analysis` |
| `CostBlocksController` | parametrisiert für monthly_costs/sales_forecasts/labor_costs/fixed_costs/overhead_rules |
| `SuppliersController` | CRUD (unter Projekten) |
| `PricingController` | `GET pricing`, `POST pricing/optimize` |
| `DashboardsController` | `GET dashboard` (KPIs + Charts + Risiko-Rollup) |
| `MaterialRiskController` | `risk_assessment` (show/manual/refresh), `risk_events` |
| `RiskProvidersController` | `index`, `configure`, `probe` |
| `MaterialCardsController` | `GET materials/:id/card` |
| `RiskEventsController` | `index/show/update` (Acknowledge) |
| `RiskSummariesController` | `GET projects/:id/risk_summary` |
| `PricingScenariosController` | CRUD + `activate/optimize` |
| `SalesForecastsController` | `analysis` |
| `CostTemplatesController` | CRUD + `apply` |
| `JobsController` | `GET jobs/:id`, `GET jobs` |
| `RiskNotificationsController` | `index/show` + `acknowledge/dismiss/read/read_all` |

## Hintergrundjobs (`app/jobs/`)

| Job | Queue | Zweck |
|---|---|---|
| `RefreshMaterialRiskJob` | — | Ein Material aktualisieren |
| `RefreshRiskAssessmentsJob` | `risk_polling` | Bulk-Refresh veralteter Materialien (12 h) |
| `PollDisasterAlertsJob` | `risk_polling` | GDACS/USGS/Open-Meteo/ReliefWeb-Events (30 min) |
| `SyncFreightIndexJob` | `risk_polling` | Frachtraten-Indizes (6 h) |
| `RefreshSanctionsListJob` | `risk_polling` | Sanktionslisten-Abgleich (täglich 4 Uhr) |
| `PurgeExpiredAssessmentsJob` | `maintenance` | abgelaufene Bewertungen aufräumen (3 Uhr) |
| `RecomputeRiskSurchargesJob` | `maintenance` | `auto_from_risk`-Zuschläge neu rechnen (5 Uhr) |

Zeitpläne → `config/recurring.yml`.

## Frontend-Komponenten (Auszug)

- `App` / `AppShell` / `HomePage` / `ModuleHost` — Shell & Routing.
- `apps/calculator/index.tsx` — Projektauswahl, Tabs, Dialoge (Neu/Archiv/Löschen).
- `apps/calculator/tabs/*` — `MaterialTab`, `MonthlyCostsTab`, `FixedCostsTab`,
  `PricingTab`, `DashboardTab`.
- `apps/calculator/components/*` — `NotificationBell`, `MaterialRiskPanel`.
- `apps/calculator/store/*` — `calculator-store.ts`, `notification-store.ts` (Zustand).
- `apps/calculator/api/*` — TanStack-Query-Hooks + Endpunkt-Wrapper.
- `shared/components/*` — `RiskAmpel`, `ErrorBoundary`, `LoadingState`, `EmptyState`, `QueryError`.
