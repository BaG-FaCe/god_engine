# Modul: `supply_chain_risk`

## Rolle

**Lieferrisiko-Frühwarnsystem**: Provider-Abstraktion, Risiko-Aggregation,
Ereignis-Ingestion, In-App-Benachrichtigungen und die zugehörigen Hintergrundjobs.

## Dateien

```
app/modules/supply_chain_risk/
├── domain/
│   ├── risk_data_provider.rb     # Vertrag (Interface)
│   ├── assessment_draft.rb       # normalisiertes Bewertungsobjekt
│   ├── event_draft.rb            # Frühwarnsignal + persist!
│   ├── provider_descriptor.rb    # Metadaten
│   ├── provider_context.rb       # injizierte Außenwelt
│   ├── subject.rb                # "Frage" zu einem Material
│   └── notification_policy.rb    # Benachrichtigungs-Entscheidung
├── application/
│   ├── aggregate_product_risk.rb
│   ├── refresh_material_risk.rb
│   └── notify_risk_alert.rb
└── infrastructure/
    ├── provider_catalogue.rb     # lädt risk_providers.yml
    ├── provider_registry.rb      # Katalog + Projekt-Config
    ├── poll_schedule.rb          # wann/was pollen
    └── providers/
        ├── internal/             # manual_provider, heuristic_provider
        ├── free_data/            # 14 Open-Data-Adapter
        └── paid_data/            # base_adapter + 19 SCRM-Adapter
```

## Vertrag (`RiskDataProvider`)

Jede Quelle implementiert `assess`, `events`, `probe`, `available?` und liefert
`AssessmentDraft`/`EventDraft`. Provider sind zustandslos pro Aufruf und dürfen bei
erwarteten Problemen `nil` zurückgeben (statt zu werfen).

## Aggregation (`AggregateProductRisk`)

- `call(project:)` → Produkt-Risiko (Mittelwert, Level, kritische/ Einzelquellen-Zähler,
  Datenquellen).
- `material_view(material)` → Materialkarten-View (Ampel, Dimensionen, Assessments,
  Events, manuelle Bewertung, Sanktionsstatus).
- Liest nur die denormalisierten `materials.risk_score/risk_level` — nie die
  Risiko-Tabellen direkt (Entkopplung).

## Refresh (`RefreshMaterialRisk`)

1. `Subject.from_material`.
2. `ProviderRegistry.active_for(project)` (Priorität: Projekt-Config → free → internal).
3. je Provider `ProviderContext` bauen (inkl. Projekt-Overrides + verschlüsseltem Key).
4. `provider.assess(subject)` → `RiskAssessment.create!` (append-only).
5. Denormalisierung auf `material`.
6. `NotifyRiskAlert.for_material!` (🔴-Erkennung).

## Polling (`PollSchedule` + Jobs)

- `PollSchedule.due(provider_keys:)` liefert fällige `Scope`-Objekte (Projekt-Override
  gewinnt, `enabled:false` deaktiviert, ohne Config = Katalog-Default).
- Jobs: `PollDisasterAlertsJob`, `SyncFreightIndexJob`, `RefreshRiskAssessmentsJob`,
  `RefreshSanctionsListJob`, `PurgeExpiredAssessmentsJob`, `RefreshMaterialRiskJob`.
- Idempotenz durch `(source, source_event_id)`-Unique-Index.

## Benachrichtigungen (`NotifyRiskAlert` + `NotificationPolicy`)

- `for_event!` bei jedem neuen Event; `for_material!` bei 🔴.
- Policy entscheidet, Service schreibt; Fehler werden geloggt und verschluckt
  (niemals den Schreibpfad brechen).

## Cache & Stale-Fallback (`ProviderContext`)

- `cached(namespace, key)` cached mit TTL **und** `:stale`-Kopie (TTL × 14).
- Bei Upstream-Ausfall → letzter bekannter Wert, als „stale“ markiert, Confidence halbiert.
