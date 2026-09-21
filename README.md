# God Engine — Verkaufspreis-Kalkulationsplattform

Modulare Plattform zur Produkt- und Verkaufspreiskalkulation mit integriertem
**Lieferrisiko-Frühwarnsystem (Supply Chain Risk Intelligence)**.

Die Plattform ist als **modularer Monolith** aufgebaut: Jeder Anwendungsbereich ist
ein eigenständiges Modul mit eigener API, eigener UI, eigener Geschäftslogik und
eigenen Tests. Module werden erst geladen, wenn sie geöffnet werden.

> **Status:** Der `Produktkalkulator` ist vollständig implementiert (Tabs 1–5 inkl.
> Lieferrisiko-Ampel, Preiskalkulation, Preisoptimierung und Dashboard).
> Alle übrigen Module (`Materialmanager`, `Produktionsplaner`, `Lagerverwaltung`,
> `Reporting`, `Lieferrisiko-Monitor`) sind als Platzhalter angelegt.

---

## Highlights

| Bereich | Umsetzung |
|---|---|
| Backend | Ruby 3.x · Rails 8 (API-only) · **SQLite** · **Solid Queue** · **Solid Cache** |
| Frontend | React 19 · TypeScript · Vite · Material UI · TanStack Query · Zustand · Recharts |
| Betrieb | **Kein Docker, kein PostgreSQL, kein Redis-Prozess** — `bundle install` + `rails db:setup` + `rails server` |
| Architektur | Modulare Monolithen-Struktur mit Bounded Contexts (DDD), Ports & Adapters, SOLID |
| Risiko | Provider-Abstraktion `RiskDataProvider` (Open Data **und** kommerzielle SCRM-Provider), Ampel 0–33 / 34–66 / 67–100 |

---

## Warum kein Docker / PostgreSQL / Redis?

Rails 8 bringt für alles, was früher Zusatzinfrastruktur erforderte, DB-gestützte
Adapter mit. Dadurch reduziert sich die Installation auf drei Befehle und der
Ressourcenverbrauch bleibt minimal:

```
storage/<env>.sqlite3        → Anwendungsdaten
storage/<env>_cache.sqlite3  → Solid Cache (statt Redis)
storage/<env>_queue.sqlite3  → Solid Queue (statt Sidekiq/Redis)
```

Deshalb ist die Konfiguration in `api/config/database.yml` bewusst auf getrennte
Dateien pro Concern ausgelegt (WAL-Modus + `busy_timeout`), damit sich Web- und
Worker-Prozess nicht gegenseitig blockieren.

---

## Schnellstart (Windows, empfohlen)

Voraussetzungen: Ruby 3.x, Bundler, Node.js 20+.

```powershell
# Alles in einem Schritt: Abhängigkeiten, DB-Import, beide Server, Browser
.\start-dev.bat
```

oder mit Parametern:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-dev.ps1                 # Standard: API :3000, UI :5173
powershell -ExecutionPolicy Bypass -File .\start-dev.ps1 -SkipInstall   # schneller Neustart
powershell -ExecutionPolicy Bypass -File .\start-dev.ps1 -ApiPort 3001 -WebPort 5174 -NoBrowser
.\stop-dev.ps1                                                          # beide Prozesse sauber beenden
```

| Dienst | URL |
|---|---|
| SPA | http://127.0.0.1:5173 |
| API | http://127.0.0.1:3000/api/v1 |
| Health | http://127.0.0.1:3000/up |

**Seed-Login:** `admin@god-engine.local` / `GodEngine-Admin-123`
(Schreibzugriffe sind JWT-geschützt; Lesen ist für die Kalkulationsansichten offen.)

### Manuell (macOS/Linux/Windows)

```bash
cd api
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server                 # http://127.0.0.1:3000

