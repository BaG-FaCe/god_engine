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
};
export type { Paginated };
