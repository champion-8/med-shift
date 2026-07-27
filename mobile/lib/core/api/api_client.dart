import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

typedef TokenProvider = String? Function();
typedef UnauthorizedHandler = Future<void> Function();

class ApiClient {
  late final Dio _dio;
  TokenProvider? _tokenProvider;
  UnauthorizedHandler? onUnauthorized;
  bool _handlingUnauthorized = false;

  ApiClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        sendTimeout: AppConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          print('[API Request] ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print(
              '[API Response] ${response.statusCode} ${response.requestOptions.path}');
          final body = response.data;
          if (body is Map<String, dynamic> && body.containsKey('success')) {
            if (body['success'] == true) {
              response.data = body['data'];
            } else {
              return handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                  message: (body['message'] as String?) ?? 'Request failed',
                ),
              );
            }
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          print(
              '[API Error] ${error.response?.statusCode} ${error.requestOptions.path}');
          print('[API Error Message] ${error.message}');
          _notifyUnauthorizedIfNeeded(error);
          return handler.next(error);
        },
      ),
    );
  }

  void _notifyUnauthorizedIfNeeded(DioException error) {
    if (error.response?.statusCode != 401) return;
    final path = error.requestOptions.path;
    if (path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password')) {
      return;
    }
    if (_handlingUnauthorized || onUnauthorized == null) return;
    _handlingUnauthorized = true;
    Future(() async {
      try {
        await onUnauthorized?.call();
      } finally {
        _handlingUnauthorized = false;
      }
    });
  }

  // GET Request
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST Request
  Future<Response> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final opts = options ?? Options();
      if (data is FormData) {
        opts.contentType = Headers.multipartFormDataContentType;
        opts.headers = {
          ...?opts.headers,
          Headers.contentTypeHeader: Headers.multipartFormDataContentType,
        };
      }
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: opts,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT Request
  Future<Response> put(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE Request
  Future<Response> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PATCH Request
  Future<Response> patch(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error Handler
  ApiException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timeout. Please check your internet connection.',
          statusCode: 408,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 500;
        return ApiException(
          message: _extractErrorMessage(error),
          statusCode: statusCode,
          data: error.response?.data,
        );

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request was cancelled',
          statusCode: 499,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: 'No internet connection',
          statusCode: 503,
        );

      default:
        return ApiException(
          message: error.message ?? 'Unknown error occurred',
          statusCode: 500,
        );
    }
  }

  /// Safe extract — API may return Map, String, or empty body (esp. 401).
  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final raw = data['message'] ??
          data['title'] ??
          data['detail'] ??
          data['error'];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        return raw.toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return error.response?.statusMessage ??
        error.message ??
        'Unknown error occurred';
  }

  void setTokenProvider(TokenProvider provider) {
    _tokenProvider = provider;
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}

// Custom API Exception
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    required this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException: $message (Status Code: $statusCode)';
}
