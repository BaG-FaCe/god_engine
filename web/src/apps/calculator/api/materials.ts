import { http } from '../../../shared/api/http';
import type { LeadTimeAnalysis, Material, MaterialCard, MaterialUpsert, Paginated } from '../../../shared/api/types';

export const materialApi = {
  list: (projectId: string) =>
    http.get<Paginated<Material>>(`/projects/${projectId}/materials`),
  create: (projectId: string, material: MaterialUpsert) =>
    http.post<Material>(`/projects/${projectId}/materials`, { material }),
  update: (projectId: string, id: string, material: Partial<MaterialUpsert>) =>
    http.patch<Material>(`/projects/${projectId}/materials/${id}`, { material }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/materials/${id}`),
  leadTime: (projectId: string) =>
    http.get<LeadTimeAnalysis>(`/projects/${projectId}/materials/lead_time_analysis`),
  card: (materialId: string) => http.get<MaterialCard>(`/materials/${materialId}/card`),
};
