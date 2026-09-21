import type { Ampel, CurrencyCode, RiskLevel, Timestamp, UUID } from './common';

export type MaterialType =
  | 'raw_material'
  | 'component'
  | 'fastener'
  | 'electronics'
  | 'packaging'
  | 'consumable'
  | 'service'
  | 'other';

export type LeadTimeUnit = 'days' | 'weeks' | 'months';

export type TransportMode = 'sea' | 'air' | 'road' | 'rail' | 'multimodal';

export type FreightCostTrend = 'rising' | 'stable' | 'falling' | 'unknown';

export interface AlternativeSupplier {
  id: UUID;
  materialId: UUID;
  supplierId: UUID | null;
  name: string;
  country: string | null;
  /** Lower number wins. */
  priority: number;
  leadTimeDays: number | null;
  unitPriceCents: number | null;
  notes: string | null;
}

export type AlternativeSupplierUpsert = Omit<AlternativeSupplier, 'id' | 'materialId'>;

export type DocumentKind = 'datasheet' | 'cad' | 'certificate' | 'image' | 'other';

export interface MaterialDocument {
  id: UUID;
  materialId: UUID;
  kind: DocumentKind;
  name: string;
  url: string;
  byteSize: number | null;
  contentType: string | null;
  createdAt: Timestamp;
}

/**
 * Manually maintained supply-chain risk fields. Every field is optional: they
 * may be entered by hand or populated from an external provider through the
 * `supply-chain-risk` bounded context.
 */
export interface MaterialRiskProfile {
  originCountry: string | null;
  hsCode: string | null;
  shippingRoute: string | null;
  transportMode: TransportMode | null;
  isSingleSource: boolean;
  historicalDelayCount: number | null;
  historicalDelayDays: number | null;
  lastDisruptionAt: Timestamp | null;
  lastDisruptionCause: string | null;
  lastDisruptionNote: string | null;
  freightCostTrend: FreightCostTrend;
  manualRiskLevel: Ampel | null;
  manualRiskNote: string | null;
}

export interface Material {
  id: UUID;
  projectId: UUID;
  name: string;
  materialType: MaterialType;
  supplierId: UUID | null;
  supplierName: string | null;
  articleNumber: string | null;
  description: string | null;
  imageUrl: string | null;
  unit: string;
  unitPriceCents: number;
  priceIncludesTax: boolean;
  quantity: number;
  minOrderQuantity: number;
  leadTimeValue: number;
  leadTimeUnit: LeadTimeUnit;
  /** Normalised lead time in days. */
  leadTimeDays: number;
  storageLocation: string | null;
  deliveryAddress: string | null;
  currency: CurrencyCode;
  stockQuantity: number;
  reorderLevel: number;
  position: number;
  /** Denormalised score of the newest assessment (0-100). */
  riskScore: number | null;
  riskLevel: RiskLevel | null;
  lastRiskCheckedAt: Timestamp | null;
  riskProfile: MaterialRiskProfile | null;
  alternativeSuppliers: AlternativeSupplier[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export type MaterialUpsert = {
  name: string;
  materialType?: MaterialType;
  supplierId?: UUID | null;
  articleNumber?: string | null;
  description?: string | null;
  imageUrl?: string | null;
  unit?: string;
  unitPriceCents?: number;
  priceIncludesTax?: boolean;
  quantity?: number;
  minOrderQuantity?: number;
  leadTimeValue?: number;
  leadTimeUnit?: LeadTimeUnit;
  storageLocation?: string | null;
  deliveryAddress?: string | null;
  currency?: CurrencyCode;
  stockQuantity?: number;
  reorderLevel?: number;
  position?: number;
  riskProfile?: Partial<MaterialRiskProfile> | null;
};

export interface LeadTimeAnalysis {
  materialCount: number;
  averagePlannedDays: number | null;
  averageActualDays: number | null;
  longestDays: number | null;
  longestMaterial: { id: UUID; name: string } | null;
  criticalMaterials: Array<{ id: UUID; name: string; leadTimeDays: number }>;
  varianceDays: number | null;
  riskWeightedAverageDays: number | null;
  /** Only the long-lead materials, used by the planner. */
  buckets: Array<{ label: string; count: number; thresholdDays: number }>;
}

export interface MaterialCard {
  material: Material;
  supplier: Record<string, unknown> | null;
  logistics: {
    leadTimeDays: number;
    plannedLeadTimeDays: number;
    actualLeadTimeDays: number | null;
    leadTimeVarianceDays: number | null;
    riskWeightedLeadTimeDays: number;
    deliveryAddress: string | null;
  };
  purchasing: {
    unitPriceNetCents: number;
    unitPriceGrossCents: number;
    minOrderQuantity: number;
    totalValueNetCents: number;
  };
  stock: {
    stockQuantity: number;
    reorderLevel: number;
    belowReorderLevel: boolean;
  };
  risk: import('./risk').MaterialRiskView;
  documents: MaterialDocument[];
}