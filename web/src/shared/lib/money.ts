/**
 * Money helpers.
 *
 * The API transports every monetary value as **integer cents**. Rounding is
 * done half-up on integers (`Math.round`) which matches the server-side
 * `Rational#round(:half_up)` behaviour used by the Ruby calculators, so the SPA
 * never disagrees with the backend about a price.
 */

const DEFAULT_LOCALE = 'de-DE';

export function centsToFloat(cents: number): number {
  return cents / 100;
}

export function floatToCents(value: number): number {
  return Math.round(value * 100);
}

export function roundCents(value: number): number {
  return Math.round(value);
}

/** `1234` -> `"12,34 €"` */
export function formatMoney(
  cents: number | null | undefined,
  currency = 'EUR',
  locale = DEFAULT_LOCALE,
): string {
  if (cents === null || cents === undefined || Number.isNaN(cents)) return '–';
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(centsToFloat(cents));
}

/** `1234` -> `"12,34"` (no currency symbol, for inputs and tables). */
export function formatAmount(cents: number | null | undefined, locale = DEFAULT_LOCALE): string {
  if (cents === null || cents === undefined || Number.isNaN(cents)) return '';
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(centsToFloat(cents));
}

/** `0.195` -> `"19,50 %"` */
export function formatPercent(
  fraction: number | null | undefined,
  locale = DEFAULT_LOCALE,
  digits = 2,
): string {
  if (fraction === null || fraction === undefined || Number.isNaN(fraction)) return '–';
  return new Intl.NumberFormat(locale, {
    style: 'percent',
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(fraction);
}

/** Parses German or English decimal input (`"1.234,56"`, `"1234.56"`). */
export function parseAmountToCents(input: string): number | null {
  if (input === null || input === undefined) return null;
  const trimmed = String(input).trim().replace(/[€\s]/g, '');
  if (trimmed === '') return null;

  const hasComma = trimmed.includes(',');
  const hasDot = trimmed.includes('.');

  let normalised = trimmed;
  if (hasComma && hasDot) {
    // Whichever separator appears last is the decimal separator.
    normalised =
      trimmed.lastIndexOf(',') > trimmed.lastIndexOf('.')
        ? trimmed.replace(/\./g, '').replace(',', '.')
        : trimmed.replace(/,/g, '');
  } else if (hasComma) {
    normalised = trimmed.replace(',', '.');
  }

  const parsed = Number.parseFloat(normalised);
  if (Number.isNaN(parsed)) return null;
  return Math.round(parsed * 100);
}

/** Gross-from-net using the project tax rate (a decimal fraction). */
export function netToGrossCents(netCents: number, taxRate: number): number {
  return Math.round(netCents * (1 + taxRate));
}

/** Net-from-gross using the project tax rate (a decimal fraction). */
export function grossToNetCents(grossCents: number, taxRate: number): number {
  return Math.round(grossCents / (1 + taxRate));
}

export function marginPct(priceCents: number, costCents: number): number | null {
  if (priceCents === 0) return null;
  return (priceCents - costCents) / priceCents;
}