# Versioning / Fortschrittsprotokoll

## 2026-02-27 - Backend: Notification-Controlling-Pfade vervollstandigt
- Aufgabe: 2 (Teil)
- Anderung: 
  - risk_notifications_controller.rb auf Acknowledge/Dismiss (POST) + erweiterte JSON-Serialisierung angepasst.
  - RiskNotification-Model um acknowledged_at/acknowledged_by und dismissed_at/dismissed_by erweitert.
- Betroffene Dateien: api/app/controllers/api/v1/risk_notifications_controller.rb, api/app/models/risk_notification.rb
- Tests: Noch nicht implementiert (Rails-Tests fehlen im Baum)
- Offene Punkte: Frontend-Zustand/UI folgt; DB-Schema hat bereits die notwendigen Spalten

## 2026-02-27 - Web-Typen: Notification-Summary eingefugt
- Aufgabe: 2 (Teil)
- Anderung: web/src/shared/api/types/common.ts um NotificationStatus und RiskNotificationSummary erganzt; Build erfolgreich
- Betroffene Dateien: web/src/shared/api/types/common.ts
- Tests: Keine Web-Tests vorhanden; Build als Prufung genutzt


## 2026-02-27 – Lieferrisiko-Modul: Freie Provider, Notification-UX, Tests (Iteration 1)
- Aufgabe: 1/2/3 (+ Optional-Prep für 4)
- Änderung: Konsistenzprüfung bestehender Implementierung, Entscheidung zu Datenquellen-Status, Plan zur Umsetzung, Versionsprotokoll eingerichtet, Redis→Solid-Cache/Queue-Korrektur dokumentiert.
- Betroffene Dateien/Module: 
  - Backend: `api/app/modules/supply_chain_risk/...` (Domain/Infrastructure/Application/Jobs), `api/app/models/...`, Controller, Migrations.
  - Frontend: `web/src/shared/api/types/risk.ts`, `RiskAmpel.tsx`, `web/src/apps/calculator/...` (Teil-Infrastruktur vorhanden).
- Tests: Noch nicht implementiert (keine `spec/`/`test/`-Dateien im Baum). Geplant für diesen Zyklus.
- Offene Punkte / bekannte Einschränkungen:
  - `original_app_structure.md` enthält ausdrücklich Redis; aktuelle Codebasis nutzt Solid Cache + Solid Queue. Korrektur muss konsequent sein.
  - Paid-Adapter sind fast ausschließlich Stub/Schema-Definitionen; echte Integrations-Tests fehlen.
  - Frontend-Notification-UX (Glocke, Badge, Dropdown, Acknowledge/Dismiss, Deep-Link) existiert noch nicht.
  - Datenquellen-Status je Quelle muss finalisiert werden (siehe Tabelle unten).
- Abweichungen von original_app_structure.md:
  - Redis durch Solid Cache + Solid Queue ersetzt (Tech-Stack-Vorgabe, keine separaten Redis-Prozesse).
  - `risk_provider_configs` ist projektspezifisch realisiert (API-Key verschlüsselt, Poll-Intervall, Priority), passt aber zum Konzept.

## Datenquellen-Status (Auswahl aus Kategorie A)

| Datenquelle | Status | Begründung | TTL / Poll-Intervall |
|---|---|---|---|
| World Bank LPI | **implementiert** (Adapter vorhanden, HTTP/Parsing/Normalisierung vorhanden) | Stabile, frei verfügbare Indicatoren-API; seltene Änderung → langes Cache-TTL. | Cache 24h+ (Prod-TTL 1440 min im Katalog); Job-Polling nach Bedarf. |
| GDACS | **implementiert** | Freie EU/JRC-Daten, gutes Event-Modell, wird für `risk_events` genutzt. | Cache ~30 min, Disaster-Polling 30 min. |
| USGS Earthquake | **implementiert** | Freie GeoJSON-Feed, wird für events + assess genutzt. | Cache ~60 min, Event-Polling 24h Lookback. |
| Open-Meteo | **implementiert** | Kein Key nötig, Wetterlage/Böen/Niederschlag als Logistiksignal. | Cache ~2h. |
| ECB/EUR FX (Frankfurter API) | **implementiert** | Kostenlos, kein Key, Wechselkurs als Finanzrisiko. Bug behoben: Ländercode→Währung-Mapping ergänzt (`CURRENCY_BY_COUNTRY`), vorher antwortete der Adapter für echte Materialien immer `nil`. | Cache ~12h. |
| EU Consolidated Sanctions | **implementiert** (CSV-Sync ins DB) | Audit-relevant → persists in `sanctions_entries`, täglich Sync via `RefreshSanctionsListJob`. | Sync täglich, Screening täglich; Cache-TTL lang. |
| OFAC SDN | **implementiert** (CSV-Sync ins DB) | Wie EU-Liste; täglicher Sync + Screening. | Sync täglich. |
| EU TARIC | **optional/deaktivierbar** | Kein freier REST-Endpunkt ohne Konfiguration; Adapter ist endpoint-konfigurierbar. Ohne Konfiguration skip. | Konfigurierbar, kein automatischer Polling ohne Endpoint. |
| ReliefWeb (UN OCHA) | **optional/deaktivierbar** | Benötigt approved appname; sonst 403. Adapter vorhanden, aber ohne Konfiguration deaktiviert. | Optional, Polling nur wenn Konfiguriert. |
| UN Comtrade | **implementiert (optional/deaktivierbar)** | Public-Preview-Endpoint ohne Key (120 Anfragen/Std.); Adapter vollständig, UN-M49-Ländercodes (`comtradeCodes`) in `risk_country_data.yml` ergänzt. | Cache 24h; Abfrage nur bei Bedarf je Material. |
| Öffentliche Hafenauslastungs-Indizes (z. B. allgemeine Port Congestion Feeds) | **verworfen als automatische Quelle (Stub)** | Kein lizenzkonformes, frei häkchenfähiges ständiges Feed-Format identifiziert; interner Port-Congestion-Adaptor nutzt konfigurierten Lokal-Datensatz (yaml) als Platzhalter. | N/A |
| Freightos Baltic Index (FBX) | **optional/deaktivierbar** | Benötigt API-Key; Adapter vorhanden; optional iconfigurierbar. | Konfigurierbar; Sync-Job vorhanden. |

