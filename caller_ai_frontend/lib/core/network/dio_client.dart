import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../env.dart';

final _storage = FlutterSecureStorage();

Dio createDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: AppEnv.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Auth interceptor: inject Bearer token
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (DioException err, handler) async {
      if (err.response?.statusCode == 401) {
        // Attempt silent refresh
        final refreshed = await _refreshToken();
        if (refreshed) {
          final token = await _storage.read(key: 'access_token');
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await Dio().fetch(err.requestOptions);
          return handler.resolve(response);
        }
      }
      handler.next(err);
    },
  ));

  // Logging in debug mode
  if (AppEnv.isDebug) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  return dio;
}

Future<bool> _refreshToken() async {
  try {
    final storage = FlutterSecureStorage();
    final refreshToken = await storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    final dio = Dio(BaseOptions(baseUrl: AppEnv.apiBaseUrl));
    final resp = await dio.post('/auth/refresh-token', data: {
      'refresh_token': refreshToken,
    });

    await storage.write(key: 'access_token', value: resp.data['access_token']);
    await storage.write(key: 'refresh_token', value: resp.data['refresh_token']);
    return true;
  } catch (_) {
    return false;
  }
}

final apiClient = createDioClient();
