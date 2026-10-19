import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caller_ai/core/models/voicemail.dart';
import 'package:caller_ai/core/network/voicemail_repository.dart';
import 'package:caller_ai/core/services/audio_player_service.dart';
import 'package:caller_ai/presentation/blocs/voicemail_bloc.dart';
import 'package:caller_ai/presentation/screens/voicemail_inbox_screen.dart';
import 'package:caller_ai/presentation/screens/voicemail_detail_screen.dart';

class FakeAudioPlayerAdapter implements AudioPlayerAdapter {
  final _posController = StreamController<Duration>.broadcast();
  final _durController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  bool isPlaying = false;
  String? lastPlayedUrl;
  Map<String, String>? lastHeaders;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Stream<Duration?> get durationStream => _durController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Future<void> playUrl(String url, {Map<String, String>? headers}) async {
    lastPlayedUrl = url;
    lastHeaders = headers;
    isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> resume() async {
    isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    _posController.add(position);
  }

  @override
  Future<void> dispose() async {
    await _posController.close();
    await _durController.close();
    await _playingController.close();
  }
}

class FakeVoicemailRepository extends VoicemailRepository {
  List<Voicemail> messages = [];
  bool shouldThrowOnFetch = false;
  bool shouldThrowOnDelete = false;
  Completer<List<Voicemail>>? fetchCompleter;

  FakeVoicemailRepository({List<Voicemail>? initialMessages, this.fetchCompleter})
      : messages = initialMessages != null ? List.from(initialMessages) : [],
        super();

  @override
  Future<List<Voicemail>> getMessages({int page = 1, int perPage = 20, bool unreadOnly = false}) async {
    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }
    if (shouldThrowOnFetch) throw Exception('Network connection failed');
    if (unreadOnly) {
      return messages.where((m) => !m.isRead).toList();
    }
    return List.from(messages);
  }

  @override
  Future<void> markAsRead(String id, {bool isRead = true}) async {
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      messages[idx] = messages[idx].copyWith(isRead: isRead);
    }
  }

  @override
  Future<void> deleteVoicemail(String id) async {
    if (shouldThrowOnDelete) throw Exception('Telephony provider failed to delete media');
    messages.removeWhere((m) => m.id == id);
  }

  @override
  String getAudioPlaybackUrl(String id) {
    return 'https://api.callerai.app/api/v1/voicemail/messages/$id/audio';
  }

  @override
  Future<String?> getAuthToken() async {
    return 'fake-bearer-token';
  }
}

void main() {
  final sampleVoicemail1 = Voicemail(
    id: 'vm-1',
    callerNumber: '+15551234567',
    destinationNumber: '+15559876543',
    durationSeconds: 32,
    status: 'completed',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
  );

  final sampleVoicemail2 = Voicemail(
    id: 'vm-2',
    callerNumber: '+15559998888',
    destinationNumber: '+15559876543',
    durationSeconds: 15,
    status: 'completed',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  );

  Widget createTestWidget(VoicemailBloc bloc, {Widget? child}) {
    return MaterialApp(
      home: BlocProvider<VoicemailBloc>.value(
        value: bloc,
        child: child ?? const VoicemailInboxScreen(),
      ),
    );
  }

  group('VoicemailInboxScreen Widget Tests', () {
    testWidgets('renders loading state initially', (tester) async {
      final completer = Completer<List<Voicemail>>();
      final repo = FakeVoicemailRepository(fetchCompleter: completer);
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No voicemails yet'), findsOneWidget);
    });

    testWidgets('renders empty state when messages list is empty', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: []);
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pumpAndSettle();

      expect(find.text('No voicemails yet'), findsOneWidget);
      expect(find.text('When callers leave a recorded message, it will appear here.'), findsOneWidget);
    });

    testWidgets('renders error state and retries on button press', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: []);
      repo.shouldThrowOnFetch = true;
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load voicemails. Please check your connection.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix error and retry
      repo.shouldThrowOnFetch = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No voicemails yet'), findsOneWidget);
    });

    testWidgets('renders populated voicemail list with caller numbers and durations', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: [sampleVoicemail1, sampleVoicemail2]);
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pumpAndSettle();

      expect(find.text('+15551234567'), findsOneWidget);
      expect(find.text('+15559998888'), findsOneWidget);
      expect(find.text('0:32'), findsOneWidget);
      expect(find.text('0:15'), findsOneWidget);
    });

    testWidgets('tapping play button starts audio playback with Bearer token', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: [sampleVoicemail1]);
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pumpAndSettle();

      // Find and tap play button
      final playButton = find.byIcon(Icons.play_circle_fill_rounded);
      expect(playButton, findsOneWidget);

      await tester.tap(playButton);
      await tester.pumpAndSettle();

      expect(player.isPlaying, isTrue);
      expect(player.lastPlayedUrl, 'https://api.callerai.app/api/v1/voicemail/messages/vm-1/audio');
      expect(player.lastHeaders?['Authorization'], 'Bearer fake-bearer-token');
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('delete flow shows dialog, and handles provider failure gracefully with retry', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: [sampleVoicemail1]);
      repo.shouldThrowOnDelete = true;
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pumpAndSettle();

      // Tap delete icon
      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('Delete Voicemail?'), findsOneWidget);

      // Confirm delete in dialog
      final confirmDelete = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      // Since provider failed, metadata is kept!
      expect(find.text('+15551234567'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Telephony provider failed to delete recording'), findsOneWidget);
    });

    testWidgets('successful delete removes message from list', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: [sampleVoicemail1]);
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(createTestWidget(bloc));
      await tester.pumpAndSettle();

      final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      final confirmDelete = find.widgetWithText(ElevatedButton, 'Delete');
      await tester.tap(confirmDelete);
      await tester.pumpAndSettle();

      expect(find.text('+15551234567'), findsNothing);
      expect(find.text('No voicemails yet'), findsOneWidget);
    });
  });

  group('VoicemailDetailScreen Widget Tests', () {
    testWidgets('renders voicemail details and playback controls', (tester) async {
      final repo = FakeVoicemailRepository(initialMessages: [sampleVoicemail1]);
      final player = FakeAudioPlayerAdapter();
      final bloc = VoicemailBloc(repository: repo, audioPlayer: player);

      await tester.pumpWidget(
        createTestWidget(
          bloc,
          child: VoicemailDetailScreen(voicemail: sampleVoicemail1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+15551234567'), findsNWidgets(2)); // Title and callback subtitle
      expect(find.text('Voicemail Details'), findsOneWidget);
      expect(find.text('Mark as Read'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.replay_5_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_5_rounded), findsOneWidget);
    });
  });
}
