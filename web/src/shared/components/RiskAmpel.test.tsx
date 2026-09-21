import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { RISK_THRESHOLDS, ampelForLevel, levelForScore, RiskAmpel } from './RiskAmpel';

describe('RiskAmpel threshold logic', () => {
  it('maps scores to the spec traffic light bands', () => {
    expect(RISK_THRESHOLDS).toEqual({ medium: 34, high: 67 });
    expect(levelForScore(0)).toBe('low');
    expect(levelForScore(23)).toBe('low');
    expect(levelForScore(34)).toBe('medium');
    expect(levelForScore(66)).toBe('medium');
    expect(levelForScore(67)).toBe('high');
    expect(levelForScore(100)).toBe('high');
    expect(levelForScore(null)).toBeNull();
  });

  it('maps levels to ampel colours', () => {
    expect(ampelForLevel('low')).toBe('green');
    expect(ampelForLevel('medium')).toBe('yellow');
    expect(ampelForLevel('high')).toBe('red');
    expect(ampelForLevel('unknown')).toBe('unknown');
  });
});

describe('RiskAmpel component', () => {
  it('renders the score variant', () => {
    render(<RiskAmpel level="low" score={23} />);
    expect(screen.getByText(/Niedrig \(23\)/)).toBeInTheDocument();
  });

  it('renders unknown when no data exists', () => {
    render(<RiskAmpel level={null} score={null} />);
    expect(screen.getByText(/Unbekannt/)).toBeInTheDocument();
  });
});
