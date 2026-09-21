import { http } from '../../../shared/api/http';
import type { FixedCost, FixedCostUpsert, LaborCost, LaborCostUpsert, MonthlyCost, MonthlyCostUpsert, OverheadRule, OverheadRuleUpsert, Paginated, SalesForecast, SalesForecastAnalysis, SalesForecastUpsert } from '../../../shared/api/types';

export const monthlyApi = {
  list: (projectId: string) =>
    http.get<Paginated<MonthlyCost>>(`/projects/${projectId}/monthly_costs`),
  create: (projectId: string, item: MonthlyCostUpsert) =>
    http.post<MonthlyCost>(`/projects/${projectId}/monthly_costs`, { item }),
  update: (projectId: string, id: string, item: MonthlyCostUpsert) =>
    http.patch<MonthlyCost>(`/projects/${projectId}/monthly_costs/${id}`, { item }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/monthly_costs/${id}`),
};

export const laborApi = {
  list: (projectId: string) =>
    http.get<Paginated<LaborCost>>(`/projects/${projectId}/labor_costs`),
  create: (projectId: string, item: LaborCostUpsert) =>
    http.post<LaborCost>(`/projects/${projectId}/labor_costs`, { item }),
  update: (projectId: string, id: string, item: LaborCostUpsert) =>
    http.patch<LaborCost>(`/projects/${projectId}/labor_costs/${id}`, { item }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/labor_costs/${id}`),
};

export const fixedApi = {
  list: (projectId: string) =>
    http.get<Paginated<FixedCost>>(`/projects/${projectId}/fixed_costs`),
  create: (projectId: string, item: FixedCostUpsert) =>
    http.post<FixedCost>(`/projects/${projectId}/fixed_costs`, { item }),
  update: (projectId: string, id: string, item: FixedCostUpsert) =>
    http.patch<FixedCost>(`/projects/${projectId}/fixed_costs/${id}`, { item }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/fixed_costs/${id}`),
};

export const overheadApi = {
  list: (projectId: string) =>
    http.get<Paginated<OverheadRule>>(`/projects/${projectId}/overhead_rules`),
  create: (projectId: string, item: OverheadRuleUpsert) =>
    http.post<OverheadRule>(`/projects/${projectId}/overhead_rules`, { item }),
  update: (projectId: string, id: string, item: Partial<OverheadRuleUpsert>) =>
    http.patch<OverheadRule>(`/projects/${projectId}/overhead_rules/${id}`, { item }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/overhead_rules/${id}`),
};

export const forecastApi = {
  list: (projectId: string) =>
    http.get<Paginated<SalesForecast>>(`/projects/${projectId}/sales_forecasts`),
  analysis: (projectId: string) =>
    http.get<SalesForecastAnalysis>(`/projects/${projectId}/sales_forecasts/analysis`),
  create: (projectId: string, item: SalesForecastUpsert) =>
    http.post<SalesForecast>(`/projects/${projectId}/sales_forecasts`, { item }),
  update: (projectId: string, id: string, item: SalesForecastUpsert) =>
    http.patch<SalesForecast>(`/projects/${projectId}/sales_forecasts/${id}`, { item }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/sales_forecasts/${id}`),
};
