import { Chip, Tooltip, type ChipProps } from '@mui/material';
import type { Ampel, RiskLevel } from '../api/types/common';

/**
 * Traffic light used on material cards, tables and dashboard tiles.
 *
 * The thresholds are the ones the backend enforces (`RiskSurchargePolicy`:
 * 0-33 low, 34-66 medium, 67-100 high), so client and server can never disagree
 * about what "red" means.
 */
export const RISK_THRESHOLDS = { medium: 34, high: 67 } as const;

export function levelForScore(score: number | null | undefined): RiskLevel | null {
  if (score === null || score === undefined || Number.isNaN(score)) return null;
  if (score < RISK_THRESHOLDS.medium) return 'low';
  if (score < RISK_THRESHOLDS.high) return 'medium';
  return 'high';
}

export function ampelForLevel(level: RiskLevel | string | null | undefined): Ampel | 'unknown' {
  switch (level) {
    case 'low':
      return 'green';
    case 'medium':
      return 'yellow';
    case 'high':
      return 'red';
    default:
      return 'unknown';
  }
}

export const RISK_LABELS: Record<string, string> = {
  low: 'Niedrig',
  medium: 'Mittel',
  high: 'Hoch',
  unknown: 'Unbekannt',
};

export const AMPEL_SYMBOLS: Record<string, string> = {
  green: '🟢',
  yellow: '',
  red: '🔴',
  unknown: '⚪',
};

export interface RiskAmpelProps extends Omit<ChipProps, 'label' | 'color'> {
  level?: RiskLevel | string | null;
  score?: number | null;
  /** Renders as "🟢 Lieferrisiko: Niedrig (23)". */
  showScore?: boolean;
  tooltip?: string;
}

/** The risk traffic light itself: colour, symbol, label and score. */
export function RiskAmpel({ level, score, showScore = true, tooltip, ...rest }: RiskAmpelProps) {
  const resolvedLevel = level ?? levelForScore(score ?? null);
  const ampel = ampelForLevel(resolvedLevel);
  const label = RISK_LABELS[resolvedLevel ?? 'unknown'] ?? RISK_LABELS.unknown;
  const color: ChipProps['color'] =
    ampel === 'green' ? 'success' : ampel === 'yellow' ? 'warning' : ampel === 'red' ? 'error' : 'default';

  const text = showScore && score !== null && score !== undefined
    ? `${AMPEL_SYMBOLS[ampel]} Lieferrisiko: ${label} (${score})`
    : `${AMPEL_SYMBOLS[ampel]} Lieferrisiko: ${label}`;

  const chip = (
    <Chip size="small" variant="outlined" color={color} label={text} {...rest} />
  );

  return tooltip ? <Tooltip title={tooltip}>{chip}</Tooltip> : chip;
}