cd ../web
npm install
npm run dev                      # http://127.0.0.1:5173 (Proxy /api → :3000)
```

---

## Projektstruktur

```text
god_engine/
├── api/                                  # Rails 8 API-only Backend (modularer Monolith)
│   ├── app/
│   │   ├── controllers/api/v1/           # REST-Schicht (dünn: nur HTTP + Params)
│   │   ├── jobs/supply_chain_risk/       # Solid-Queue-Jobs (Refresh, Alerts, Sanktionen …)
│   │   ├── models/                       # ActiveRecord (Persistenz)
│   │   └── modules/                      # Bounded Contexts
│   │       ├── calculator/               # Domain: PricingCalculator, PriceOptimizer,
│   │       │                             #         RiskSurchargePolicy, LeadTimeAnalyzer
│   │       ├── supply_chain_risk/        # Domain: RiskDataProvider, AssessmentDraft, …
│   │       │                             # Infrastructure: Provider-Registry + Adapter
│   │       └── shared/                   # HTTP-Client, Rate-Limiter, Audit, Job-Adapter
│   ├── config/                           # risk_providers.yml, cache.yml, queue.yml, recurring.yml
│   ├── db/migrate/                       # Schema inkl. Lieferrisiko-Entitäten
│   └── lib/tasks/smoke.rake              # End-to-End-Smoke-Test gegen laufende API
│
├── web/                                  # React 19 SPA
│   └── src/
│       ├── apps/                         # ein Ordner pro Modul (lazy geladen)
│       │   ├── calculator/               # aktiv: api/ · store/ · tabs/ (1–5)
│       │   ├── material-management/      # Coming Soon
│       │   ├── production-planner/       # Coming Soon
│       │   ├── inventory/                # Coming Soon
│       │   ├── reporting/                # Coming Soon
│       │   └── supply-chain-risk/        # Coming Soon
│       ├── shared/                       # api-client, types, components (RiskAmpel …), hooks, lib
│       ├── shell/AppShell.tsx            # Navigation, Login, Layout
│       └── shared/module-registry.ts     # zentrale Modul-Registry (Lazy Loading)
│
├── start-dev.ps1 / start-dev.bat / stop-dev.ps1
└── .gitignore
```

### Modularitätsregeln

1. **Ein Modul = ein Ordner** in `web/src/apps/<modul>/` **und** `api/app/modules/<modul>/`.
2. Module werden über `module-registry.ts` **lazy** importiert → nicht geöffnete Module
   werden weder heruntergeladen noch abgefragt.
3. Modulübergreifende Fähigkeiten liegen ausschließlich in `shared/`.
4. Der `supply-chain-risk`-Context ist bewusst entkoppelt (eigene Domain, eigene
   Provider-Registry, keine Kenntnis vom Kalkulator) und damit später als eigener
   Service extrahierbar.

---

## Produktkalkulator — Funktionsumfang

**Tab 1 · Materialkosten** — Materialstammdaten, Lieferanten, Preise netto/brutto,
Menge, Lieferzeit, Lagerort, Produktbild, Dokumente; dazu die optionalen
**Lieferrisiko-Felder** je Material (Herkunftsland, HS-Code, Versandroute,
Transportmodus, Single-Source, historische Verzögerungen, Frachtkostentrend,
manuelle Ampel + Notiz). Zusätzlich: Lieferzeit-Analyse (Ø geplant, längste,
risikogewichtet, Abweichung).

**Tab 2 · Monatliche Kosten** — wiederkehrende Kosten (Miete, Strom, Marketing …),
Verkaufsprognose vs. Realität inkl. Abweichung, sowie anwendbare Kosten-Vorlagen.

**Tab 3 · Fix- & Gemeinkosten** — Arbeitskosten (Stunden × Stundensatz),
Fixkosten mit Verrechnungsbasis (pro Einheit / Monat / Charge) und
Gemeinkosten-Zuschläge inkl. **risikogekoppeltem Aufschlagsvorschlag**.

**Tab 4 · Preiskalkulation** — Zusammenführung aller Kostenblöcke,
Gesamtkosten netto/brutto, Kosten pro Einheit, aggregiertes Produktrisiko,
**manuelle Preisoptimierung** (Zielpreis brutto/netto → Gewinn, Marge,
Deckungsbeitrag, Umsatz, Monatsgewinn, Break-Even) und speicherbare Preisszenarien.

**Tab 5 · Dashboard** — KPIs (Material-, Monats-, Fix-, Arbeitskosten, Gewinn,
Umsatz, Break-Even, kritische Lieferrisiken, Ø-Risikoscore) und Diagramme:
Kostenverteilung, Gewinnentwicklung, Prognose vs. Realität,
**Lieferrisiko-Verteilung** und **Risiko-Timeline** inkl. Risiko-Ereignissen.


---

## Lieferrisiko-Management (Supply Chain Risk Intelligence)

### Kategorien von Datenquellen

* **Kategorie A — Open Data (Basisabsicherung, kostenlos):** World Bank LPI,
  UN Comtrade, GDACS, ReliefWeb/USGS, NOAA/Open-Meteo, EZB-Wechselkurse,
  EU-/OFAC-Sanktionslisten, EU TARIC (HS-Codes), Hafenauslastungs-Indizes,
  Freightos Baltic Index. Liefern Kontext- und Makrorisiken.
* **Kategorie B — kommerzielle SCRM-/Visibility-APIs (optional):** project44,
  FourKites, Everstream, Resilinc, riskmethods (Sphera), Interos,
  Dun & Bradstreet, Moody's/S&P, Flexport, Maersk, DHL/UPS/FedEx, Descartes,
  Overhaul. Werden als pluggable Provider hinter derselben Schnittstelle integriert.

### Provider-Abstraktion

Alle Quellen implementieren dieselbe Schnittstelle und liefern ein normalisiertes
Risiko-Objekt (Score 0–100, Level, Dimensionen, Begründung, Quelle, Zeitstempel):

```text
SupplyChainRiskService
        │
        ▼
 RiskDataProvider (Interface)
   ├── FreeDataProvider        # Open-Data-Adapter (LPI, GDACS, Sanktionen, Kurse …)
   ├── PaidProvider::*         # project44, FourKites, Resilinc, Interos, D&B, …
   ├── HeuristicProvider       # interne Heuristik aus den Stammdaten
   └── ManualProvider          # manuelle Einschätzung (immer verfügbar)
