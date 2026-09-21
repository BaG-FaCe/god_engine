import { http } from '../../../shared/api/http';
import type { Paginated, Project, ProjectUpsert, Supplier, SupplierUpsert } from '../../../shared/api/types';

export const projectsApi = {
  list: (params?: { q?: string; status?: string; page?: number; perPage?: number }) =>
    http.get<Paginated<Project>>('/projects', params),
  get: (id: string) => http.get<Project>(`/projects/${id}`),
  create: (project: { project: ProjectUpsert }) =>
    http.post<Project>('/projects', project),
  update: (id: string, project: { project: Partial<ProjectUpsert> }) =>
    http.patch<Project>(`/projects/${id}`, project),
  remove: (id: string) => http.del<void>(`/projects/${id}`),
  duplicate: (id: string) => http.post<Project>(`/projects/${id}/duplicate`),
  archive: (id: string) => http.post<Project>(`/projects/${id}/archive`),
  restore: (id: string) => http.post<Project>(`/projects/${id}/restore`),
  exportJson: (id: string) => http.get<unknown>(`/projects/${id}/export`, { format: 'json' }),
  importJson: (id: string, document: unknown) =>
    http.post<{ imported: Record<string, number> }>(`/projects/${id}/import`, document),
  exportCsvUrl: (id: string) => `/api/v1/projects/${id}/export?format=csv`,
};

export const suppliersApi = {
  list: (projectId: string, q?: string) =>
    http.get<{ data: Supplier[] }>(`/projects/${projectId}/suppliers`, q ? { q } : undefined),
  get: (projectId: string, id: string) =>
    http.get<Supplier>(`/projects/${projectId}/suppliers/${id}`),
  create: (projectId: string, supplier: SupplierUpsert) =>
    http.post<Supplier>(`/projects/${projectId}/suppliers`, { supplier }),
  update: (projectId: string, id: string, supplier: Partial<SupplierUpsert>) =>
    http.patch<Supplier>(`/projects/${projectId}/suppliers/${id}`, { supplier }),
  remove: (projectId: string, id: string) =>
    http.del<void>(`/projects/${projectId}/suppliers/${id}`),
};

export const authApi = {
  login: (email: string, password: string) =>
    http.post<{ token: string; user: unknown }>('/auth/login', { email, password }),
  me: () => http.get<{ user: unknown }>('/auth/me'),
};