> Hinweis: Diese Tabelle ist die einzige Wahrheit für Datenquellen-Status. Nicht eingetragene Quellen sind ab sofort Stubs/optional/verworfen.

## 2026-02-27 – Notification-API + Frontend-Typen erweitert
- Aufgabe: 2 (Teil)
- Änderung: Frontend-API-Kontext um Notifications-Endpunkte und Typen ergänzt (`notifications`, `acknowledgeNotification`, `dismissNotification`, Typen `RiskNotification`, `NotificationStoreEntry`). Build erfolgreich (tsc + vite build).
- Betroffene Dateien/Module: `web/src/apps/calculator/api/risk.ts`, Web-Typen (Common/Risk).
- Tests: Noch nicht; Web-Tests noch nicht vorhanden (planen).
- Offene Punkte / bekannte Einschränkungen:
  - Controller-Endpoints für Notifications (Acknowledge/Dismiss) müssen analog `risk_events_controller.rb` implementiert werden ( PATCH / POST vs. aktuelle PATCH-basierte "")
  - Zustand-Notification-State + UI-Komponente (Glocke/Badge, Dropdown, Deep-Link) folgt als nächster Schritt.
- Abweichungen von original_app_structure.md: Keine Breaking Changes; ergänzende Endpunkte passen zum bestehenden API-Design.

## 2026-09-25 – Lieferrisiko-Modul: Freie Provider, Notification-UX, Tests (Iteration 2)
- Aufgabe: 1/2/3 (+ 4 als Test-Harness)
- Änderung (Backend – Aufgabe 1):
  - **Stale-Fallback** in `ProviderContext#cached`: erfolgreiche Reads schreiben zusätzlich eine langlebige `:stale`-Kopie; bei Provider-Ausfall wird der letzte bekannte Wert zurückgegeben und über `last_read_stale?` markiert. `RiskDataProvider#draft` kennzeichnet solche Drafts in `reason` („⚠ Stale-Fallback …“) und halbiert `confidence` – niemals harter Fehler im Kalkulator, aber auch nie „frisch vortäuschen“.
  - **`RiskDataProvider#events_safely`** ergänzt; `PollDisasterAlertsJob` nutzt sie, damit ein nicht erreichbarer Feed zum leeren Ergebnis statt zum fehlgeschlagenen Job degradiert.
  - **Per-Projekt-Polling** über neues `Infrastructure::PollSchedule`: `risk_provider_configs` (enabled, `poll_interval_minutes`, `last_run_at`) entscheidet, welcher Provider wann pollt; Projekte ohne Konfiguration nutzen Katalog-Defaults. `PollDisasterAlertsJob` markiert Erfolg/Fehler auf der Config.
  - **`available?`-Fix**: berücksichtigt jetzt den projektgebundenen API-Key aus `ProviderContext#configured?` (vorher wurde ein per Projekt hinterlegter Paid-Key ignoriert).
  - **`event_capable_provider_keys`-Fix**: erkennt jetzt echte Event-Feeds (override) statt jeden freien Adapter (die Basisklasse vererbt `events`).
  - **ECB-Fix**: `currency_for` übersetzt ISO-Ländercode→Währung; vorher `nil` für jedes reale Material.
  - **UN-Comtrade**: `comtradeCodes` (UN-M49) in `config/risk_country_data.yml` ergänzt → Adapter jetzt funktionsfähig; Status von „verworfen“ auf „implementiert (optional)“ geändert (siehe Tabelle).
