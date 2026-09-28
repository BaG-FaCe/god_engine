# 01 — Projektübersicht

## Kurzbeschreibung

**God Engine** ist eine modulare Web-Plattform zur **Produkt- und Verkaufspreiskalkulation**
mit einem integrierten **Lieferrisiko-Frühwarnsystem**. Sie richtet sich an
Fertigungs- und Handelsunternehmen, die Stückkosten und Verkaufspreise aus
Material-, Monats-, Arbeits- und Fixkosten herleiten und dabei Lieferkettenrisiken
transparent einpreisen wollen.

## Kernzweck

1. **Preiskalkulation** über fünf Tabs:
   - Tab 1 · Materialkosten (Stücklistenpositionen, Lieferanten, Lieferzeitanalyse)
   - Tab 2 · Monatliche Kosten (wiederkehrende Kosten + Verkaufsprognose)
   - Tab 3 · Fix- & Gemeinkosten (Arbeit, Fixkosten, Zuschläge)
   - Tab 4 · Preiskalkulation (Gesamtkosten, Preisoptimierung, Szenarien)
   - Tab 5 · Dashboard (KPIs, Diagramme, Risiko-Rollup)
2. **Lieferrisiko-Management**: aggregierter Risikoscore 0–100 je Material und
   Produkt, Ampel (0–33 grün / 34–66 gelb / 67–100 rot), risikogekoppelter
   Zuschlag auf den Preis.
3. **Frühwarnung**: Polling von Open-Data- und (optional) kommerziellen SCRM-
   Quellen, Ereignis-Deduplizierung, In-App-Benachrichtigungen.
4. **Minimaler Betrieb**: keine externe Infrastruktur (kein Docker, PostgreSQL,
   Redis) — alles auf SQLite-Dateien.

## Status

- **Produktkalkulator** (`calculator`): vollständig implementiert.
- **Lieferrisiko-Intelligenz** (`supply_chain_risk`): vollständig implementiert
  (Provider-Abstraktion, Aggregation, Events, Benachrichtigungen, Jobs).
- **Weitere Module** (`Materialmanager`, `Produktionsplaner`, `Lagerverwaltung`,
  `Reporting`, `Lieferrisiko-Monitor`): als „Coming Soon“-Platzhalter angelegt.

## Technologiestapel

| Bereich | Technik |
|---|---|
| Sprache Backend | Ruby ≥ 3.3 |
| Framework | Rails 8 (API-only) |
| Datenbank | SQLite (3 Dateien: primary / cache / queue) |
| Caching | Solid Cache (SQLite-basiert) |
| Jobs | Solid Queue (Linux/macOS) bzw. `async` (Windows) |
| Sprache Frontend | TypeScript |
| UI-Framework | React 19 + Material UI |
| State/Server | Zustand (Client-State), TanStack Query (Server-State) |
| Build | Vite |
| Diagramme | Recharts |

## Einstiegspunkte

| Komponente | Datei |
|---|---|
| Backend-Boot | `api/config.ru` → `api/config/application.rb` |
| Rails-App-Klasse | `api/config/application.rb` (`GodEngine::Application`) |
| Frontend-Boot | `web/index.html` → `web/src/main.tsx` |
| App-Routing | `web/src/App.tsx` |
| Modul-Registry | `web/src/shared/module-registry.ts` |
| API-Routen | `api/config/routes.rb` |
| Dev-Start | `start-dev.ps1` / `start-dev.bat` / `stop-dev.ps1` |

## Mitgelieferte Demo-Daten

- Seed-Login: `admin@god-engine.local` / `GodEngine-Admin-123`.
- `db/seeds.rb` legt ein Demo-Projekt inkl. Risikodaten an.
- Rollen: `admin` (schreiben), `manager` (schreiben), `viewer` (nur lesen).

## Weiterführend

- Architektur → [02_architecture.md](02_architecture.md)
- Verzeichnisstruktur → [03_directory_structure.md](03_directory_structure.md)
- Fortschrittshistorie → `versioning.md` im Projektwurzelverzeichnis
