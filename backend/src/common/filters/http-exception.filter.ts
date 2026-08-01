import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AppException, ErrorCode, ErrorDetail } from '../exceptions/app.exception';

/**
 * Formats every error thrown in the app (AppException, Nest's built-in
 * HttpExceptions, ValidationPipe errors, and unhandled 500s) into the
 * uniform shape:
 *   { "error": { "code": "...", "message": "...", "details"?: [...] } }
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code: ErrorCode = 'INTERNAL_ERROR';
    let message = 'Đã xảy ra lỗi hệ thống';
    let details: ErrorDetail[] | undefined;

    if (exception instanceof AppException) {
      status = exception.getStatus();
      code = exception.code;
      message = exception.message;
      details = exception.details;
    } else if (exception instanceof BadRequestException) {
      // ValidationPipe errors land here as a BadRequestException whose
      // response.message is either a string or string[] of constraint messages.
      status = HttpStatus.BAD_REQUEST;
      code = 'VALIDATION_ERROR';
      const res = exception.getResponse() as
        | string
        | { message?: string | string[]; error?: string };
      const rawMessages =
        typeof res === 'string' ? [res] : Array.isArray(res.message) ? res.message : res.message ? [res.message] : [exception.message];
      message = 'Dữ liệu không hợp lệ';
      details = rawMessages.map((m) => this.toErrorDetail(m));
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      message = exception.message;
      code = this.codeFromStatus(status);
    } else if (exception instanceof Error) {
      this.logger.error(exception.message, exception.stack);
      message = exception.message || message;
    } else {
      this.logger.error('Unknown exception thrown', exception as any);
    }

    response.status(status).json({
      error: {
        code,
        message,
        ...(details && details.length ? { details } : {}),
      },
    });

    if (status >= 500) {
      this.logger.error(`${request.method} ${request.url} -> ${status} ${code}: ${message}`);
    }
  }

  private toErrorDetail(rawMessage: string): ErrorDetail {
    // class-validator messages typically start with the property name, e.g.
    // "amount must be a positive number". We try to pull the field name out;
    // fall back to "unknown" when we can't.
    const firstWord = rawMessage.split(' ')[0];
    return { field: firstWord || 'unknown', message: rawMessage };
  }

  private codeFromStatus(status: number): ErrorCode {
    switch (status) {
      case 400:
        return 'VALIDATION_ERROR';
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 409:
        return 'CONFLICT';
      case 422:
        return 'INSUFFICIENT_BALANCE';
      default:
        return 'INTERNAL_ERROR';
    }
  }
}