- Änderung (Backend – Aufgabe 2):
  - Migration `20260101000007` ergänzt `risk_notifications.acknowledged_at/_by_id, dismissed_at/_by_id` (Model-Vertrag war dem Schema voraus).
  - `RiskNotificationsController` um `read`, `read_all`, Status-Filter (`status`/`severity`), Meta-Zähler und `status`-Feld erweitert; nichts wird gelöscht. Route `/api/v1/notifications` als Alias zu `/api/v1/risk_notifications`.
  - `RiskNotification` um `undismissed`/`open`/`for_material`-Scopes + `#status` ergänzt.
  - `Domain::NotificationPolicy` (pure Entscheidungslogik: wann Event/🔴 benachrichtigt, Dedupe, konfigurierbarer Schweregrad-Floor via `RISK_NOTIFICATION_MIN_SEVERITY`) eingeführt; `NotifyRiskAlert` nutzt sie und versendet Deep-Link-Payload (`materialId`, `riskEventId`).
  - `RefreshMaterialRisk` übergibt zusätzlich `previous_score`, damit „bleibt 🔴 mit unverändertem Score“ still bleibt.
- Änderung (Bugfixes, durch Tests aufgedeckt):
  - `PaidData::BaseAdapter#extract_dimensions`: `Domain::RiskAssessment` → `::RiskAssessment` (Konstantenauflösung).
  - `SanctionsEntry.sync!` + `PurgeExpiredAssessmentsJob`: UUID-PK bei `upsert` explizit gesetzt (vorher `NOT NULL constraint failed: id`) inkl. `update_only`, damit der PK bei Konflikt stabil bleibt.
  - `ApplicationController#authenticate_user!`/`require_write!` halten jetzt an (raise + `rescue_from`), statt nach `render` weiterzulaufen (vorher DoubleRenderError/500 bei fehlender Schreibberechtigung).
- Änderung (Frontend – Aufgabe 2):
  - Zustand-Store `notification-store.ts` (Panel offen/`lastSeenAt`), TanStack-Query-Hooks `api/notifications.ts` (30s-Polling, Acknowledge/Dismiss/Read/Read-all).
  - `components/NotificationBell.tsx`: Glocke mit Badge-Count, Dropdown, Acknowledge/Dismiss, „Alle gelesen“, Deep-Link.
  - `components/MaterialRiskPanel.tsx`: aufklappbarer Lieferrisiko-Bereich der Materialkarte; `MaterialTab` klappt per Deep-Link (`focusMaterialId`) auf und scrollt hin; `calculator-store` um `focusMaterialId` erweitert.
  - Typen `RiskNotification`/`NotificationMeta`/`NotificationStatus` in `api/risk.ts` an das Backend-JSON angeglichen.
- Betroffene Dateien/Module:
  - Backend: `app/modules/supply_chain_risk/{domain,application,infrastructure}/…`, `app/jobs/supply_chain_risk/*`, `app/models/{risk_notification,sanctions_entry}.rb`, `app/controllers/api/v1/{risk_notifications_controller,application_controller}.rb`, `config/routes.rb`, `config/risk_country_data.yml`, `config/environments/test.rb`, `db/migrate/20260101000007_*`, `app/modules/shared/infrastructure/jobs/job_adapter.rb`.
  - Frontend: `web/src/apps/calculator/{api,components,store}/…`, `web/src/apps/calculator/tabs/MaterialTab.tsx`, `web/src/apps/calculator/index.tsx`.
- Tests:
  - RSpec (neu, `api/spec/`): Provider-Contract-Harness (`spec/support/risk_provider_contract.rb` + `spec/contracts/…` mit 14 Fixtures in `spec/fixtures/risk/`), Domain (Scoring, Event-Drafting+Dedupe, NotificationPolicy, ProviderContext-Stale), Application (Aggregation, NotifyRiskAlert), Requests (Notifications/RiskEvents/RiskProviders/MaterialRisk), Jobs (PollDisaster/Sanctions/FreightIndex/Refresh/Purge + recurring.yml + Solid-Infrastruktur), Factories. **323 Beispiele grün**.
  - Frontend: `notification-store.test.ts` (neu), Bestandstests grün; `tsc -b --noEmit` und `vite build` erfolgreich.
- Offene Punkte / bekannte Einschränkungen:
  - Paid-Adapter bleiben deklarativ/Stub (nur project44 mit Recording im Harness); echte Vertrags-URLs/Schemata fehlen bewusst (Vertragsgated).
  - ActionCable-Push nicht umgesetzt (bewusst: Intervall-Polling reicht laut Scope; Architektur über Query-Key wechselbereit).
  - `eu_taric`/`reliefweb`/`freightos_fbx`/`fred_economic`/`openweather_alerts` benötigen weiterhin Endpoint/Appname/Key (optional).
- Abweichungen von original_app_structure.md:
  - Redis bleibt durch Solid Cache + Solid Queue ersetzt (Tech-Stack-Vorgabe), in `config/cache.yml`, `database.yml` und dem neuen `solid_infrastructure_spec` verankert.
  - Endpunkte heißen weiter `risk_notifications` (plus Alias `/notifications` aus dem Update-Prompt); kein Breaking Change zu bestehendem API-Design.


