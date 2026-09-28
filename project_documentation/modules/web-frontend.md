# Modul: `web` (React-SPA)

## Rolle

Modulare Single-Page-App. Jedes Backend-Modul hat ein Frontend-Gegenstück unter
`web/src/apps/<modul>`; nicht geöffnete Module werden nicht geladen.

## Einstieg & Shell

- `src/main.tsx` — Root-Render (ThemeProvider, QueryProvider, BrowserRouter).
- `src/App.tsx` — Routen: `/` (HomePage), `/modules/:moduleId/*` (ModuleHost),
  Fallback. `ModuleHost` lädt das Modul lazy per `React.lazy` + `Suspense` + `ErrorBoundary`.
- `src/shell/AppShell.tsx` — Navigation, Login, Layout.
- `src/shared/module-registry.ts` — **die eine Stelle**, die alle Module kennt.

## Modul-Registry

```ts
interface ModuleDescriptor {
  id, title, description, icon, status: 'active' | 'coming_soon',
  component: LazyExoticComponent<ComponentType>
}
```

- `MODULES` listet 6 Module; `calculator` ist `active`, die übrigen `coming_soon`.
- `lazy(() => import('../apps/<modul>'))` → Vite emittiert pro Modul einen Chunk.

## Aktives Modul: `apps/calculator`

```
apps/calculator/
├── index.tsx                  # Projektauswahl, Tabs, Neu/Archiv/Löschen-Dialoge
├── api/                       # materials/pricing/costs/projects/risk/templates/notifications/queries
├── store/                     # calculator-store.ts, notification-store.ts (Zustand + persist)
├── tabs/                      # MaterialTab, MonthlyCostsTab, FixedCostsTab, PricingTab, DashboardTab
└── components/                # NotificationBell, MaterialRiskPanel
```

- `index.tsx` bündelt die fünf Tabs, Projekt-Dropdown mit „⋯“-Menü (Archivieren /
  Löschen mit Type-to-confirm), `NotificationBell`.
- `queries.ts` definiert zentrale TanStack-Query-Keys (Prefix `calculator`, je
  Projekt gescoped) und Mutation-Hooks, die ganze Tabs invalidieren.

## Shared-Schicht (`src/shared`)

| Bereich | Inhalt |
|---|---|
| `api/http.ts` | HTTP-Client (`request`, `http.get/post/...`, `authApi`, `jobsApi`, `costTemplatesApi`) |
| `api/types/*` | TypeScript-Typen (project, material, risk, costs, pricing, document, common) |
| `components/` | `RiskAmpel`, `ErrorBoundary`, `LoadingState`, `EmptyState`, `QueryError` |
| `hooks/` | `useAsync` |
| `lib/` | `money.ts` (Cent-Formatierung/-Parsing), `format.ts`, `errors.ts` |

## State-Management

- **Zustand** (Client-State, persistiert): `stores.ts` (`useAuthStore`, `useProjectStore`),
  `calculator-store.ts` (Tab, Projekt, Szenario, `focusMaterialId`),
  `notification-store.ts` (Panel offen, `lastSeenAt`).
- **TanStack Query** (Server-State): `query-client.tsx` (retry 1, staleTime 30 s,
  gcTime 300 s), alle Daten-Hooks in `apps/calculator/api/*`.

## Konfiguration

- `vite.config.ts` — Aliase `@apps`/`@shared`, Dev-Proxy `/api` → `:3000`,
  manuelle Chunks (`vendor-core`, `vendor-mui`, `vendor-charts`).
- Token-Speicherung: `localStorage` (`god-engine.auth.token`).
