# 04 — Module (Bounded Contexts)

## Übersicht

| Modul | Ort (Backend) | Ort (Frontend) | Status | Verantwortung |
|---|---|---|---|---|
| calculator | `app/modules/calculator` | `apps/calculator` | aktiv | Preiskalkulation |
| supply_chain_risk | `app/modules/supply_chain_risk` | `apps/supply-chain-risk` (Platzhalter) | aktiv (Backend) | Lieferrisiko |
| shared | `app/modules/shared` | `src/shared` | aktiv | Querschnitt |
| auth | `app/modules/auth` | (Shell) | aktiv | JWT |
| material-management | — | `apps/material-management` | Coming Soon | Materialstamm |
| production-planner | — | `apps/production-planner` | Coming Soon | Fertigungsplanung |
| inventory | — | `apps/inventory` | Coming Soon | Lager |
| reporting | — | `apps/reporting` | Coming Soon | Auswertungen |

## `calculator` (Produktkalkulator)

**Domain:**
- `PricingCalculator` — baut aus `CostBasis` die Gesamtkalkulation (Material, Labor,
  Fix, Monat, Gemeinkosten, Risikozuschlag, Steuer) auf. Pro-Stück-Werte sind
  maßgeblich; Batch-/Monatswerte werden daraus abgeleitet.
- `PriceOptimizer` — beantwortet „Was passiert, wenn wir zu Preis X verkaufen?“
  (Gewinn, Marge, Deckungsbeitrag, Umsatz, Monatsgewinn, Break-Even).
- `RiskSurchargePolicy` — bildet den aggregierten Risikoscore auf einen Zuschlag ab.
- `LeadTimeAnalyzer` — Lieferzeitanalyse (Ø, längste, risikogewichtet, Buckets).
- `CostBasis` / `CostBreakdown` — Value Objects (`Inputs`, `MaterialLine`, …).

**Application:**
- `BuildCostBasis` — lädt das Projekt-Aggregat in `CostBasis` (Ports & Adapters).
- `Serializers`, `MaterialSerializer` — camelCase-REST-Vertrag.
- `DuplicateProject`, `ProjectDocument` (JSON-Import/Export), `ProjectCsv`,
  `ApplyCostTemplate`.

## `supply_chain_risk` (Lieferrisiko)

**Domain:**
- `RiskDataProvider` — der einzige Vertrag, den jede Quelle erfüllen muss
  (`assess(subject) → AssessmentDraft`, `events`, `probe`, `available?`).
- `AssessmentDraft` — normalisiertes, unpersistiertes Bewertungsobjekt.
- `EventDraft` — normalisiertes Frühwarnsignal (idempotente Ingestion).
- `ProviderDescriptor` — statische Metadaten einer Quelle.
- `ProviderContext` — injizierte Außenwelt (HTTP, Cache, Logger, Config, Clock).
- `Subject` — die „Frage“ an einen Provider für ein Material.
- `NotificationPolicy` — entscheidet, ob benachrichtigt wird.

**Application:**
- `AggregateProductRisk` — aggregiert Material-Risiken zu Produkt-/Material-Views.
- `RefreshMaterialRisk` — führt aktive Provider für ein Material aus.
- `NotifyRiskAlert` — In-App-Benachrichtigungs-Fan-out (idempotent).

**Infrastructure:**
- `ProviderCatalogue` — lädt `config/risk_providers.yml`.
- `ProviderRegistry` — vereint Katalog + Projekt-Konfiguration, Priorisierung.
- `PollSchedule` — entscheidet, welcher Provider wann gepollt wird.
- `providers/internal` → `ManualProvider`, `HeuristicProvider`.
- `providers/free_data` → 14 Open-Data-Adapter.
- `providers/paid_data` → `BaseAdapter` + 19 SCRM-Adapter.

## `shared` (Querschnitt)

- `Money` — unveränderlicher Geldbetrag in **ganzen Cent** (kaufmännische Rundung).
- `Http::JsonClient` — einziger ausgehender HTTP-Client (Timeouts, Retries,
  Rate-Limits, Caching, Fehler-Normalisierung).
- `Http::RateLimiter` — Fixed-Window-Zähler je Provider (pro Minute).
- `Audit::Recorder` — zentrale Audit-Trail-Schreibung.
- `Jobs::JobAdapter` — plattformabhängige Wahl Solid Queue / async / inline / test.
- `Jobs::JobStatus` — einheitliche Job-Status-Abfrage.

## `auth` (Authentifizierung)

- `Session` (Modell `app/models/session.rb`) — SQL-gestützte, persistente Session.
  `Session.issue!` stellt das Token beim Login aus (nur der SHA-256-Hash wird
  gespeichert), `Session.authenticate` validiert es. Kein JWT mehr.

## Frontend-Module

- `src/apps/calculator` — aktives Modul (`index.tsx`, `api/*`, `store/*`, `tabs/*`,
  `components/*`).
- Übrige `src/apps/*` — `coming-soon.tsx`-Platzhalter.
- `src/shared` — API-Client, Typen, Komponenten, Hooks, Lib (modulübergreifend).
- `src/shell/AppShell.tsx` — Navigation, Login, Layout.
- `src/shared/module-registry.ts` — zentrale Modul-Registry.

Detailbeschreibungen → [modules/](modules/README.md).
