import type { ApiErrorPayload, FieldError } from '../api/types';

/** Base class for every error surfaced by the shared HTTP client. */
export class AppError extends Error {
  public readonly code: string;
  public readonly status: number;
  public readonly details?: FieldError[] | Record<string, unknown>;

  constructor(
    message: string,
    options: {
      code?: string;
      status?: number;
      details?: FieldError[] | Record<string, unknown>;
    } = {},
  ) {
    super(message);
    this.name = 'AppError';
    this.code = options.code ?? 'unknown_error';
    this.status = options.status ?? 0;
    if (options.details !== undefined) this.details = options.details;
  }

  get isValidationError(): boolean {
    return this.status === 422;
  }

  get isUnauthorized(): boolean {
    return this.status === 401 || this.status === 403;
  }

  get isNotFound(): boolean {
    return this.status === 404;
  }

  /** `422` payloads are rendered as one message per invalid field. */
  get fieldErrors(): FieldError[] {
    if (Array.isArray(this.details)) return this.details;
    if (this.details && typeof this.details === 'object') {
      return Object.entries(this.details).map(([field, message]) => ({
        field,
        message: Array.isArray(message) ? message.join(', ') : String(message),
      }));
    }
    return [];
  }
}

export class NetworkError extends AppError {
  constructor(message = 'Netzwerkfehler: Die API ist nicht erreichbar.') {
    super(message, { code: 'network_error' });
    this.name = 'NetworkError';
  }
}

export class TimeoutError extends AppError {
  constructor(message = 'Zeitüberschreitung bei der Anfrage.') {
    super(message, { code: 'timeout' });
    this.name = 'TimeoutError';
  }
}

export function isApiErrorPayload(value: unknown): value is ApiErrorPayload {
  return (
    typeof value === 'object' &&
    value !== null &&
    'error' in value &&
    typeof (value as ApiErrorPayload).error === 'object'
  );
}

export function toAppError(error: unknown): AppError {
  if (error instanceof AppError) return error;
  if (error instanceof Error) return new AppError(error.message);
  return new AppError(String(error));
}

/** Human readable message used by toasts and error placeholders. */
export function errorMessage(error: unknown): string {
  if (error instanceof AppError) {
    const fields = error.fieldErrors;
    if (fields.length > 0) {
      return `${error.message} (${fields.map((f) => `${f.field}: ${f.message}`).join('; ')})`;
    }
    return error.message;
  }
  if (error instanceof Error) return error.message;
  return 'Unbekannter Fehler';
}