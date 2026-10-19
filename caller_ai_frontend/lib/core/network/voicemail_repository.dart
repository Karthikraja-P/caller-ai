import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/voicemail.dart';
import '../env.dart';
import 'dio_client.dart';

class VoicemailRepository {
  final Dio dio;
  final FlutterSecureStorage _storage;

  VoicemailRepository({Dio? dio, FlutterSecureStorage? storage})
      : dio = dio ?? createDioClient(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<List<Voicemail>> getMessages({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    final response = await dio.get('/voicemail/messages', queryParameters: {
      'page': page,
      'per_page': perPage,
      'unread_only': unreadOnly,
    });
    final data = response.data;
    if (data is Map<String, dynamic> && data['messages'] is List) {
      return (data['messages'] as List)
          .map((item) => Voicemail.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Voicemail> getMessageDetail(String id) async {
    final response = await dio.get('/voicemail/messages/$id');
    return Voicemail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markAsRead(String id, {bool isRead = true}) async {
    await dio.patch('/voicemail/messages/$id/read', data: {'is_read': isRead});
  }

  Future<void> deleteVoicemail(String id) async {
    await dio.delete('/voicemail/messages/$id');
  }

  String getAudioPlaybackUrl(String id) {
    return '${AppEnv.apiBaseUrl}/voicemail/messages/$id/audio';
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: 'access_token');
  }
}
