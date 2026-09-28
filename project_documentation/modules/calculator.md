# Modul: `calculator`

## Rolle

Vollständige **Produkt- und Verkaufspreiskalkulation**. Einziger Bereich, der die
Risikodaten in den Preis übersetzt.

## Dateien

```
app/modules/calculator/
├── domain/
│   ├── cost_basis.rb            # Value Objects (Inputs, MaterialLine, …)
│   ├── cost_breakdown.rb        # CostLine/Block/Basis
│   ├── pricing_calculator.rb    # Kern-Engine
│   ├── price_optimizer.rb       # Zielpreis-Simulation
│   ├── risk_surcharge_policy.rb # Score → Zuschlag
│   └── lead_time_analyzer.rb    # Lieferzeitanalyse
└── application/
    ├── build_cost_basis.rb      # ActiveRecord → CostBasis (Port)
    ├── serializers.rb           # camelCase-Serialisierung
    ├── material_serializer.rb
    ├── duplicate_project.rb
    ├── project_document.rb      # JSON-Import/Export
    ├── project_csv.rb
    └── apply_cost_template.rb
```

## Kern-Objekte

### `CostBasis`
Unveränderlicher Input-Schnappschuss eines Projekts. Enthält `Inputs` (Volumen,
Steuer, Risiko-Zuschlag), sowie Arrays von `MaterialLine`, `MonthlyLine`, `LaborLine`,
`FixedLine`, `OverheadLine` und ein `RiskInput`.

### `PricingCalculator`
- `initialize(basis)` + `#call` → `Result`.
- Baut Blöcke: material, labor, fixed, monthly, overhead, risk.
- `#policy` gibt die aufgelöste `RiskSurchargePolicy` zurück (das „Warum“ für die UI).

### `PriceOptimizer`
- `call(target_price_cents:, includes_tax:, …)` → `Result` mit Gewinn, Marge,
  Deckungsbeitrag, Umsatz, Monatsgewinn, Break-Even.

### `RiskSurchargePolicy`
- Lineares, gedeckeltes Zuschlagsmodell; manueller Override gewinnt; per ENV
  kalibrierbar (Details → [06](../06_functions_and_logic.md)).

### `LeadTimeAnalyzer`
- Aggregation von Lieferzeiten inkl. Risikopuffer; Buckets und „Long Lead“.

## Anwendungsschicht

- `BuildCostBasis` ist der einzige Ort, der ActiveRecord in Domain-Value-Objects
  übersetzt (Ports & Adapters). Es ruft `AggregateProductRisk` für den Risiko-Input.
- `DuplicateProject`, `ProjectDocument`, `ProjectCsv`, `ApplyCostTemplate` orchestrieren
  Import/Export/Duplizieren/Vorlagen.

## Frontend-Gegenstück

`web/src/apps/calculator/` (aktiv): Tabs `MaterialTab`, `MonthlyCostsTab`,
`FixedCostsTab`, `PricingTab`, `DashboardTab`; API-Hooks in `api/*`, UI-State in
`store/*`.
