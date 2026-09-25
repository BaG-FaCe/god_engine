import { http } from '../../../shared/api/http';
import type {
  MaterialRiskView,
  Paginated,
  RiskEvent,
  RiskManualAssessmentRequest,
  RiskProviderConfigPayload,
  RiskProviderDescriptor,
  RiskProviderProbeResult,
  RiskRefreshResult,
  RiskSummary,
} from '../../../shared/api/types';
import type { UUID, Timestamp } from '../../../shared/api/types/common';
import type { RiskEventSeverity } from '../../../shared/api/types/risk';

export const riskApi = {
  assessment: (materialId: string) =>
    http.get<MaterialRiskView>(`/materials/${materialId}/risk_assessment`),
  eventsForMaterial: (materialId: string) =>
    http.get<{ data: RiskEvent[] }>(`/materials/${materialId}/risk_events`),
  manual: (materialId: string, body: RiskManualAssessmentRequest) =>
    http.post<MaterialRiskView>(`/materials/${materialId}/risk_assessment/manual`, body),
  refresh: (materialId: string) =>
    http.post<RiskRefreshResult>(`/materials/${materialId}/risk_assessment/refresh`),
  card: (materialId: string) =>
    http.get<import('../../../shared/api/types').MaterialCard>(`/materials/${materialId}/card`),
  providers: (projectId?: string) =>
    http.get<{ data: RiskProviderDescriptor[] }>(
      '/risk_providers',
      projectId ? { projectId } : undefined,
    ),
  configureProvider: (key: string, projectId: string | null, body: RiskProviderConfigPayload) =>
    http.post<{ providerKey: string; apiKeyPresent: boolean; enabled: boolean }>(
      `/risk_providers/${key}/configure`,
      { ...body, projectId },
    ),
  probeProvider: (key: string) =>
    http.post<RiskProviderProbeResult>(`/risk_providers/${key}/probe`),
  summary: (projectId: string) =>
    http.get<RiskSummary>(`/projects/${projectId}/risk_summary`),
  projectEvents: (projectId: string) =>
    http.get<{ data: RiskEvent[] }>(`/projects/${projectId}/risk_events`),
  allEvents: () => http.get<{ data: RiskEvent[] }>('/risk_events'),
  acknowledgeEvent: (id: string) =>
    http.patch<RiskEvent>(`/risk_events/${id}`, { acknowledged: true }),

  // In-app notifications (risk_notifications_controller + notification UI hooks)
  notifications: (projectId?: string) =>
    http.get<{ data: RiskNotification[]; meta: NotificationMeta }>(
      '/risk_notifications',
      (projectId ? { projectId: projectId } : undefined),
    ),
  acknowledgeNotification: (id: string) =>
    http.post<{ notification: RiskNotification; meta: NotificationMeta }>(
      `/risk_notifications/${id}/acknowledge`,
    ),
  dismissNotification: (id: string) =>
    http.post<{ notification: RiskNotification; meta: NotificationMeta }>(
      `/risk_notifications/${id}/dismiss`,
    ),
  readNotification: (id: string) =>
    http.patch<{ notification: RiskNotification; meta: NotificationMeta }>(
      `/risk_notifications/${id}/read`,
    ),
  readAllNotifications: (projectId?: string) =>
    http.post<{ updated: number; meta: NotificationMeta }>(
      '/risk_notifications/read_all',
      projectId ? { projectId } : undefined,
    ),
};
export type { Paginated };

/** Counts returned alongside the notification list (see RiskNotificationsController#meta_for). */
export interface NotificationMeta {
  unreadCount: number;
  openCount: number;
  acknowledgedCount: number;
  dismissedCount: number;
}

export type NotificationStatus = 'unread' | 'read' | 'acknowledged' | 'dismissed';

/** Notification-level types used by the in-app notification bell/dropdown. */
export interface RiskNotification {
  id: UUID;
  projectId: UUID | null;
  materialId: UUID | null;
  riskEventId: UUID | null;
  kind: 'risk_event' | 'critical_material';
  severity: RiskEventSeverity;
  title: string;
  body: string | null;
  payload: Record<string, unknown> | null;
  status: NotificationStatus;
  readAt: Timestamp | null;
  acknowledgedAt: Timestamp | null;
  acknowledgedBy: UUID | null;
  dismissedAt: Timestamp | null;
  dismissedBy: UUID | null;
  createdAt: Timestamp;
}

/** Lightweight shape kept in the Zustand notification store. */
export interface NotificationStoreEntry {
  id: UUID;
  projectId: UUID | null;
  materialId: UUID | null;
  kind: 'risk_event' | 'critical_material';
  severity: RiskEventSeverity;
  title: string;
  body: string | null;
  payload: Record<string, unknown> | null;
  status: NotificationStatus;
  readAt: Timestamp | null;
  createdAt: Timestamp;
  unread: boolean;
  riskEvent?: RiskEvent | null;
}
