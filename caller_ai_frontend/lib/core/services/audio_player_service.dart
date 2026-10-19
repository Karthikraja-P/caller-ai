import 'dart:async';
import 'package:just_audio/just_audio.dart';

abstract class AudioPlayerAdapter {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  Future<void> playUrl(String url, {Map<String, String>? headers});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioPlayerAdapter implements AudioPlayerAdapter {
  final AudioPlayer _player;

  JustAudioPlayerAdapter({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> playUrl(String url, {Map<String, String>? headers}) async {
    await _player.setUrl(url, headers: headers);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
