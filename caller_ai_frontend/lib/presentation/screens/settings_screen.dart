import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../blocs/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      {
        'title': 'Account',
        'items': [
          {'icon': Icons.person_rounded, 'label': 'Profile & Account', 'route': '/profile', 'color': AppColors.primary},
          {'icon': Icons.workspace_premium_rounded, 'label': 'Premium Subscription', 'route': '/premium', 'color': AppColors.gold},
        ],
      },
      {
        'title': 'AI Features',
        'items': [
          {'icon': Icons.smart_toy_rounded, 'label': 'AI Agent Config', 'route': '/ai-agent', 'color': AppColors.aiBlue},
          {'icon': Icons.history_rounded, 'label': 'AI Call History', 'route': '/ai-call-history', 'color': AppColors.aiPurple},
        ],
      },
      {
        'title': 'Protection',
        'items': [
          {'icon': Icons.shield_rounded, 'label': 'Spam Center', 'route': '/spam-center', 'color': AppColors.spamHigh},
          {'icon': Icons.block_rounded, 'label': 'Blocked Numbers', 'route': null, 'color': AppColors.error},
        ],
      },
      {
        'title': 'Integrations',
        'items': [
          {'icon': Icons.chat_rounded, 'label': 'WhatsApp Bridge', 'route': '/whatsapp', 'color': AppColors.whatsapp},
        ],
      },
      {
        'title': 'More',
        'items': [
          {'icon': Icons.notifications_rounded, 'label': 'Notifications', 'route': '/notifications', 'color': AppColors.warning},
          {'icon': Icons.privacy_tip_rounded, 'label': 'Privacy & Data', 'route': '/profile', 'color': AppColors.info},
        ],
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...sections.map((section) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  section['title'] as String,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: (section['items'] as List).asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value as Map;
                    final isLast = i == (section['items'] as List).length - 1;
                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
                          ),
                          title: Text(item['label'] as String, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                          onTap: () {
                            final route = item['route'] as String?;
                            if (route != null) Navigator.pushNamed(context, route);
                          },
                        ),
                        if (!isLast) const Divider(color: AppColors.bgSurface, height: 1, indent: 60),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          )),

          // Logout
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              ),
              title: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text('Caller AI v2.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to log out?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
              Navigator.pushNamedAndRemoveUntil(context, '/otp', (_) => false);
            },
            child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
