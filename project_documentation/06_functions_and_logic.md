# 06 — Funktionen & Kernlogik

## Preiskalkulation (`PricingCalculator`)

Basis ist **eine Produktions-Charge** als Kostenrechnungseinheit; **Pro-Stück-Werte
sind maßgeblich**, Batch-/Monatswerte werden daraus abgeleitet.

```
per_unit_net  = Material + Monatskosten + Arbeitslohn + Fixkosten
                + Gemeinkosten + Risikozuschlag
per_unit_tax  = per_unit_net × Steuersatz        (kaufmännische Rundung)
per_unit_gross= per_unit_net + per_unit_tax
```

Aufbau (Reihenfolge in `#call`):
1. Material-Block (Batch)
2. Labor-Block (Batch)
3. Fixkosten-Block (Batch, Monat)
4. Monatskosten-Block (Batch, Monat)
5. Gemeinkosten-Block (Zuschläge auf Basisblöcke)
6. Risiko-Block (Zuschlag auf Zwischensumme)
7. `Result` mit `inputs`, `blocks`, `lines`, `totals`, `risk`, `taxes`, `warnings`

## Risikozuschlag (`RiskSurchargePolicy`)

Lineares, gedeckeltes Modell (per ENV kalibrierbar):

```
surcharge = score/100 × MAX                 (Basis, Default 15 %)
          + CRITICAL_BONUS je kritischer Position   (Default 1,5 %, Cap 5 %)
          + SINGLE_SOURCE_BONUS je Einzelquelle     (Default 0,5 %, Cap 3 %)
          gedeckelt auf MAX
```

- Manueller Override (`project.risk_surcharge_pct`) gewinnt immer (`source: manual`).
- Ohne Risikodaten: Zuschlag 0 (`source: none`).
- Ampel: `low` (<34), `medium` (34–66), `high` (67–100).

## Preisoptimierung (`PriceOptimizer`)

Beantwortet „Was passiert bei Verkaufspreis X?“ — getrennt von der Kalkulation, damit
der UI-Slider viele Zielpreise ohne Neuberechnung der Kostenbasis testen kann.

- `target`, `calculated`, `profit`, `revenue`, `monthly_profit`, `break_even`,
  `variable_cost`, `fixed_cost`.
- Break-Even (Stück/Monat): `ceil(fixkosten / deckungsbeitrag)`.

## Lieferzeitanalyse (`LeadTimeAnalyzer`)

Reine Aggregation über `MaterialLine`-Werte:
- `RISK_BUFFER_DAYS = { high: 14, medium: 7, low: 2 }` (Risikopuffer).
- `riskWeightedDays = geplante Tage + Puffer(risk_level)`.
- Buckets: bis 7 / 8–30 / 31–60 / über 60 Tage; „Long Lead“ ab 60 Tagen.

## Risiko-Aggregation (`AggregateProductRisk`)

- Produktebene: Mittelwert der denormalisierten `material.risk_score`; Level über
  `RiskAssessment.level_for`.
- Materialebene (`material_view`): Ampel, Dimensionen, Datenquellen, Sanktionsstatus,
  Alternativlieferanten, letztes Event, manuelle Bewertung.

## Provider-Abstraktion

Jeder Provider implementiert `RiskDataProvider`:
- `assess(subject) → AssessmentDraft|nil` (nie werfen bei erwarteten Problemen)
- `events(since:) → [EventDraft]` (Bulk-Feeds; Default leer)
- `probe` (günstiger Verbindungstest, schreibt nichts)
- `available?` (Key vorhanden / Open Data)

`AssessmentDraft#build` clampt Score/Dimensionen auf 0–100 und normalisiert auf die
sechs bekannten Dimensions-Keys (`logistics`, `geopolitical`, `weather`, `financial`,
`compliance`, `operational`).

## Caching & Stale-Fallback (`ProviderContext#cached`)

- Erfolgreiche Reads werden mit TTL im Cache gespeichert **und** als langfristige
  `:stale`-Kopie (TTL × 14).
- Ist der Upstream nicht erreichbar und der frische Eintrag abgelaufen, wird der
  letzte bekannte Wert zurückgegeben; der Draft wird als „stale“ markiert und die
  Confidence halbiert (`RiskDataProvider#draft`).

## Ereignis-Ingestion (`EventDraft#persist!`)

Idempotentes Upsert über `(source, source_event_id)`; bei jedem **neuen** Event wird
`NotifyRiskAlert.for_event!` ausgelöst. Re-Polls aktualisieren nur und benachrichtigen
niemanden.

## Benachrichtigungs-Policy (`NotificationPolicy`)

- Neues Frühwarnereignis → benachrichtigen (einmal).
- Material wird 🔴 oder bleibt 🔴 mit neuem Score → benachrichtigen.
- Unverändertes 🔴 → still.
- Schweregrad-Floor via `RISK_NOTIFICATION_MIN_SEVERITY` (Default `low`).

## Geld (`Shared::Domain::Money`)

- Speicherung/Transport als **ganze Cent** (vermeidet Float-Drift).
- Rundung `:half_up` (kaufmännisch).
- `allocate(total, weights)` verteilt ohne Cent-Verlust (Größte-Reste-Verfahren).

## Audit (`Shared::Infrastructure::Audit::Recorder`)

Einheitliche Schreibung von `AuditLog`-Zeilen für Create/Update/Delete/Export/Import/
Provider-Config/Refresh; Fehler werden geloggt, brechen aber nie die Business-Transaktion.
