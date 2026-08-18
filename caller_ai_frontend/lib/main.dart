import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/env.dart';
import 'presentation/blocs/auth_bloc.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/otp_verification_screen.dart';
import 'presentation/screens/profile_creation_screen.dart';
import 'presentation/screens/ai_agent_setup_screen.dart';
import 'presentation/screens/permission_setup_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/call_log_screen.dart';
import 'presentation/screens/number_search_screen.dart';
import 'presentation/screens/ai_agent_screen.dart';
import 'presentation/screens/ai_call_history_screen.dart';
import 'presentation/screens/spam_center_screen.dart';
import 'presentation/screens/whatsapp_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/premium_screen.dart';
import 'presentation/screens/notification_screen.dart';
import 'presentation/screens/call_overlay_screen.dart';
import 'presentation/screens/ai_voice_call_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  runApp(const CallerAIApp());
}

class CallerAIApp extends StatelessWidget {
  const CallerAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
      ],
      child: MaterialApp(
        title: 'Caller AI',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
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

      case '/ai-agent-setup':
        return MaterialPageRoute(builder: (_) => const AIAgentSetupScreen());

      case '/permissions':
        return MaterialPageRoute(builder: (_) => const PermissionSetupScreen());

      case '/onboarding':
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case '/dashboard':
        return MaterialPageRoute(builder: (_) => const DashboardScreen());

      case '/call-log':
        return MaterialPageRoute(builder: (_) => const CallLogScreen());

      case '/number-search':
        return MaterialPageRoute(builder: (_) => const NumberSearchScreen());

      case '/ai-agent':
        return MaterialPageRoute(builder: (_) => const AIAgentScreen());

      case '/ai-call-history':
        return MaterialPageRoute(builder: (_) => const AICallHistoryScreen());

      case '/spam-center':
        return MaterialPageRoute(builder: (_) => const SpamCenterScreen());

      case '/whatsapp':
        return MaterialPageRoute(builder: (_) => const WhatsAppScreen());

      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case '/premium':
        return MaterialPageRoute(builder: (_) => const PremiumScreen());

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
          ),
        );

      case '/ai-voice-call':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AIVoiceCallScreen(
            callerNumber: args?['callerNumber'] ?? 'Unknown',
            agentName: args?['agentName'] ?? 'Max',
            callType: args?['callType'] ?? 'spam',
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
