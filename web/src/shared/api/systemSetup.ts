import { request } from './http';

/** First-run SQL backend setup contract (mirrors Api::V1::SystemSetupController). */

export type SqlAdapter = 'sqlite' | 'sqlserver' | 'mariadb';

export interface SetupStatus {
  adapter: SqlAdapter;
  adapters: string[];
  sqlServerConfigured: boolean;
  setupRequired: boolean;
  databases: string[];
}

export interface SetupTestResult {
  ok: boolean;
  adapter?: string;
  serverVersion?: string;
  database?: string;
  host?: string;
  username?: string;
  databases?: { existing: string[]; missing: string[] };
}

export interface VerificationEntry {
  database: string;
  ok: boolean;
  tables: Record<string, number | null>;
  totalRows: number;
  missing: string[];
  error?: string;
}

export interface SetupCompleteResult {
  configured: boolean;
  adapter: string;
  provisioned: { existing: string[]; created: string[]; missing: string[] };
  schema: { migrated: number; pending: number };
  imported: Record<string, number>;
  seeded: { users: number; projects: number; materials: number };
  verification: Record<string, VerificationEntry | boolean>;
  migrationRun: string | null;
}

export interface SqlServerSetupInput {
  adapter?: string;
  server: string;
  port?: number | string;
  username: string;
  password: string;
  database?: string;
  usersDatabase?: string;
  eventsDatabase?: string;
  logsDatabase?: string;
  encrypt?: boolean;
}

export const systemSetupApi = {
  status: () => request<SetupStatus>('/system/setup/status'),

  test: (input: SqlServerSetupInput) =>
    request<SetupTestResult>('/system/setup/test', { method: 'POST', body: input }),

  complete: (input: SqlServerSetupInput) =>
    request<SetupCompleteResult>('/system/setup/complete', { method: 'POST', body: input }),
};

