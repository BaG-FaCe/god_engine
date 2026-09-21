import type {
  CostTemplateItem,
  FixedCostAllocation,
  FixedCostCategory,
  MonthlyCostCategory,
  OverheadBase,
} from './costs';
import type { CurrencyCode, RiskLevel, Timestamp } from './common';
import type { LeadTimeUnit, MaterialType } from './material';
import type { SanctionsStatus } from './project';
import type { RiskEventType, ProviderTier } from './risk';

/**
 * Portable project document.
 *
 * This is the on-disk / import / export representation of a complete project
 * (deliverable 3 of the specification). It is intentionally decoupled from the
 * relational schema so that files stay readable and forward compatible - the
 * `schemaVersion` gates migrations on import.
 */
export const PROJECT_DOCUMENT_SCHEMA_VERSION = '1.0';

export interface ProjectDocumentRisk {
  originCountry: string | null;
  shippingRoute: string | null;
  hsCode: string | null;
  transportMode: string | null;
  riskScore: number | null;
  riskLevel: RiskLevel | null;
  leadTimeVarianceDays: number | null;
  lastCheckedAt: Timestamp | null;
  dataSources: string[];
  sanctionsStatus?: SanctionsStatus;
  manuallyAssessed?: boolean;
  alternativeSuppliers?: Array<{
    name: string;
    country: string | null;
    priority: number;
    leadTimeDays: number | null;
    unitPriceCents: number | null;
    notes: string | null;
  }>;
}

export interface ProjectDocumentMaterial {
  id?: string;
  name: string;
  materialType?: MaterialType;
  supplier?: string | null;
  articleNumber?: string | null;
  description?: string | null;
  unit?: string;
  unitPriceCents?: number;
  priceIncludesTax?: boolean;
  quantity?: number;
  minOrderQuantity?: number;
  leadTimeDays?: number;
  leadTime?: { value: number; unit: LeadTimeUnit };
  storageLocation?: string | null;
  deliveryAddress?: string | null;
  stockQuantity?: number;
  reorderLevel?: number;
  supplyChainRisk?: ProjectDocumentRisk;
  documents?: Array<{ kind: string; name: string; url: string }>;
}

export interface ProjectDocument {
  schemaVersion: string;
  projectName: string;
  exportedAt?: Timestamp;
  country?: string;
  currency?: CurrencyCode;
  taxRate: number;
  taxProfile?: string;
  materials: ProjectDocumentMaterial[];
  suppliers?: Array<{
    name: string;
    country?: string | null;
    city?: string | null;
    rating?: number | null;
    isSingleSource?: boolean;
    sanctionsStatus?: SanctionsStatus;
  }>;
  monthlyCosts: Array<{
    category?: MonthlyCostCategory;
    name: string;
    amountCents: number;
    isRecurring?: boolean;
    notes?: string | null;
  }>;
  fixedCosts: Array<{
    category?: FixedCostCategory;
    name: string;
    amountCents: number;
    allocationBasis?: FixedCostAllocation;
    notes?: string | null;
  }>;
  laborCosts?: Array<{
    employee: string;
    role?: string | null;
    department?: string | null;
    hours: number;
    hourlyRateCents: number;
    notes?: string | null;
  }>;
  overheadRules?: Array<{
    key: string;
    name: string;
    percentage: number;
    base: OverheadBase;
    autoFromRisk?: boolean;
    enabled?: boolean;
  }>;
  salesForecasts?: Array<{
    period: string;
    forecastUnits: number;
    actualUnits: number | null;
  }>;
  pricing: {
    unitsPerMonth?: number;
    batchSize?: number;
    targetPriceCents?: number | null;
    targetPriceIncludesTax?: boolean;
    riskSurchargePct?: number | null;
    autoRiskSurcharge?: boolean;
    scenarios?: Array<{
      name: string;
      targetPriceCents: number | null;
      targetPriceIncludesTax: boolean;
      unitsPerMonth: number;
      isActive?: boolean;
    }>;
  };
  riskContext?: {
    generatedAt: Timestamp;
    providers: Array<{ key: string; tier: ProviderTier }>;
    events: Array<{
      materialId: string | null;
      eventType: RiskEventType;
      severity: string;
      title: string;
      occurredAt: Timestamp;
      source: string;
    }>;
  };
  templates?: Array<{
    name: string;
    kind: string;
    items: CostTemplateItem[];
  }>;
}