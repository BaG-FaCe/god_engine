import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { costTemplatesApi, templatesCatalogApi } from '../../../shared/api/http';
import type { CostTemplate, CostTemplateUpsert } from '../../../shared/api/types';

export const costTemplateKeys = {
  all: (projectId?: string) => ['cost-templates', projectId ?? 'global'] as const,
};

export function useCostTemplates(projectId?: string) {
  return useQuery({
    queryKey: costTemplateKeys.all(projectId),
    queryFn: () => costTemplatesApi.list(projectId),
  });
}

export function useCostTemplateMutations(projectId: string) {
  const client = useQueryClient();
  const invalidate = () => {
    void client.invalidateQueries({ queryKey: costTemplateKeys.all(projectId) });
    void client.invalidateQueries({ queryKey: costTemplateKeys.all(undefined) });
  };
  const create = useMutation({
    mutationFn: (payload: CostTemplateUpsert) => costTemplatesApi.create(payload),
    onSuccess: invalidate,
  });
  const update = useMutation({
    mutationFn: ({ id, item }: { id: string; item: Partial<CostTemplateUpsert> }) =>
      costTemplatesApi.update(id, item),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => costTemplatesApi.remove(id),
    onSuccess: invalidate,
  });
  const apply = useMutation({
    mutationFn: (templateId: string) =>
      templatesCatalogApi.apply(templateId, { projectId }),
    onSuccess: () => {
      invalidate();
      void client.invalidateQueries({ queryKey: ['calculator'] });
    },
  });
  return { create, update, remove, apply };
}

export function categorizeCostTemplate(template: CostTemplate): 'monthly' | 'fixed' | 'mixed' {
  if (template.kind === 'monthly_costs') return 'monthly';
  if (template.kind === 'fixed_costs') return 'fixed';
  return 'mixed';
}
