import type { ApiErrorPayload } from './types';
import { AppError, NetworkError, TimeoutError, isApiErrorPayload } from '../lib/errors';

/**
 * Thin, dependency-free HTTP client for the Rails API.
 *
 * Responsibilities are deliberately small so every module can wrap it without
 * inheriting hidden state:
 *   - base URL + bearer token resolution
 *   - JSON (de)serialisation and uniform error mapping to `AppError`
 *   - request timeout via `AbortController`
 *   - binary download support for XLSX / PDF / CSV exports
 */

export const API_BASE_URL: string =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? '/api/v1';

const DEFAULT_TIMEOUT_MS = 20_000;

/** Token storage key. Kept in one place so auth changes stay localised. */
export const AUTH_TOKEN_KEY = 'god-engine.auth.token';

let tokenProvider: () => string | null = () => {
  try {
    return window.localStorage.getItem(AUTH_TOKEN_KEY);
  } catch {
    return null;
  }
};

/** Lets tests, or a cookie based session, override token resolution. */
export function setTokenProvider(provider: () => string | null): void {
  tokenProvider = provider;
}

export function getToken(): string | null {
  return tokenProvider();
}

export function setToken(token: string | null): void {
  try {
    if (token) window.localStorage.setItem(AUTH_TOKEN_KEY, token);
    else window.localStorage.removeItem(AUTH_TOKEN_KEY);
  } catch {
    /* storage unavailable — token stays in memory only */
  }
}

export type QueryParams = Record<
  string,
  string | number | boolean | null | undefined | Array<string | number>
>;

export function buildQuery(params?: QueryParams): string {
  if (!params) return '';
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined || value === '') continue;
    if (Array.isArray(value)) {
      for (const item of value) search.append(`${key}[]`, String(item));
    } else {
      search.append(key, String(value));
    }
  }
  const serialised = search.toString();
  return serialised ? `?${serialised}` : '';
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';
  body?: unknown;
  params?: QueryParams;
  signal?: AbortSignal;
  timeoutMs?: number;
  headers?: Record<string, string>;
}

function authHeaders(): Record<string, string> {
  const token = tokenProvider();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function requestRaw(path: string, options: RequestOptions = {}): Promise<Response> {
  const { method = 'GET', body, params, signal, timeoutMs = DEFAULT_TIMEOUT_MS } = options;

  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
  signal?.addEventListener('abort', () => controller.abort(), { once: true });

  const url = `${API_BASE_URL}${path}${buildQuery(params)}`;
  const isFormData = body instanceof FormData;

  try {
    return await fetch(url, {
      method,
      headers: {
        Accept: 'application/json',
        ...(isFormData || body === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...authHeaders(),
        ...options.headers,
      },
      body: isFormData ? body : body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
      credentials: 'same-origin',
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new TimeoutError();
    }
    throw new NetworkError();
  } finally {
    window.clearTimeout(timeout);
  }
}

export async function parseError(response: Response): Promise<AppError> {
  let payload: unknown = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  if (isApiErrorPayload(payload)) {
    const parsed = payload as ApiErrorPayload;
    return new AppError(parsed.error.message, {
      code: parsed.error.code,
      status: response.status,
      ...(parsed.error.details !== undefined ? { details: parsed.error.details } : {}),
    });
  }

  return new AppError(`Anfrage fehlgeschlagen (HTTP ${response.status})`, {
    code: 'http_error',
    status: response.status,
  });
}

async function parseJson<T>(response: Response): Promise<T> {
  if (!response.ok) throw await parseError(response);
  if (response.status === 204) return undefined as T;
  const text = await response.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

/** Typed JSON request — throws `AppError` on any non-2xx status. */
export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const response = await requestRaw(path, options);
  return parseJson<T>(response);
}

export interface ListParams extends QueryParams {
  page?: number;
  perPage?: number;
  q?: string;
}

export const http = {
  get: <T>(path: string, params?: QueryParams, options?: Omit<RequestOptions, 'method' | 'params'>) =>
    request<T>(path, { ...options, method: 'GET', params }),
  post: <T>(path: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(path, { ...options, method: 'POST', body }),
  patch: <T>(path: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(path, { ...options, method: 'PATCH', body }),
  put: <T>(path: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(path, { ...options, method: 'PUT', body }),
  del: <T>(path: string, options?: Omit<RequestOptions, 'method'>) =>
    request<T>(path, { ...options, method: 'DELETE' }),
};

export const costTemplatesApi = {
  list: (projectId?: string) =>
    request<{ data: import('./types').CostTemplate[] }>('/cost_templates', {
      method: 'GET',
      params: projectId ? { projectId } : undefined,
    }),
  get: (id: string) => request<import('./types').CostTemplate>(`/cost_templates/${id}`),
  create: (template: import('./types').CostTemplateUpsert) =>
    request<import('./types').CostTemplate>('/cost_templates', {
      method: 'POST',
      body: { cost_template: template },
    }),
  update: (id: string, template: Partial<import('./types').CostTemplateUpsert>) =>
    request<import('./types').CostTemplate>(`/cost_templates/${id}`, {
      method: 'PATCH',
      body: { cost_template: template },
    }),
  remove: (id: string) => request<void>(`/cost_templates/${id}`, { method: 'DELETE' }),
  apply: (id: string, projectId: string) =>
    request<{ applied: Record<string, number> }>(`/cost_templates/${id}/apply`, {
      method: 'POST',
      body: { projectId },
    }),
};

export const templatesCatalogApi = {
  apply: (templateId: string, body: { projectId: string }) =>
    costTemplatesApi.apply(templateId, body.projectId),
};

export interface JobStatus {
  id: string;
  status: string;
  queueName?: string | null;
  jobClass?: string | null;
  enqueuedAt?: string | null;
  finishedAt?: string | null;
  error?: string | null;
  queryable?: boolean;
}

export const jobsApi = {
  get: (id: string) => request<JobStatus>(`/jobs/${id}`),
  list: () => request<{ data: JobStatus[] }>('/jobs'),
};

/** Auth endpoints — used by the shell, not owned by a single module. */
export const authApi = {
  login: (email: string, password: string) =>
    request<{ token: string; user: unknown }>('/auth/login', {
      method: 'POST',
      body: { email, password },
    }),
  me: () => request<{ user: unknown }>('/auth/me'),
};
