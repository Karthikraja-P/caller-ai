import 'package:caller_ai/presentation/screens/call_overlay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester t, {required bool previewOnly}) => t.pumpWidget(
        MaterialApp(
          home: CallOverlayScreen(
            callerNumber: '+10000000000',
            callerName: 'Unknown caller',
            previewOnly: previewOnly,
          ),
        ),
      );

  testWidgets('preview hides actions that call backend or AI', (t) async {
    await pump(t, previewOnly: true);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Block'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Voicemail'), findsNothing);
  });

  testWidgets('default mode keeps all actions', (t) async {
    await pump(t, previewOnly: false);
    expect(find.text('Block'), findsOneWidget);
    expect(find.text('Voicemail'), findsOneWidget);
  });
}
