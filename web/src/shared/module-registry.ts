import { lazy, type ComponentType, type LazyExoticComponent } from 'react';

/** Lifecycle of a module inside the modular monolith. */
export type ModuleStatus = 'active' | 'coming_soon';

export interface ModuleDescriptor {
  /** Route segment: `/modules/<id>`. */
  id: string;
  title: string;
  description: string;
  /** MUI icon name rendered as an emoji-free glyph label. */
  icon: string;
  status: ModuleStatus;
  /**
   * Lazy component. Vite emits one chunk per module, so a module that is never
   * opened is never downloaded - the core requirement of the platform.
   */
  component: LazyExoticComponent<ComponentType>;
}

/**
 * The one place that knows which modules exist.
 *
 * Adding a module = one entry here plus its folder under `src/apps/`. Nothing
 * else in the shell has to change, and the backend mirror (`app/modules/`) keeps
 * the same names so routes, contexts and tests line up.
 */
export const MODULES: ModuleDescriptor[] = [
  {
    id: 'calculator',
    title: 'Produktkalkulator',
    description:
      'Material-, Monats-, Fix- und Arbeitskosten erfassen, Verkaufspreis kalkulieren und gegen Lieferrisiken absichern.',
    icon: 'calculate',
    status: 'active',
    component: lazy(() => import('../apps/calculator')),
  },
  {
    id: 'material-management',
    title: 'Materialmanager',
    description: 'Materialstammdaten, Lieferanten und Dokumente zentral pflegen (geplant).',
    icon: 'inventory_2',
    status: 'coming_soon',
    component: lazy(() => import('../apps/material-management')),
  },
  {
    id: 'production-planner',
    title: 'Produktionsplaner',
    description: 'Fertigungsreihenfolge auf Basis von Lieferzeiten und Risikogewichten (geplant).',
    icon: 'precision_manufacturing',
    status: 'coming_soon',
    component: lazy(() => import('../apps/production-planner')),
  },
  {
    id: 'inventory',
    title: 'Lagerverwaltung',
    description: 'Bestände, Meldebestände und Wiederbeschaffung (geplant).',
    icon: 'warehouse',
    status: 'coming_soon',
    component: lazy(() => import('../apps/inventory')),
  },
  {
    id: 'reporting',
    title: 'Reporting',
    description: 'Auswertungen, Exporte und Periodenvergleiche (geplant).',
    icon: 'insights',
    status: 'coming_soon',
    component: lazy(() => import('../apps/reporting')),
  },
  {
    id: 'supply-chain-risk',
    title: 'Lieferrisiko-Monitor',
    description:
      'Eigenständige Sicht auf Provider-Abdeckung, Frühwarnereignisse und Risikoverlauf (geplant).',
    icon: 'crisis_alert',
    status: 'coming_soon',
    component: lazy(() => import('../apps/supply-chain-risk')),
  },
];

export function findModule(id: string | undefined): ModuleDescriptor | undefined {
  return MODULES.find((module) => module.id === id);
}