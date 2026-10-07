import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

/// Why a call to the API did not return what was asked for.
///
/// Every failure of a generated client method is one of these two, so a
/// caller handles errors with a single `switch`.
sealed class ApiException implements Exception {
  const new();

  /// Turns whatever a generated client method threw into an [ApiException].
  factory from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return inner;

      final response = error.response;
      if (response == null) return ApiUnreachable(cause: error);
      return ApiProblem.fromResponse(response);
    }
    return ApiUnreachable(cause: error);
  }
}

/// The API answered with an error.
///
/// Branch on [code], which is stable (`job.invalid_transition`,
/// `auth.invalid_credentials`). [detail] is written for people.
final class ApiProblem extends ApiException {
  const new({
    required this.status,
    required this.code,
    required this.title,
    this.detail,
    this.fieldErrors = const [],
    this.requestId,
  });

  /// Reads the `application/problem+json` body the API sends with every
  /// error. A response without one, such as a proxy's 502 page, becomes a
  /// problem with the code `http.<status>`.
  factory fromResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final body = response.data;
    if (body is Map<String, dynamic> && body['code'] is String) {
      final errors = body['errors'];
      return ApiProblem(
        status: status,
        code: body['code'] as String,
        title: body['title'] is String ? body['title'] as String : 'Error',
        detail: body['detail'] is String ? body['detail'] as String : null,
        fieldErrors: [
          if (errors is List)
            for (final error in errors)
              if (error is Map<String, dynamic>) ApiFieldError.fromJson(error),
        ],
        requestId: body['request_id'] is String
            ? body['request_id'] as String
            : null,
      );
    }
    return ApiProblem(
      status: status,
      code: 'http.$status',
      title: response.statusMessage ?? 'HTTP $status',
    );
  }

  final int status;
  final String code;
  final String title;
  final String? detail;

  /// One entry per rejected field of the request, for a 422.
  final List<ApiFieldError> fieldErrors;

  /// Quote this when reporting a problem. It finds the request in the logs.
  final String? requestId;

  @override
  String toString() => 'ApiProblem($status $code: ${detail ?? title})';
}

/// One rejected field of a request.
@immutable
class ApiFieldError {
  const new({required this.field, required this.message, required this.code});

  factory fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: '${json['field'] ?? ''}',
      message: '${json['message'] ?? ''}',
      code: '${json['code'] ?? ''}',
    );
  }

  /// The field's path in the request, for example `email` or
  /// `settings.copies`.
  final String field;
  final String message;
  final String code;
}

/// The API could not be reached: no connection, a timeout, or a reply that
/// could not be read.
final class ApiUnreachable extends ApiException {
  const new({required this.cause});

  final Object cause;

  @override
  String toString() => 'ApiUnreachable($cause)';
}

/// Runs [call], rethrowing any failure as an [ApiException].
Future<T> apiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(ApiException.from(error), stackTrace);
  }
}
