import type { CurrencyCode, PeriodKey, Timestamp, UUID } from './common';

// ---------------------------------------------------------------------------
// Tab 2 - monthly costs
// ---------------------------------------------------------------------------

export type MonthlyCostCategory =
  | 'rent'
  | 'energy'
  | 'marketing'
  | 'insurance'
  | 'hosting'
  | 'leasing'
  | 'maintenance'
  | 'software'
  | 'other';

export interface MonthlyCost {
  id: UUID;
  projectId: UUID;
  category: MonthlyCostCategory;
  name: string;
  amountCents: number;
  currency: CurrencyCode;
  isRecurring: boolean;
  notes: string | null;
  position: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export type MonthlyCostUpsert = {
  category: MonthlyCostCategory;
  name: string;
  amountCents: number;
  currency?: CurrencyCode;
  isRecurring?: boolean;
  notes?: string | null;
  position?: number;
};

export interface SalesForecast {
  id: UUID;
  projectId: UUID;
  period: PeriodKey;
  forecastUnits: number;
  actualUnits: number | null;
  notes: string | null;
}

export interface SalesForecastUpsert {
  period: PeriodKey;
  forecastUnits: number;
  actualUnits?: number | null;
  notes?: string | null;
}

export interface SalesForecastAnalysis {
  rows: Array<{
    period: PeriodKey;
    forecastUnits: number;
    actualUnits: number | null;
    deviationUnits: number | null;
    deviationPct: number | null;
  }>;
  totals: {
    forecastUnits: number;
    actualUnits: number;
    deviationUnits: number;
    deviationPct: number | null;
    monthsWithActuals: number;
  };
  /** Profit / loss deviation between planned and actual volume. */
  profitDeviationCents: number | null;
  costPerUnitCents: number | null;
}

// ---------------------------------------------------------------------------
// Cost templates
// ---------------------------------------------------------------------------

export type CostTemplateKind = 'monthly_costs' | 'fixed_costs' | 'labor_costs' | 'mixed';

export interface CostTemplateItem {
  category: string;
  name: string;
  amountCents: number;
  isRecurring?: boolean;
  notes?: string | null;
  /** Labor-specific fields. */
  employee?: string;
  role?: string;
  hours?: number;
  hourlyRateCents?: number;
  allocationBasis?: string;
}

export interface CostTemplate {
  id: UUID;
  projectId: UUID | null;
  name: string;
  kind: CostTemplateKind;
  description: string | null;
  isGlobal: boolean;
  items: CostTemplateItem[];
  itemCount: number;
  totalCents: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface CostTemplateUpsert {
  name: string;
  kind: CostTemplateKind;
  description?: string | null;
  isGlobal?: boolean;
  items: CostTemplateItem[];
}

// ---------------------------------------------------------------------------
// Tab 3 - labor, fixed costs, overheads
// ---------------------------------------------------------------------------

export interface LaborCost {
  id: UUID;
  projectId: UUID;
  employee: string;
  role: string | null;
  department: string | null;
  hours: number;
  hourlyRateCents: number;
  /** `hours * hourlyRateCents`, computed server-side. */
  totalCents: number;
  notes: string | null;
}

export interface LaborCostUpsert {
  employee: string;
  role?: string | null;
  department?: string | null;
  hours: number;
  hourlyRateCents: number;
  notes?: string | null;
}

export type FixedCostAllocation = 'per_unit' | 'per_month' | 'per_batch';

export type FixedCostCategory =
  | 'labor'
  | 'development'
  | 'engineering'
  | 'quality_control'
  | 'packaging'
  | 'sales'
  | 'depreciation'
  | 'other';

export interface FixedCost {
  id: UUID;
  projectId: UUID;
  category: FixedCostCategory;
  name: string;
  amountCents: number;
  allocationBasis: FixedCostAllocation;
  notes: string | null;
  /** Amount actually rolled into the unit price, per unit. */
  perUnitCents: number;
}

export interface FixedCostUpsert {
  category: FixedCostCategory;
  name: string;
  amountCents: number;
  allocationBasis: FixedCostAllocation;
  notes?: string | null;
}

export type OverheadBase =
  | 'materials'
  | 'labor'
  | 'fixed_costs'
  | 'monthly_costs'
  | 'direct_cost'
  | 'subtotal';

export interface OverheadRule {
  id: UUID;
  projectId: UUID;
  key: string;
  name: string;
  /** Decimal fraction: `0.05` === 5 %. */
  percentage: number;
  base: OverheadBase;
  /** When true the percentage is proposed from the aggregated risk score. */
  autoFromRisk: boolean;
  enabled: boolean;
  position: number;
  notes: string | null;
  /** Risk-derived suggestion, only present when `autoFromRisk` is true. */
  suggestedPercentage: number | null;
}

export interface OverheadRuleUpsert {
  key: string;
  name: string;
  percentage: number;
  base: OverheadBase;
  autoFromRisk?: boolean;
  enabled?: boolean;
  position?: number;
  notes?: string | null;
}