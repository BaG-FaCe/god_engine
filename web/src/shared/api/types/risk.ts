import type { Ampel, RiskLevel, Timestamp, UUID } from './common';
import type { SanctionsStatus } from './project';

/** `free` = open data, `paid` = commercial SCRM/visibility vendor. */
export type ProviderTier = 'free' | 'paid' | 'internal';

export type ProviderCategory =
  | 'visibility'
  | 'risk_intelligence'
  | 'financial'
  | 'tracking'
  | 'customs'
  | 'open_data';

export type ProviderRunStatus = 'ok' | 'error' | 'never_run';

/** Provenance of a single assessment - required for liability traceability. */
export type AssessmentOrigin = 'automatic' | 'manual' | 'hybrid';

export type RiskDimensionKey =
  | 'logistics'
  | 'geopolitical'
  | 'weather'
  | 'financial'
  | 'compliance'
  | 'operational';

export type RiskDimensions = Record<RiskDimensionKey, number | null>;

export interface RiskAssessment {
  id: UUID;
  materialId: UUID;
  providerKey: string;
  providerName: string;
  providerTier: ProviderTier;
  riskScore: number;
  riskLevel: RiskLevel;
  dimensions: RiskDimensions;
  leadTimeVarianceDays: number | null;
  reason: string | null;
  origin: AssessmentOrigin;
  fetchedAt: Timestamp;
  expiresAt: Timestamp | null;
  stale: boolean;
  dataSources: string[];
  rawPayload: Record<string, unknown> | null;
}

/** Aggregated, product-relevant view of one material's risk. */
export interface MaterialRiskView {
  materialId: UUID;
  riskScore: number | null;
  riskLevel: RiskLevel | null;
  ampel: Ampel | 'unknown';
  dimensions: RiskDimensions;
  lastCheckedAt: Timestamp | null;
  hasAutomaticData: boolean;
  hasManualData: boolean;
  dataSources: string[];
  sanctionsStatus: SanctionsStatus;
  originCountry: string | null;
  hsCode: string | null;
  shippingRoute: string | null;
  alternativeSupplierCount: number;
  lastEvent: RiskEvent | null;
  assessments: RiskAssessment[];
  manualAssessment: {
    level: Ampel | null;
    note: string | null;
    assessedAt: Timestamp | null;
  } | null;
}

export type RiskEventType =
  | 'weather'
  | 'disaster'
  | 'sanction'
  | 'port_congestion'
  | 'price_spike'
  | 'customs'
  | 'supplier'
  | 'manual';

export type RiskEventSeverity = 'low' | 'medium' | 'high' | 'critical';

export interface RiskEvent {
  id: UUID;
  materialId: UUID | null;
  projectId: UUID | null;
  countryCode: string | null;
  eventType: RiskEventType;
  severity: RiskEventSeverity;
  title: string;
  description: string | null;
  source: string;
  sourceEventId: string | null;
  occurredAt: Timestamp;
  acknowledgedAt: Timestamp | null;
  metadata: Record<string, unknown> | null;
}

export interface RiskProviderDescriptor {
  key: string;
  name: string;
  tier: ProviderTier;
  category: ProviderCategory;
  description: string;
  requiresApiKey: boolean;
  configured: boolean;
  enabled: boolean;
  /** Cache TTL (minutes) applied to raw responses to protect rate limits. */
  cacheTtlMinutes: number;
  rateLimitPerMinute: number;
  dimensions: RiskDimensionKey[];
  docsUrl: string | null;
  lastRunAt: Timestamp | null;
  lastStatus: ProviderRunStatus | null;
}

export interface RiskProviderConfigPayload {
  apiKey?: string;
  enabled?: boolean;
  pollIntervalMinutes?: number;
  priority?: number;
  config?: Record<string, unknown>;
}

export interface RiskProviderConfig {
  id: UUID;
  projectId: UUID;
  providerKey: string;
  enabled: boolean;
  pollIntervalMinutes: number;
  priority: number;
  /** The key itself is never returned - only whether one is stored. */
  apiKeyPresent: boolean;
  apiKeyHint: string | null;
  config: Record<string, unknown>;
  lastRunAt: Timestamp | null;
}

export interface RiskManualAssessmentRequest {
  level: Ampel;
  note?: string | null;
  score?: number | null;
}

export interface RiskSummary {
  projectId: UUID;
  materialCount: number;
  averageRiskScore: number | null;
  criticalCount: number;
  elevatedCount: number;
  lowCount: number;
  unknownCount: number;
  distribution: Array<{ level: RiskLevel | 'unknown'; count: number }>;
  timeline: Array<{ date: string; averageRiskScore: number; eventCount: number }>;
  criticalMaterials: Array<{
    materialId: UUID;
    name: string;
    riskScore: number;
    riskLevel: RiskLevel;
    originCountry: string | null;
    lastCheckedAt: Timestamp | null;
  }>;
  recentEvents: RiskEvent[];
}

export interface RiskRefreshResult {
  materialId: UUID;
  jobId: string | null;
  queued: boolean;
  providerKeys: string[];
  message: string;
}

export interface RiskProviderProbeResult {
  providerKey: string;
  ok: boolean;
  latencyMs: number;
  sampleScore: number | null;
  message: string;
}