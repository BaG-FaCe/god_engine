import { describe, expect, it } from 'vitest';
import {
  formatAmount, formatMoney, formatPercent, grossToNetCents, netToGrossCents,
  parseAmountToCents,
} from './money';

describe('money helpers', () => {
  it('formats cents as EUR', () => {
    expect(formatMoney(2999)).toContain('29,99');
    expect(formatMoney(0)).toContain('0,00');
    expect(formatMoney(null)).toBe('–');
  });

  it('formats amounts without currency symbol', () => {
    expect(formatAmount(1234)).toBe('12,34');
  });

  it('formats percent fractions', () => {
    expect(formatPercent(0.19)).toContain('19');
    expect(formatPercent(null)).toBe('–');
  });

  it('parses German decimal input', () => {
    expect(parseAmountToCents('29,99')).toBe(2999);
    expect(parseAmountToCents('1234.56')).toBe(123456);
    expect(parseAmountToCents('1.234,56')).toBe(123456);
    expect(parseAmountToCents('')).toBeNull();
  });

  it('converts net and gross using the tax rate', () => {
    expect(netToGrossCents(10000, 0.19)).toBe(11900);
    expect(grossToNetCents(11900, 0.19)).toBe(10000);
  });
});
