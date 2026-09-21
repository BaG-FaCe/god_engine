import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type {
  FixedCostUpsert,
  LaborCostUpsert,
  MaterialUpsert,
  MonthlyCostUpsert,
  OverheadRuleUpsert,
  PriceOptimizationRequest,
  PricingScenarioUpsert,
  ProjectUpsert,
  SalesForecastUpsert,
} from '../../../shared/api/types';
import { costTemplatesApi as sharedTemplatesApi } from '../../../shared/api/http';
import { materialApi } from './materials';
import { monthlyApi, laborApi, fixedApi, overheadApi, forecastApi } from './costs';
import { pricingApi } from './pricing';
import { projectsApi, suppliersApi } from './projects';
import { riskApi } from './risk';

/**
 * Query hooks for the calculator module.
 *
 * Every key is prefixed with `calculator` and scoped by project so mutations can
 * invalidate whole tabs without touching other modules.
 */
const K = {
  root: ['calculator'] as const,
  projects: (params?: Record<string, unknown>) => [...K.root, 'projects', params ?? {}] as const,
  project: (id?: string | null) => [...K.root, 'project', id ?? 'none'] as const,
  suppliers: (id?: string | null) => [...K.root, 'suppliers', id ?? 'none'] as const,
  materials: (id?: string | null) => [...K.root, 'materials', id ?? 'none'] as const,
  leadTime: (id?: string | null) => [...K.root, 'lead-time', id ?? 'none'] as const,
  monthly: (id?: string | null) => [...K.root, 'monthly-costs', id ?? 'none'] as const,
  labor: (id?: string | null) => [...K.root, 'labor-costs', id ?? 'none'] as const,
  fixed: (id?: string | null) => [...K.root, 'fixed-costs', id ?? 'none'] as const,
  overhead: (id?: string | null) => [...K.root, 'overhead-rules', id ?? 'none'] as const,
  forecasts: (id?: string | null) => [...K.root, 'forecasts', id ?? 'none'] as const,
  forecastAnalysis: (id?: string | null) =>
    [...K.root, 'forecast-analysis', id ?? 'none'] as const,
  pricing: (id?: string | null) => [...K.root, 'pricing', id ?? 'none'] as const,
  dashboard: (id?: string | null) => [...K.root, 'dashboard', id ?? 'none'] as const,
  scenarios: (id?: string | null) => [...K.root, 'scenarios', id ?? 'none'] as const,
  riskSummary: (id?: string | null) => [...K.root, 'risk-summary', id ?? 'none'] as const,
  templates: (id?: string | null) => [...K.root, 'templates', id ?? 'global'] as const,
};

// --- reads -------------------------------------------------------------------

export function useProjects(params?: { q?: string; status?: string }) {
  return useQuery({
    queryKey: K.projects(params),
    queryFn: () => projectsApi.list(params),
  });
}

export function useProject(id?: string | null) {
  return useQuery({
    queryKey: K.project(id),
    queryFn: () => projectsApi.get(id as string),
    enabled: Boolean(id),
  });
}

