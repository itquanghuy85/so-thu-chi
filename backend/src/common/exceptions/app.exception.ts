import { HttpException } from '@nestjs/common';

export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'UNAUTHORIZED'
  | 'INVALID_CREDENTIALS'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'INSUFFICIENT_BALANCE'
  | 'VAULT_NOT_IN_WORKSPACE'
  | 'INTERNAL_ERROR';

export const ERROR_CODE_STATUS: Record<ErrorCode, number> = {
  VALIDATION_ERROR: 400,
  UNAUTHORIZED: 401,
  INVALID_CREDENTIALS: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  INSUFFICIENT_BALANCE: 422,
  VAULT_NOT_IN_WORKSPACE: 422,
  INTERNAL_ERROR: 500,
};

export interface ErrorDetail {
  field: string;
  message: string;
}

/**
 * Application-level exception carrying a stable error `code` that the
 * global HttpExceptionFilter maps to the response shape:
 * { error: { code, message, details? } }
 */
export class AppException extends HttpException {
  public readonly code: ErrorCode;
  public readonly details?: ErrorDetail[];

  constructor(code: ErrorCode, message: string, details?: ErrorDetail[]) {
    super({ code, message, details }, ERROR_CODE_STATUS[code]);
    this.code = code;
    this.details = details;
  }
}
