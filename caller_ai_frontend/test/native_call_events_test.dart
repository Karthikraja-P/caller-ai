import 'package:caller_ai/main.dart';
import 'package:caller_ai/presentation/screens/call_overlay_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channelName = 'com.callerai/calls';
const _codec = StandardMethodCodec();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> emit(WidgetTester t, Object? event) async {
    await messenger.handlePlatformMessage(
      _channelName,
      _codec.encodeSuccessEnvelope(event),
      (_) {},
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> emitError(WidgetTester t) async {
    await messenger.handlePlatformMessage(
      _channelName,
      _codec.encodeErrorEnvelope(code: 'boom', message: 'bad'),
      (_) {},
    );
    await t.pump();
  }

  Future<void> pumpApp(WidgetTester t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
        const MethodChannel(_channelName), (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel(_channelName), null));
    await t.pumpWidget(const CallerAIApp(initialRoute: 'test-home'));
    await t.pump();
  }

  // Foundation invariants are checked before tearDown callbacks run, so the
  // platform override must be cleared inside the test body.
  void scenario(String name, Future<void> Function(WidgetTester t) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Finder overlay() => find.byType(CallOverlayScreen);

  scenario('incoming opens preview once; duplicate is ignored', (t) async {
    await pumpApp(t);
    expect(overlay(), findsNothing);

    await emit(t, {'event': 'incoming', 'number': '+15551234567'});
    expect(overlay(), findsOneWidget);
    expect(find.text('+15551234567'), findsWidgets);
    expect(find.text('Block'), findsNothing); // previewOnly

    await emit(t, {'event': 'incoming', 'number': '+15551234567'});
    await emit(t, {'event': 'incoming', 'number': '+19998887777'});
    expect(overlay(), findsOneWidget);

    // One pop returns to the home route, proving only one route was pushed.
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await t.pumpAndSettle();
    expect(overlay(), findsNothing);
    expect(find.textContaining('Route not found'), findsOneWidget);
  });

  scenario('blank or missing number shows Unknown', (t) async {
    await pumpApp(t);
    await emit(t, {'event': 'incoming', 'number': '  '});
    expect(overlay(), findsOneWidget);
    expect(find.text('Unknown'), findsWidgets);
  });

  for (final kind in ['answered', 'missed', 'ended']) {
    scenario('$kind closes the preview', (t) async {
      await pumpApp(t);
      await emit(t, {'event': 'incoming', 'number': '+15551234567'});
      expect(overlay(), findsOneWidget);

      await emit(t, {'event': kind, 'number': '+15551234567'});
      await t.pumpAndSettle();
      expect(overlay(), findsNothing);
      expect(find.textContaining('Route not found'), findsOneWidget);
    });
  }

  scenario('terminal event without preview is a no-op', (t) async {
    await pumpApp(t);
    await emit(t, {'event': 'ended'});
    await emit(t, {'event': 'missed'});
    expect(overlay(), findsNothing);
    expect(find.textContaining('Route not found'), findsOneWidget);
  });

  scenario('a new incoming call can open a preview after close', (t) async {
    await pumpApp(t);
    await emit(t, {'event': 'incoming', 'number': '+1'});
    await emit(t, {'event': 'ended'});
    await t.pumpAndSettle();
    expect(overlay(), findsNothing);
    await emit(t, {'event': 'incoming', 'number': '+2'});
    expect(overlay(), findsOneWidget);
  });

  scenario('malformed events and stream errors are ignored', (t) async {
    await pumpApp(t);
    for (final bad in <Object?>[
      null,
      'incoming',
      42,
      ['incoming'],
      <String, Object?>{},
      {'event': null},
      {'event': 42},
      {'event': 'ringing'},
      {'number': '+1'},
    ]) {
      await emit(t, bad);
    }
    await emitError(t);
    expect(overlay(), findsNothing);
    expect(t.takeException(), isNull);

    await emit(t, {'event': 'incoming', 'number': '+1'});
    expect(overlay(), findsOneWidget);

    // Malformed events don't close an open preview.
    await emit(t, {'event': 'bogus'});
    await emit(t, 'ended');
    await emitError(t);
    expect(overlay(), findsOneWidget);
  });

  scenario('replayed queue burst keeps order and accepts extra fields', (t) async {
    await pumpApp(t);
    // Native replays queued events in order on subscribe; they carry id/timestamp.
    await emit(t, {'event': 'incoming', 'number': '+1', 'id': 1, 'timestamp': 10});
    expect(overlay(), findsOneWidget);
    await emit(t, {'event': 'missed', 'number': '+1', 'id': 2, 'timestamp': 11});
    await t.pumpAndSettle();
    expect(overlay(), findsNothing);
    await emit(t, {'event': 'incoming', 'number': '+2', 'id': 3, 'timestamp': 12});
    expect(overlay(), findsOneWidget);
    expect(find.text('+2'), findsWidgets);
  });
}