```

* Jeder Adapter wird in `config/risk_providers.yml` deklariert (Tier, Kategorie,
  Rate-Limit, Cache-TTL, benötigte API-Keys).
* API-Keys werden **verschlüsselt** je Projekt gespeichert
  (`RiskProviderConfig`, `ActiveRecord::Encryption`).
* Rohantworten werden in **Solid Cache** mit TTL zwischengespeichert, um Rate-Limits
  und Kosten zu schonen; ausgehende Aufrufe laufen über einen Rate-Limiter.
* Automatische und manuelle Risikodaten bleiben getrennt nachvollziehbar
  (`risk_assessments.origin`) — Ampel: **0–33 grün · 34–66 gelb · 67–100 rot**.

### Hintergrundjobs (Solid Queue)

| Job | Zweck |
|---|---|
| `RefreshMaterialRiskJob` | Risikoaktualisierung für ein Material |
| `RefreshRiskAssessmentsJob` | periodischer Refresh je Provider-Intervall |
| `PollDisasterAlertsJob` | GDACS/USGS/NOAA-Alarme für Herkunftsländer |
| `SyncFreightIndexJob` | Frachtraten-Indizes für die Trendanzeige |
| `RefreshSanctionsListJob` | Abgleich der Lieferanten gegen Sanktionslisten |
| `PurgeExpiredAssessmentsJob` | Aufräumen abgelaufener Bewertungen |
| `RecomputeRiskSurchargesJob` | Neuberechnung risikogekoppelter Aufschläge |

Zeitpläne: `api/config/recurring.yml`.

### Datenmodell (Auszug)

```text
materials               id, project_id, name, type, supplier_id, article_number, …
material_risk_profiles  origin_country, hs_code, shipping_route, transport_mode,
                        is_single_source, historical_delay_*, last_disruption_*,
                        freight_cost_trend, manual_risk_level, manual_risk_note
suppliers               id, name, country, rating, is_single_source, sanctions_*
risk_assessments        id, material_id, provider_key, risk_score, risk_level,
                        dimension_scores (json), lead_time_variance_days, reason,
                        origin, fetched_at, expires_at
risk_events             id, material_id, event_type, severity, title, source, occurred_at
risk_score_snapshots    täglicher Verlauf des aggregierten Scores (Timeline)
risk_provider_configs   id, project_id, provider_key, api_key_encrypted, enabled,
                        poll_interval_minutes, priority
```


---

## API (Auszug)

```text
POST   /api/v1/auth/login                              # JWT
GET    /api/v1/projects                                # Liste (paginiert)
POST   /api/v1/projects/:id/duplicate|archive|restore
GET    /api/v1/projects/:id/export?format=json|csv     # JSON-Dokument / CSV
POST   /api/v1/projects/:id/import                     # Projekt-JSON laden

