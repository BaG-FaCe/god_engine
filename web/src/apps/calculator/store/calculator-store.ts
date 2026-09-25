import { create } from 'zustand';
import { persist } from 'zustand/middleware';

/**
 * Module-local UI state for the calculator.
 *
 * Everything the *server* owns (projects, materials, scenarios) lives in
 * TanStack Query; this store only holds the cross-tab UI selections that must
 * survive reloads (active project, active scenario, last opened tab).
 */
export interface CalculatorState {
  projectId: string | null;
  scenarioId: string | null;
  tab: CalculatorTabKey;
  /** Deep-link target set by the notification bell (which material card to open). */
  focusMaterialId: string | null;
  selectProject: (projectId: string | null) => void;
  selectScenario: (scenarioId: string | null) => void;
  setTab: (tab: CalculatorTabKey) => void;
  focusMaterial: (materialId: string | null) => void;
}

export type CalculatorTabKey = 'materials' | 'monthly' | 'fixed' | 'pricing' | 'dashboard';

export const CALCULATOR_TABS: Array<{ key: CalculatorTabKey; label: string }> = [
  { key: 'materials', label: 'Materialkosten' },
  { key: 'monthly', label: 'Monatliche Kosten' },
  { key: 'fixed', label: 'Fix- & Gemeinkosten' },
  { key: 'pricing', label: 'Preiskalkulation' },
  { key: 'dashboard', label: 'Dashboard' },
];

export const useCalculatorStore = create<CalculatorState>()(
  persist(
    (set) => ({
      projectId: null,
      scenarioId: null,
      tab: 'materials',
      focusMaterialId: null,
      selectProject: (projectId) => set({ projectId }),
      selectScenario: (scenarioId) => set({ scenarioId }),
      setTab: (tab) => set({ tab }),
      focusMaterial: (focusMaterialId) => set({ focusMaterialId }),
    }),
    { name: 'god-engine.calculator' },
  ),
);
