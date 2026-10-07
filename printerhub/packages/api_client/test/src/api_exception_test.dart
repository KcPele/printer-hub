import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final request = RequestOptions(path: '/api/v1/users/me');

  DioException failure({Response<dynamic>? response, Object? error}) {
    return DioException(
      requestOptions: request,
      response: response,
      error: error,
    );
  }

  Response<dynamic> response(int status, Object? body, {String? message}) {
    return Response<dynamic>(
      requestOptions: request,
      statusCode: status,
      statusMessage: message,
      data: body,
    );
  }

  group('ApiException.from', () {
    test('keeps an ApiException as it is', () {
      const problem = ApiProblem(
        status: 404,
        code: 'printer.not_found',
        title: 'Not found',
      );

      expect(ApiException.from(problem), same(problem));
      expect(ApiException.from(failure(error: problem)), same(problem));
    });

    test('reads the problem the API sent', () {
      final exception = ApiException.from(
        failure(
          response: response(422, {
            'type': 'about:blank',
            'title': 'Validation failed',
            'status': 422,
            'code': 'request.invalid',
            'detail': 'Check the highlighted fields.',
            'request_id': 'req-42',
            'errors': [
              {
                'field': 'email',
                'message': 'Not an email',
                'code': 'value_error',
              },
              'not a field error',
            ],
          }),
        ),
      );

      expect(exception, isA<ApiProblem>());
      final problem = exception as ApiProblem;
      expect(problem.status, 422);
      expect(problem.code, 'request.invalid');
      expect(problem.title, 'Validation failed');
      expect(problem.detail, 'Check the highlighted fields.');
      expect(problem.requestId, 'req-42');
      expect(problem.fieldErrors, hasLength(1));
      expect(problem.fieldErrors.single.field, 'email');
      expect(problem.fieldErrors.single.message, 'Not an email');
      expect(problem.fieldErrors.single.code, 'value_error');
      expect(
        '$problem',
        'ApiProblem(422 request.invalid: Check the highlighted fields.)',
      );
    });

    test('reads a problem that leaves out the optional parts', () {
      final problem = ApiException.from(
        failure(response: response(409, {'code': 'job.invalid_transition'})),
      ) as ApiProblem;

      expect(problem.code, 'job.invalid_transition');
      expect(problem.title, 'Error');
      expect(problem.detail, isNull);
      expect(problem.requestId, isNull);
      expect(problem.fieldErrors, isEmpty);
      expect('$problem', 'ApiProblem(409 job.invalid_transition: Error)');
    });

    test('names an error that is not a problem after its status', () {
      final fromProxy = ApiException.from(
        failure(
          response: response(
            502,
            '<html>Bad Gateway</html>',
            message: 'Bad Gateway',
          ),
        ),
      ) as ApiProblem;
      final bare = ApiException.from(
        failure(response: response(500, null)),
      ) as ApiProblem;

      expect(fromProxy.code, 'http.502');
      expect(fromProxy.title, 'Bad Gateway');
      expect(bare.code, 'http.500');
      expect(bare.title, 'HTTP 500');
    });

    test('treats a failure without a response as unreachable', () {
      final timeout = failure();
      const other = FormatException('bad json');

      final unreachable = ApiException.from(timeout);

      expect(unreachable, isA<ApiUnreachable>());
      expect((unreachable as ApiUnreachable).cause, same(timeout));
      expect((ApiException.from(other) as ApiUnreachable).cause, same(other));
      expect('${ApiException.from(other)}', contains('bad json'));
    });
  });

  group('apiCall', () {
    test('returns what the call returns', () async {
      expect(await apiCall(() async => 7), 7);
    });

    test('rethrows a failure as an ApiException', () async {
      await expectLater(
        apiCall<void>(
          () async => throw failure(
            response: response(404, {'code': 'printer.not_found'}),
          ),
        ),
        throwsA(
          isA<ApiProblem>().having((p) => p.code, 'code', 'printer.not_found'),
        ),
      );
      await expectLater(
        apiCall<void>(() async => throw failure()),
        throwsA(isA<ApiUnreachable>()),
      );
    });
  });

  group('ApiFieldError', () {
    test('tolerates missing keys', () {
      final error = ApiFieldError.fromJson(const {});

      expect(error.field, isEmpty);
      expect(error.message, isEmpty);
      expect(error.code, isEmpty);
    });
  });
}
