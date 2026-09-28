# 11 — Datenbank & Datenmodell

## Datenbanken (SQLite)

| Datei | Zweck |
|---|---|
| `storage/<env>.sqlite3` | Anwendungsdaten (`primary`) |
| `storage/<env>_cache.sqlite3` | Solid Cache |
| `storage/<env>_queue.sqlite3` | Solid Queue |

## Microsoft SQL Server (optionales Backend)

Die primäre Anwendungsdatenbank kann auf **Microsoft SQL Server** statt SQLite
betrieben werden (Adapter `activerecord-sqlserver-adapter` + `tiny_tds`). Dabei
garantiert die Initialisierung drei Datenbanken:

| Datenbank | Verantwortung |
|---|---|
| `app_data` | Primäres Anwendungsschema (alle AR-Modelle) |
| `log` | Protokollierung / Audit-Trail |
| `users` | Identitäts-Speicher (Benutzer) |

Ersteinrichtung, Provisionierung (nur fehlende DBs anlegen), Schema-Migration und
Legacy-Datenmigration (SQLite → SQL Server) sind in
[18_sql_server.md](18_sql_server.md) dokumentiert. Solid Cache / Solid Queue
bleiben auf SQLite.

Schema-Quelle: `api/db/schema.rb` (Format `:ruby`), Migrationen unter `api/db/migrate`
(`20260101000001` … `20260101000008`). `cache_schema.rb`/`queue_schema.rb` halten die
Solid-Schemata. Migration `20260101000008` ersetzt alle persistenten JSON-Spalten
durch normalisierte relationale Tabellen — siehe [19_json_to_sql_migration.md](19_json_to_sql_migration.md).

## Gemeinsame Merkmale

- Alle Tabellen verwenden **String-UUID-Primärschlüssel** (Länge 36).
- UUIDs werden in Ruby (`SecureRandom.uuid`) erzeugt — identisches Verhalten auf
  SQLite und PostgreSQL, verschachtelte Dokumente können vor dem Persistieren
  des Parents gebaut werden.
- Fremdschlüssel (`foreign_keys: true`) aktiv.

## Tabellen (Übersicht)

| Tabelle | Kernspalten |
|---|---|
| `users` | email (unique), password_digest, name, role, active, locale, last_login_at |
| `audit_logs` | action, auditable_type/id, user_id, ip, user_agent, occurred_at → `audit_log_changes` + `audit_log_metadata` |
| `projects` | name, description, status, country, currency, tax_rate, tax_profile, units_per_month, batch_size, target_margin_pct, risk_surcharge_pct, auto_risk_surcharge, risk_refresh_interval_hours, owner_id, archived_at |
| `suppliers` | name, country, city, contact_*, website, rating, is_single_source, sanctions_status/details/checked_at |
| `materials` | project_id, supplier_id, name, material_type, unit, quantity, min_order_quantity, unit_price_cents, price_includes_tax, lead_time_value/unit/days, stock/reorder, risk_score, risk_level, last_risk_checked_at |
| `material_risk_profiles` | material_id (unique), origin_country, hs_code, shipping_route, transport_mode, is_single_source, historical_delay_*, last_disruption_*, freight_cost_trend, manual_risk_level/note, manual_score_override |
| `alternative_suppliers` | material_id, supplier_id, name, country, priority, lead_time_days, unit_price_cents |
| `material_documents` | material_id, name, kind, url, content_type, byte_size |
| `monthly_costs` | project_id, category, name, amount_cents, currency, is_recurring, position |
| `sales_forecasts` | project_id, period (unique je Projekt), forecast_units, actual_units |
| `labor_costs` | project_id, employee, role, department, hours, hourly_rate_cents |
| `fixed_costs` | project_id, category, name, amount_cents, allocation_basis, position |
| `overhead_rules` | project_id, key, name, percentage, base, auto_from_risk, enabled, position |
| `cost_templates` | project_id (nullable), name, kind, description, is_global → `cost_template_items` |
| `pricing_scenarios` | project_id, name, target_price_cents, target_price_includes_tax, units_per_month, batch_size, is_active → `pricing_scenario_results` (1:1) + `pricing_scenario_warnings` |
| `risk_assessments` | material_id, provider_key/name/tier, risk_score, risk_level, lead_time_variance_days, reason, origin, fetched_at, expires_at, raw_payload(text), confidence → `risk_assessment_dimensions` + `risk_assessment_data_sources` |
| `risk_events` | material_id, project_id, event_type, severity, title, description, source, source_event_id (unique je source), country_code, occurred_at, acknowledged_at/by → `risk_event_metadata` |
| `risk_notifications` | project_id, material_id, risk_event_id, kind, severity, title, body, source, country_code, event_type, risk_score, risk_level, read_at/by, acknowledged_at/by, dismissed_at/by |
| `risk_provider_configs` | project_id, provider_key (unique je Projekt), api_key(encrypted), config(text), enabled, poll_interval_minutes, priority, last_run_at/status/error, consecutive_failures |
| `risk_provider_runs` | provider_key, project_id, started_at, finished_at, status, duration_ms, requests_made, assessments_written, events_written, error_* |
| `risk_score_snapshots` | material_id, captured_on (unique je Material), risk_score, risk_level, event_count |
| `sanctions_entries` | source, entity_name, normalised_name, entity_type, list_name, program, country_code, listed_on → `sanctions_entry_aliases` + `sanctions_entry_identifiers` |

## Beziehungen (Auszug)

- `Project` hat viele: suppliers, materials, monthly_costs, labor_costs, fixed_costs,
  overhead_rules, sales_forecasts, pricing_scenarios, cost_templates, risk_events,
  risk_provider_configs.
- `Material` gehört zu project/supplier; hat eins `material_risk_profile`; hat viele
  alternative_suppliers, material_documents, risk_assessments, risk_events,
  risk_score_snapshots.
- `RiskAssessment`/`RiskEvent`/`RiskScoreSnapshot` gehören zu material.
- `RiskNotification` gehört optional zu project/material/risk_event.

## Denormalisierung (Kernentscheidung)

`materials.risk_score/risk_level/last_risk_checked_at` werden ausschließlich vom
`supply_chain_risk`-Kontext geschrieben. Der `calculator`-Kontext liest nur diese
Spalten und nie die Risiko-Tabellen → Entkopplung der beiden Kontexte.
