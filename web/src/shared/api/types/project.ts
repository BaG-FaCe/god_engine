import type { CurrencyCode, Timestamp, UUID } from './common';

/**
 * Project aggregate (the root of the `calculator` bounded context).
 * Mirrors `Project` + `db/migrate/..._create_calculator_core.rb`.
 */

export type ProjectStatus = 'draft' | 'active' | 'archived';

export type SanctionsStatus = 'clear' | 'flagged' | 'unknown' | 'pending';

export interface Project {
  id: UUID;
  name: string;
  description: string | null;
  status: ProjectStatus;
  taxRate: number;
  taxProfile: string;
  country: string;
  currency: CurrencyCode;
  unitsPerMonth: number;
  batchSize: number;
  targetMarginPct: number;
  riskSurchargePct: number | null;
  autoRiskSurcharge: boolean;
  riskRefreshIntervalHours: number;
  archivedAt: Timestamp | null;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ProjectUpsert {
  name: string;
  description?: string | null;
  status?: ProjectStatus;
  taxRate?: number;
  taxProfile?: string;
  country?: string;
  currency?: CurrencyCode;
  unitsPerMonth?: number;
  batchSize?: number;
  targetMarginPct?: number;
  riskSurchargePct?: number | null;
  autoRiskSurcharge?: boolean;
  riskRefreshIntervalHours?: number;
}

export interface Supplier {
  id: UUID;
  projectId: UUID;
  name: string;
  country: string | null;
  city: string | null;
  contactName: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  website: string | null;
  rating: number | null;
  isSingleSource: boolean;
  sanctionsStatus: SanctionsStatus;
  sanctionsCheckedAt: Timestamp | null;
  sanctionsDetails: Record<string, unknown> | null;
  notes: string | null;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface SupplierUpsert {
  name: string;
  country?: string | null;
  city?: string | null;
  contactName?: string | null;
  contactEmail?: string | null;
  contactPhone?: string | null;
  website?: string | null;
  rating?: number | null;
  isSingleSource?: boolean;
  notes?: string | null;
}