GET    /api/v1/projects/:id/materials                  # Materialien (inkl. riskProfile)
GET    /api/v1/projects/:id/materials/lead_time_analysis
GET    /api/v1/projects/:id/monthly_costs|labor_costs|fixed_costs|overhead_rules
GET    /api/v1/projects/:id/sales_forecasts/analysis
GET    /api/v1/projects/:id/pricing                    # Gesamtkalkulation
POST   /api/v1/projects/:id/pricing/optimize           # Zielpreis-Optimierung
GET    /api/v1/projects/:id/dashboard                  # KPIs + Charts + Risiko-Rollup
GET    /api/v1/projects/:id/risk_summary
GET    /api/v1/projects/:id/risk_events

GET    /api/v1/materials/:id/card                      # Materialkarte inkl. Ampel
GET    /api/v1/materials/:id/risk_assessment
POST   /api/v1/materials/:id/risk_assessment/manual
POST   /api/v1/materials/:id/risk_assessment/refresh   # startet Hintergrundjob
GET    /api/v1/materials/:id/risk_events

GET    /api/v1/risk_providers                          # verfügbare Provider + Status
POST   /api/v1/risk_providers/:key/configure           # API-Key/Intervall setzen
POST   /api/v1/risk_providers/:key/probe               # Verbindung testen
GET    /api/v1/jobs/:id                                # Job-Status (Polling)
```

Alle Fehler folgen demselben Envelope:

```json
{ "error": { "code": "validation_error", "message": "…", "details": { "name": ["…"] } } }
```

Monetäre Werte werden durchgängig als **ganzzahlige Cent** übertragen; die API
spricht camelCase, die Datenbank snake_case.

---

## JSON-Projektdokument (Export/Import)

Projekte lassen sich als strukturierte JSON-Datei sichern und wieder einlesen.
Implementierung: `api/app/modules/calculator/application/project_document.rb`,
TypeScript-Spiegel: `web/src/shared/api/types/document.ts`.

```json
{
  "schemaVersion": "1.0",
  "projectName": "Produkt A",
  "taxRate": 19,
  "materials": [
    {
      "name": "Aluminium Profil 2020",
      "unitPriceCents": 450,
      "leadTime": { "value": 14, "unit": "days" },
      "supplyChainRisk": {
        "originCountry": "DE",
        "shippingRoute": "Rotterdam-Duisburg",
        "riskScore": 23,
        "riskLevel": "low",
        "leadTimeVarianceDays": 2,
        "lastCheckedAt": "2026-09-15T08:00:00Z",
        "dataSources": ["manual", "customs_hs_lookup", "port_congestion_index"]
      }
    }
  ],
  "monthlyCosts": [],
  "fixedCosts": [],
  "pricing": {}
}
```

---

## Tests & Qualitätssicherung

```bash
# Backend
cd api
bin/rails smoke:api            # End-to-End-Checks gegen laufende API (SMOKE_BASE_URL)

# Frontend
cd web
npm run typecheck              # tsc --noEmit
npm run test                   # Vitest (Unit-Tests)
npm run test:coverage
npm run build                  # Production-Build inkl. Code-Splitting
```

---

## Sicherheit

* JWT-Authentifizierung (`Authorization: Bearer …`), Rollen `admin`/`manager`/`viewer`
* `require_write!` auf allen schreibenden Endpunkten
* Input-Validierung über ActiveRecord-Validierungen + starke Parameter
* Audit-Logs (`audit_logs`) für Create/Update/Delete/Export/Import/Login
* Verschlüsselte Speicherung der API-Keys externer Risiko-Provider
* Rate-Limiting ausgehender Provider-Aufrufe
* Getrennte Kennzeichnung automatischer vs. manueller Risikodaten

---

## Nützliche Kommandos

```bash
cd api
bin/rails db:prepare           # Schema anlegen/migrieren
bin/rails db:seed              # Demo-Projekt inkl. Risikodaten
bin/jobs                       # Solid-Queue-Worker (Windows: BACKGROUND_JOB_ADAPTER=async)
bin/rails routes | grep api    # Route-Übersicht
```

---

## Lizenz

Siehe [LICENSE](LICENSE).
