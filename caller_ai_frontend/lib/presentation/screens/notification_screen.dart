import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {'type': 'voicemail', 'title': 'New voicemail received', 'body': 'New recorded voicemail from +91 98765 43210', 'time': '2m ago'},
      {'type': 'spam', 'title': 'Spam detected', 'body': 'Potential telemarketer call identified in recent lookups', 'time': '15m ago'},
      {'type': 'voicemail', 'title': 'Voicemail saved', 'body': 'Voicemail recording ready to play in your inbox', 'time': '1h ago'},
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final n = notifications[i];
          final icon = n['type'] == 'spam'
              ? Icons.shield_rounded
              : Icons.voicemail_rounded;
          final color = n['type'] == 'spam'
              ? AppColors.spamHigh
              : AppColors.primary;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(n['body']!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(n['time']!, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}
