import { http } from '../../../shared/api/http';
import type { DashboardResponse, Paginated, PriceOptimizationRequest, PriceOptimizationResult, PricingResult, PricingScenario, PricingScenarioUpsert } from '../../../shared/api/types';

export const pricingApi = {
  get: (projectId: string) => http.get<PricingResult>(`/projects/${projectId}/pricing`),
  optimize: (projectId: string, body: PriceOptimizationRequest) =>
    http.post<PriceOptimizationResult>(`/projects/${projectId}/pricing/optimize`, body),
  dashboard: (projectId: string) =>
    http.get<DashboardResponse>(`/projects/${projectId}/dashboard`),
  scenarios: (projectId: string) =>
    http.get<{ data: PricingScenario[] }>(`/projects/${projectId}/pricing_scenarios`),
  createScenario: (projectId: string, scenario: PricingScenarioUpsert) =>
    http.post<PricingScenario>(`/projects/${projectId}/pricing_scenarios`, { pricing_scenario: scenario }),
  activateScenario: (projectId: string, id: string) =>
    http.post<PricingScenario>(`/projects/${projectId}/pricing_scenarios/${id}/activate`),
  listScenariosPage: (projectId: string) =>
    http.get<Paginated<PricingScenario>>(`/projects/${projectId}/pricing_scenarios`),
};
