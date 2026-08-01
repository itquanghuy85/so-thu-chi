import 'package:dio/dio.dart';

/// A single field-level validation error, as returned inside
/// `error.details[]` by the backend (class-validator style errors).
class ApiFieldError {
  final String field;
  final String message;

  const ApiFieldError({required this.field, required this.message});

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: json['field']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

/// Typed exception carrying the backend's `{ code, message, details }` error
/// envelope, e.g.:
/// ```json
/// { "error": { "code": "INSUFFICIENT_BALANCE", "message": "...", "details": [...] } }
/// ```
///
/// Thrown by repositories after parsing any non-2xx Dio response so the UI
/// layer can show a single friendly message via [message] (and optionally
/// inspect [details] for inline field errors).
class ApiException implements Exception {
  final String code;
  final String message;
  final List<ApiFieldError> details;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.details = const [],
    this.statusCode,
  });

  /// Parses a [DioException] into an [ApiException], falling back to a
  /// generic network/unknown message when the response doesn't match the
  /// expected error envelope (e.g. timeouts, no connectivity, 500 with no
  /// body).
  factory ApiException.fromDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final err = data['error'] as Map<String, dynamic>;
      final rawDetails = err['details'];
      final details = <ApiFieldError>[];
      if (rawDetails is List) {
        for (final d in rawDetails) {
          if (d is Map<String, dynamic>) {
            details.add(ApiFieldError.fromJson(d));
          }
        }
      }
      return ApiException(
        code: err['code']?.toString() ?? 'UNKNOWN_ERROR',
        message: err['message']?.toString() ?? 'Đã có lỗi xảy ra',
        details: details,
        statusCode: statusCode,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          code: 'TIMEOUT',
          message: 'Kết nối tới máy chủ quá thời gian chờ. Vui lòng thử lại.',
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          code: 'CONNECTION_ERROR',
          message: 'Không thể kết nối tới máy chủ. Kiểm tra kết nối mạng.',
          statusCode: statusCode,
        );
      default:
        return ApiException(
          code: 'UNKNOWN_ERROR',
          message: 'Đã có lỗi xảy ra. Vui lòng thử lại.',
          statusCode: statusCode,
        );
    }
  }

  @override
  String toString() => 'ApiException($code): $message';
}