export function useSuppliers(projectId?: string | null) {
  return useQuery({
    queryKey: K.suppliers(projectId),
    queryFn: () => suppliersApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useMaterials(projectId?: string | null) {
  return useQuery({
    queryKey: K.materials(projectId),
    queryFn: () => materialApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useLeadTimeAnalysis(projectId?: string | null) {
  return useQuery({
    queryKey: K.leadTime(projectId),
    queryFn: () => materialApi.leadTime(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useMonthlyCosts(projectId?: string | null) {
  return useQuery({
    queryKey: K.monthly(projectId),
    queryFn: () => monthlyApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useLaborCosts(projectId?: string | null) {
  return useQuery({
    queryKey: K.labor(projectId),
    queryFn: () => laborApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useFixedCosts(projectId?: string | null) {
  return useQuery({
    queryKey: K.fixed(projectId),
    queryFn: () => fixedApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useOverheadRules(projectId?: string | null) {
  return useQuery({
    queryKey: K.overhead(projectId),
    queryFn: () => overheadApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useForecasts(projectId?: string | null) {
  return useQuery({
    queryKey: K.forecasts(projectId),
    queryFn: () => forecastApi.list(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useForecastAnalysis(projectId?: string | null) {
  return useQuery({
    queryKey: K.forecastAnalysis(projectId),
    queryFn: () => forecastApi.analysis(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function usePricing(projectId?: string | null) {
  return useQuery({
    queryKey: K.pricing(projectId),
    queryFn: () => pricingApi.get(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useDashboard(projectId?: string | null) {
  return useQuery({
    queryKey: K.dashboard(projectId),
    queryFn: () => pricingApi.dashboard(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function usePricingScenarios(projectId?: string | null) {
  return useQuery({
    queryKey: K.scenarios(projectId),
    queryFn: () => pricingApi.scenarios(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useRiskSummary(projectId?: string | null) {
  return useQuery({
    queryKey: K.riskSummary(projectId),
    queryFn: () => riskApi.summary(projectId as string),
    enabled: Boolean(projectId),
  });
}

export function useGlobalCostTemplates() {
  return useQuery({
    queryKey: K.templates(null),
    queryFn: () => sharedTemplatesApi.list(),
  });
}

// --- mutations ----------------------------------------------------------------

function useInvalidateRoot() {
  const client = useQueryClient();
  return () => void client.invalidateQueries({ queryKey: K.root });
}

export function useProjectMutations() {
  const invalidate = useInvalidateRoot();
  const create = useMutation({
    mutationFn: (project: ProjectUpsert) => projectsApi.create({ project }),
    onSuccess: invalidate,
  });
  const update = useMutation({
    mutationFn: ({ id, project }: { id: string; project: Partial<ProjectUpsert> }) =>
      projectsApi.update(id, { project }),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => projectsApi.remove(id),
    onSuccess: invalidate,
  });
  const duplicate = useMutation({
    mutationFn: (id: string) => projectsApi.duplicate(id),
    onSuccess: invalidate,
  });
  const archive = useMutation({
    mutationFn: (id: string) => projectsApi.archive(id),
    onSuccess: invalidate,
  });
  const restore = useMutation({
    mutationFn: (id: string) => projectsApi.restore(id),
    onSuccess: invalidate,
  });
  const importDocument = useMutation({
    mutationFn: ({ id, document }: { id: string; document: unknown }) =>
      projectsApi.importJson(id, document),
    onSuccess: invalidate,
  });
  return { create, update, remove, duplicate, archive, restore, importDocument };
}

export function useMaterialMutations(projectId: string | null | undefined) {
  const client = useQueryClient();
  const invalidate = () => {
    void client.invalidateQueries({ queryKey: K.materials(projectId) });
    void client.invalidateQueries({ queryKey: K.pricing(projectId) });
    void client.invalidateQueries({ queryKey: K.dashboard(projectId) });
    void client.invalidateQueries({ queryKey: K.riskSummary(projectId) });
  };
  const create = useMutation({
    mutationFn: (material: MaterialUpsert) => materialApi.create(projectId as string, material),
    onSuccess: invalidate,
  });
  const update = useMutation({
    mutationFn: ({ id, material }: { id: string; material: Partial<MaterialUpsert> }) =>
      materialApi.update(projectId as string, id, material),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => materialApi.remove(projectId as string, id),
    onSuccess: invalidate,
  });
  return { create, update, remove };
}

function blockMutations<TBody, TUpdate = TBody>(
  projectId: string | null | undefined,
  key: readonly unknown[],
  api: {
    create: (projectId: string, item: TBody) => Promise<unknown>;
    update: (projectId: string, id: string, item: TUpdate) => Promise<unknown>;
    remove: (projectId: string, id: string) => Promise<unknown>;
  },
) {
  const client = useQueryClient();
  const invalidate = () => {
    void client.invalidateQueries({ queryKey: key });
    void client.invalidateQueries({ queryKey: K.root });
  };
  const create = useMutation({
    mutationFn: (item: TBody) => api.create(projectId as string, item),
    onSuccess: invalidate,
  });
  const update = useMutation({
    mutationFn: ({ id, item }: { id: string; item: TUpdate }) =>
      api.update(projectId as string, id, item),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => api.remove(projectId as string, id),
    onSuccess: invalidate,
  });
  return { create, update, remove };
}

export function useMonthlyCostMutations(projectId: string | null | undefined) {
  return blockMutations<MonthlyCostUpsert>(projectId, K.monthly(projectId), monthlyApi);
}

export function useLaborCostMutations(projectId: string | null | undefined) {
  return blockMutations<LaborCostUpsert>(projectId, K.labor(projectId), laborApi);
}

export function useFixedCostMutations(projectId: string | null | undefined) {
  return blockMutations<FixedCostUpsert>(projectId, K.fixed(projectId), fixedApi);
}

export function useOverheadRuleMutations(projectId: string | null | undefined) {
  return blockMutations<OverheadRuleUpsert, Partial<OverheadRuleUpsert>>(
    projectId, K.overhead(projectId), overheadApi,
  );
}

export function useForecastMutations(projectId: string | null | undefined) {
  return blockMutations<SalesForecastUpsert>(projectId, K.forecasts(projectId), forecastApi);
}

export function useScenarioMutations(projectId: string | null | undefined) {
  const invalidate = useInvalidateRoot();
  const create = useMutation({
    mutationFn: (scenario: PricingScenarioUpsert) =>
      pricingApi.createScenario(projectId as string, scenario),
    onSuccess: invalidate,
  });
  const activate = useMutation({
    mutationFn: (id: string) => pricingApi.activateScenario(projectId as string, id),
    onSuccess: invalidate,
  });
  return { create, activate };
}

export function usePriceOptimizer(projectId: string | null | undefined) {
  return useMutation({
    mutationFn: (body: PriceOptimizationRequest) => pricingApi.optimize(projectId as string, body),
  });
}

export function useApplyTemplate(projectId: string | null | undefined) {
  const invalidate = useInvalidateRoot();
  return useMutation({
    mutationFn: (templateId: string) =>
      sharedTemplatesApi.apply(templateId, projectId as string),
    onSuccess: invalidate,
  });
}

export function useSaveCostTemplate() {
  const invalidate = useInvalidateRoot();
  const create = useMutation({
    mutationFn: (template: Parameters<typeof sharedTemplatesApi.create>[0]) =>
      sharedTemplatesApi.create(template),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => sharedTemplatesApi.remove(id),
    onSuccess: invalidate,
  });
  return { create, remove };
}

export { K as calculatorKeys };

