# 03 — Verzeichnisstruktur

> Es werden nur **relevante** Dateien/Ordner gezeigt. Generierte/ausgelagerte
> Verzeichnisse (`tmp/`, `log/`, `storage/`, `node_modules/`, `.git/`, `dist/`,
> Bootsnap-Caches) sind ausgelassen.

```text
god_engine/
├── api/                                # Rails 8 API-only Backend
│   ├── app/
│   │   ├── controllers/api/v1/         # 21 REST-Controller
│   │   ├── jobs/                       # BaseJob + 7 Hintergrundjobs
│   │   ├── models/                     # 22 ActiveRecord-Modelle
│   │   └── modules/                    # Bounded Contexts
│   │       ├── auth/                   # json_web_token.rb (JWT)
│   │       ├── calculator/
│   │       │   ├── domain/             # pricing_calculator, price_optimizer, …
│   │       │   └── application/        # build_cost_basis, serializers, …
│   │       ├── supply_chain_risk/
│   │       │   ├── domain/             # risk_data_provider, assessment_draft, …
│   │       │   ├── application/        # aggregate_product_risk, refresh_material_risk, …
│   │       │   └── infrastructure/
│   │       │       ├── provider_catalogue.rb / provider_registry.rb / poll_schedule.rb
│   │       │       └── providers/
│   │       │           ├── internal/   # manual_provider, heuristic_provider
│   │       │           ├── free_data/  # 14 Open-Data-Adapter
│   │       │           └── paid_data/  # base_adapter + 19 SCRM-Adapter
│   │       └── shared/
│   │           ├── domain/             # money.rb
│   │           └── infrastructure/
│   │               ├── http/           # json_client.rb, rate_limiter.rb
│   │               ├── audit/          # recorder.rb
│   │               └── jobs/           # job_adapter.rb, job_status.rb
│   ├── config/
│   │   ├── application.rb / routes.rb / database.yml / puma.rb / boot.rb
│   │   ├── cache.yml / queue.yml / recurring.yml
│   │   ├── risk_providers.yml / risk_country_data.yml / risk_port_data.yml
│   │   ├── environments/               # development/test/production
│   │   └── initializers/               # cors, rack_attack, background_jobs, …
│   ├── db/
│   │   ├── migrate/                    # 7 Migrationen (20260101…)
│   │   ├── schema.rb / seeds.rb
│   │   └── cache_schema.rb / queue_schema.rb
│   ├── spec/                           # RSpec (contracts/domain/application/requests/jobs/…)
│   ├── lib/tasks/smoke.rake            # End-to-End-Smoke-Test
│   ├── Gemfile / Gemfile.lock / .ruby-version / .env.example
│   └── bin/                            # rails, rake, jobs, setup, bundle
│
├── web/                                # React 19 SPA
│   ├── src/
│   │   ├── main.tsx / App.tsx / theme.ts / query-client.tsx / stores.ts
│   │   ├── shell/AppShell.tsx
│   │   ├── shared/
│   │   │   ├── module-registry.ts
│   │   │   ├── api/                    # http.ts + types/ (project, material, risk, …)
│   │   │   ├── components/             # RiskAmpel, ErrorBoundary, LoadingState, …
│   │   │   ├── hooks/                  # useAsync
│   │   │   └── lib/                    # money.ts, format.ts, errors.ts
│   │   └── apps/
│   │       ├── calculator/             # aktiv (api/ store/ tabs/ components/)
│   │       ├── material-management/    # Coming Soon
│   │       ├── production-planner/     # Coming Soon
│   │       ├── inventory/              # Coming Soon
│   │       ├── reporting/              # Coming Soon
│   │       └── supply-chain-risk/      # Coming Soon
│   ├── package.json / package-lock.json / vite.config.ts / tsconfig.json
│   └── index.html / vitest.setup.ts
│
├── .dev-notes/                         # Statusberichte, Logs (seed-, smoke-, db-…)
├── .dev-tools/                         # ca-bundle.pem, fix-ca.ps1, Install-Logs
├── start-dev.ps1 / start-dev.bat / stop-dev.ps1
├── README.md / LICENSE / versioning.md
├── orignal_app_structure_ref.md        # Spezifikations-Referenz (21.800 B)
└── original_app_structure.md           # leer (0 B)
```

## Hinweise

- Die Controller-Namensgebung folgt Rails-Konvention: `api/v1/*_controller`.
- Die Bounded-Context-Ordner unter `app/modules` sind über `config.autoload_paths`
  als Namespaces (`Calculator`, `SupplyChainRisk`, `Shared`, `Auth`) eingebunden.
- Frontend-Module werden per `module-registry.ts` lazy geladen; Vite emittiert pro
  Modul einen eigenen Chunk.
