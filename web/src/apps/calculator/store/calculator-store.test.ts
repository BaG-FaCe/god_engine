import { beforeEach, describe, expect, it } from 'vitest';
import { CALCULATOR_TABS, useCalculatorStore } from './calculator-store';

describe('calculator store', () => {
  beforeEach(() => {
    useCalculatorStore.setState({ projectId: null, scenarioId: null, tab: 'materials' });
  });

  it('exposes the five spec tabs', () => {
    expect(CALCULATOR_TABS.map((tab) => tab.key)).toEqual([
      'materials', 'monthly', 'fixed', 'pricing', 'dashboard',
    ]);
  });

  it('tracks project and tab selection', () => {
    useCalculatorStore.getState().selectProject('p1');
    useCalculatorStore.getState().setTab('pricing');
    const state = useCalculatorStore.getState();
    expect(state.projectId).toBe('p1');
    expect(state.tab).toBe('pricing');
    expect(state.tab).not.toBe('materials');
  });
});
