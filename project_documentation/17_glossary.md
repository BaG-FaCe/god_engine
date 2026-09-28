# 17 — Glossar

| Begriff | Bedeutung |
|---|---|
| **Modularer Monolith** | Eine App, intern in klar getrennte Module (Bounded Contexts) gegliedert, aber als ein deploybares Artefakt betrieben |
| **Bounded Context** | DDD-Begriff: ein fachlich abgegrenzter Bereich mit eigener Sprache und eigenem Modell (hier `calculator`, `supply_chain_risk`, `shared`) |
| **Ports & Adapters** | Hexagonale Architektur: Domäne hängt nur von Ports (Schnittstellen) ab, Adapter verbinden zur Außenwelt |
| **RiskDataProvider** | Zentrale Schnittstelle, die jede Risikoquelle implementiert (`assess`, `events`, `probe`) |
| **AssessmentDraft** | Normalisiertes, noch nicht persistiertes Risikobewertungs-Objekt eines Providers |
| **EventDraft** | Normalisiertes Frühwarnsignal (Wetter, Katastrophe, Sanktion, …) |
| **Ampel** | Risikostufen `low` (grün), `medium` (gelb), `high` (rot); 0–33 / 34–66 / 67–100 |
| **Risikozuschlag** | Aufschlag auf den Preis, abgeleitet aus dem aggregierten Risikoscore |
| **Solid Cache** | Rails-8-Cache-Backend auf SQLite-Basis (ersetzt Redis) |
| **Solid Queue** | Rails-8-Job-Backend auf SQLite-Basis (ersetzt Sidekiq/Redis) |
| **JWT** | JSON Web Token (HS256), hier für API-Auth |
| **UUID-PK** | String-Primärschlüssel (36 Zeichen), in Ruby erzeugt |
| **Denormalisierung** | Risiko-Score/-Level zusätzlich auf `materials` gespiegelt, um Kontext-Kopplung zu vermeiden |
| **Stale-Fallback** | Rückgriff auf den letzten bekannten Provider-Wert, wenn der Upstream nicht erreichbar ist |
| **Rate-Limiter** | Begrenzung ausgehender Provider-Aufrufe (Fixed-Window, je Minute) |
| **Contract-Harness** | Testgerüst, das jeden Provider gegen den `RiskDataProvider`-Vertrag prüft |
| **TanStack Query** | React-Bibliothek für Server-State (Caching, Invalidation, Polling) |
| **Zustand** | Leichtgewichtiger React-Client-State-Store (mit `persist`) |
| **Cent-Konvention** | Geldbeträge werden durchgängig als ganze Cent (Integer) transportiert |
| **camelCase / snake_case** | API-Ausgabe camelCase, Datenbank snake_case |
| **Fugit** | Ruby-Bibliothek zur Auswertung natürlicher Cron-Ausdrücke in `recurring.yml` |
| **SCRM** | Supply Chain Risk Management (kommerzielle Risiko-Plattformen) |
