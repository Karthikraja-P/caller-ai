import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/env.dart';
import 'presentation/blocs/auth_bloc.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/otp_verification_screen.dart';
import 'presentation/screens/profile_creation_screen.dart';
import 'presentation/screens/permission_setup_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/call_log_screen.dart';
import 'presentation/screens/number_search_screen.dart';
import 'presentation/screens/spam_center_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/notification_screen.dart';
import 'presentation/screens/call_overlay_screen.dart';
import 'presentation/blocs/voicemail_bloc.dart';
import 'presentation/screens/voicemail_inbox_screen.dart';
import 'presentation/screens/voicemail_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  runApp(const CallerAIApp());
}

class CallerAIApp extends StatefulWidget {
  /// Overridable so tests can avoid the splash screen's startup flow. A name
  /// without a leading '/' is not expanded into its parent routes.
  final String initialRoute;

  const CallerAIApp({super.key, this.initialRoute = '/'});

  @override
  State<CallerAIApp> createState() => _CallerAIAppState();
}

class _CallerAIAppState extends State<CallerAIApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<dynamic>? _callEventsSubscription;
  Route<void>? _activeCallPreview;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      _callEventsSubscription = const EventChannel('com.callerai/calls')
          .receiveBroadcastStream()
          .listen(_onCallEvent, onError: (Object _) {});
    }
  }

  void _onCallEvent(dynamic event) {
    if (!mounted || event is! Map) return;
    final kind = event['event'];
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    if (kind == 'incoming') {
      if (_activeCallPreview?.isActive == true) return;
      final rawNumber = event['number']?.toString().trim() ?? '';
      final callerNumber = rawNumber.isEmpty ? 'Unknown' : rawNumber;
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/call-overlay'),
        builder: (_) => CallOverlayScreen(
          callerNumber: callerNumber,
          callerName: 'Unknown caller',
          previewOnly: true,
        ),
      );
      _activeCallPreview = route;
      navigator.push(route).whenComplete(() {
        if (identical(_activeCallPreview, route)) _activeCallPreview = null;
      });
    } else if (kind == 'answered' || kind == 'missed' || kind == 'ended') {
      final route = _activeCallPreview;
      if (route != null && route.isActive) navigator.removeRoute(route);
      _activeCallPreview = null;
    }
  }

  @override
  void dispose() {
    _callEventsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<VoicemailBloc>(create: (_) => VoicemailBloc()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Caller AI',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        initialRoute: widget.initialRoute,
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/otp':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            prefillPhone: args?['prefillPhone'] as String?,
          ),
        );

      case '/profile-creation':
        return MaterialPageRoute(builder: (_) => const ProfileCreationScreen());

      case '/permissions':
        return MaterialPageRoute(builder: (_) => const PermissionSetupScreen());

      case '/onboarding':
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case '/dashboard':
        return MaterialPageRoute(builder: (_) => const DashboardScreen());

      case '/voicemail':
        return MaterialPageRoute(builder: (_) => const VoicemailInboxScreen());

      case '/voicemail-detail':
        final args = settings.arguments as Map<String, dynamic>?;
        final vm = args?['voicemail'] as Voicemail?;
        if (vm == null) {
          return MaterialPageRoute(builder: (_) => const VoicemailInboxScreen());
        }
        return MaterialPageRoute(builder: (_) => VoicemailDetailScreen(voicemail: vm));

      case '/call-log':
        return MaterialPageRoute(builder: (_) => const CallLogScreen());

      case '/number-search':
        return MaterialPageRoute(builder: (_) => const NumberSearchScreen());

      case '/spam-center':
        return MaterialPageRoute(builder: (_) => const SpamCenterScreen());

      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case '/notifications':
        return MaterialPageRoute(builder: (_) => const NotificationScreen());

      case '/call-overlay':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => CallOverlayScreen(
            callerNumber: args?['callerNumber'] ?? 'Unknown',
            callerName: args?['callerName'] ?? 'Unknown',
            spamScore: args?['spamScore'] ?? 0,
            aiHandling: args?['aiHandling'] ?? false,
            previewOnly: args?['previewOnly'] ?? false,
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.bgDark,
            body: Center(
              child: Text('Route not found: ${settings.name}',
                style: const TextStyle(color: Colors.white)),
            ),
          ),
        );
    }
  }
}
