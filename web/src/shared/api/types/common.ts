/**
 * Shared primitive types used by every module.
 *
 * Kept in one file so the REST contract (Rails serializers) and the SPA stay
 * in sync: change a literal here and TypeScript forces every consumer to follow.
 */

/** UUID string primary key (generated via `SecureRandom.uuid` on the backend). */
export type UUID = string;

/** ISO-8601 timestamp (`2026-09-15T08:00:00Z`). */
export type Timestamp = string;

/** ISO-3166 alpha-2 country code (`DE`) or ISO-4217 currency (`EUR`). */
export type CurrencyCode = string;

/** Aggregated risk traffic light used by the material card and dashboard. */
export type RiskLevel = 'low' | 'medium' | 'high';

/** Manually maintained traffic light (Fachanwender-Ampel). */
export type Ampel = 'green' | 'yellow' | 'red';

/** Monthly period key (`YYYY-MM`) used by forecasts and the dashboard. */
export type PeriodKey = string;

/** Canonical API error envelope returned by every Rails endpoint. */
export interface ApiErrorPayload {
  error: {
    code: string;
    message: string;
    details?: FieldError[] | Record<string, string[] | string>;
  };
}

export interface FieldError {
  field: string;
  message: string;
}

/** Paginated collection envelope (`?page=&per_page=&q=`). */
export interface Paginated<T> {
  data: T[];
  meta: {
    page: number;
    perPage: number;
    total: number;
    totalPages: number;
  };
}

/** Export formats supported by `GET .../export?format=`. */
export type ExportFormat = 'json' | 'csv' | 'xlsx' | 'pdf';

/** Notification lifecycle status (mirrors RiskNotification). */
export type NotificationStatus = 'unread' | 'read' | 'acknowledged' | 'dismissed';

/** Minimal notification view used by the in-app notification bell and dropdown. */
export interface RiskNotificationSummary {
  id: UUID;
  projectId: UUID | null;
  materialId: UUID | null;
  kind: 'risk_event' | 'critical_material';
  severity: 'low' | 'medium' | 'high' | 'critical';
  title: string;
  readAt: Timestamp | null;
  acknowledgedAt: Timestamp | null;
  dismissedAt: Timestamp | null;
  createdAt: Timestamp;
}

/** JWT login request / response. */
export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthUser {
  id: UUID;
  email: string;
  name: string;
  role: 'admin' | 'manager' | 'viewer';
  active: boolean;
  lastLoginAt: Timestamp | null;
}

export interface LoginResponse {
  token: string;
  user: AuthUser;
}
