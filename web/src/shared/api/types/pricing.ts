import type { PeriodKey, Timestamp, UUID } from './common';
import type { RiskLevel } from './common';
import type { RiskEvent, RiskSummary } from './risk';

// ---------------------------------------------------------------------------
// Tab 4 - price calculation
// ---------------------------------------------------------------------------

export interface PricingInputs {
  unitsPerMonth: number;
  batchSize: number;
  taxRate: number;
  /** Manual override of the risk surcharge (decimal fraction). */
  riskSurchargePct: number | null;
  /** When true the surcharge is derived from the aggregated risk score. */
  autoRiskSurcharge: boolean;
  /** When true, refundable input tax is ignored (Kleinunternehmer). */
  taxExempt?: boolean;
}

export interface CostLineDetail {
  label: string;
  totalCents: number;
  perUnitCents: number;
}

export type CostLineCategory =
  | 'material'
  | 'monthly'
  | 'labor'
  | 'fixed'
  | 'overhead'
  | 'risk'
  | 'tax';

export interface CostLine {
  key: string;
  label: string;
  totalCents: number;
  perUnitCents: number;
  /** Share of the net total cost, decimal fraction. */
  share: number;
  category: CostLineCategory;
  detail: CostLineDetail[];
}

export interface PricingResult {
  inputs: PricingInputs;
  lines: CostLine[];
  totals: {
    materialCostCents: number;
    monthlyCostCents: number;
    laborCostCents: number;
    fixedCostCents: number;
    directCostCents: number;
    overheadCents: number;
    riskSurchargeCents: number;
    totalCostNetCents: number;
    taxCents: number;
    totalCostGrossCents: number;
    perUnitNetCents: number;
    perUnitGrossCents: number;
  };
  risk: {
    aggregateScore: number | null;
    level: RiskLevel | null;
    suggestedSurchargePct: number;
    appliedSurchargePct: number;
    criticalMaterialCount: number;
    materialCount: number;
  };
  taxes: {
    taxRate: number;
    taxProfile: string;
    country: string;
  };
}

export interface PriceOptimizationRequest {
  targetPriceCents: number;
  targetPriceIncludesTax: boolean;
  unitsPerMonth: number;
  batchSize?: number;
}

export interface PriceOptimizationResult {
  target: {
    priceCents: number;
    includesTax: boolean;
    netCents: number;
    grossCents: number;
  };
  calculated: {
    netCents: number;
    grossCents: number;
  };
  profit: {
    perUnitNetCents: number;
    perUnitGrossCents: number;
    marginPct: number;
    markupPct: number;
    contributionMarginPerUnitCents: number;
    contributionMarginRatioPct: number;
  };
  revenue: {
    monthlyNetCents: number;
    monthlyGrossCents: number;
  };
  monthlyProfit: {
    netCents: number;
    marginPct: number;
  };
  breakEven: {
    unitsPerMonth: number | null;
    revenueNetCents: number | null;
    feasible: boolean;
  };
  warnings: string[];
}

export interface PricingScenario {
  id: UUID;
  projectId: UUID;
  name: string;
  targetPriceCents: number | null;
  targetPriceIncludesTax: boolean;
  unitsPerMonth: number;
  batchSize: number;
  isActive: boolean;
  resultSnapshot: PricingResult | null;
  notes: string | null;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface PricingScenarioUpsert {
  name: string;
  targetPriceCents?: number | null;
  targetPriceIncludesTax?: boolean;
  unitsPerMonth: number;
  batchSize?: number;
  isActive?: boolean;
  notes?: string | null;
}

// ---------------------------------------------------------------------------
// Tab 5 - dashboard
// ---------------------------------------------------------------------------

export interface DashboardKpis {
  materialCostCents: number;
  monthlyCostCents: number;
  fixedCostCents: number;
  laborCostCents: number;
  overheadCents: number;
  riskSurchargeCents: number;
  totalCostNetCents: number;
  totalCostGrossCents: number;
  perUnitNetCents: number;
  perUnitGrossCents: number;
  sellingPriceNetCents: number;
  sellingPriceGrossCents: number;
  profitPerUnitNetCents: number;
  profitMarginPct: number;
  revenueMonthlyNetCents: number;
  monthlyProfitNetCents: number;
  breakEvenUnits: number | null;
  unitsPerMonth: number;
  criticalRiskCount: number;
  averageRiskScore: number | null;
  materialCount: number;
  riskLevel: RiskLevel | null;
}

export interface DashboardResponse {
  projectId: UUID;
  kpis: DashboardKpis;
  costDistribution: Array<{ key: string; label: string; totalCents: number; share: number }>;
  profitTrend: Array<{
    period: PeriodKey;
    revenueNetCents: number;
    costNetCents: number;
    profitNetCents: number;
    marginPct: number;
  }>;
  forecastVsActual: Array<{
    period: PeriodKey;
    forecastUnits: number;
    actualUnits: number | null;
  }>;
  riskDistribution: Array<{ level: RiskLevel | 'unknown'; count: number }>;
  riskTimeline: RiskSummary['timeline'];
  riskEvents: RiskEvent[];
  criticalRiskMaterials: RiskSummary['criticalMaterials'];
}