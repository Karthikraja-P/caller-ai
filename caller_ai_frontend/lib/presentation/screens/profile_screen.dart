import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _subscription;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiClient.get('/users/profile').then((r) => r.data),
        apiClient.get('/users/subscription').then((r) => r.data),
      ]);
      setState(() {
        _profile = results[0];
        _subscription = results[1];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(child: CircularProgressIndicator()),
    );

    final p = _profile ?? {};
    final sub = _subscription ?? {};
    final plan = sub['plan'] ?? 'free';
    final features = sub['features'] as Map<String, dynamic>? ?? {};
    final aiUsed = features['ai_calls_used'] ?? 0;
    final aiLimit = features['ai_agent_limit'] ?? 10;
    final isPremium = plan == 'premium';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Profile & Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    (p['display_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(p['display_name'] ?? 'No Name', style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                )),
                Text(p['phone_number'] ?? '', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Profile'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subscription card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPremium
                      ? [AppColors.gold.withOpacity(0.2), AppColors.goldDark.withOpacity(0.1)]
                      : [AppColors.bgCard, AppColors.bgCard],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPremium ? AppColors.gold.withOpacity(0.4) : AppColors.bgSurface,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isPremium ? Icons.workspace_premium_rounded : Icons.person_rounded,
                        color: isPremium ? AppColors.gold : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPremium ? 'Premium Plan' : 'Free Plan',
                        style: TextStyle(
                          color: isPremium ? AppColors.gold : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (!isPremium) ...[
                    const SizedBox(height: 12),
                    Text('AI Calls: $aiUsed / $aiLimit used', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: aiLimit > 0 ? aiUsed / aiLimit : 0,
                        backgroundColor: AppColors.bgSurface,
                        color: aiUsed >= aiLimit ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/premium'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                        child: const Text('Upgrade to Premium', style: TextStyle(color: Colors.black)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data & Privacy
            Container(
              decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.contacts_rounded, color: AppColors.primary),
                    title: const Text('Collected Contacts', style: TextStyle(color: Colors.white)),
                    subtitle: Text('Manage contact data', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                  ),
                  const Divider(color: AppColors.bgSurface, height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                    title: const Text('Download My Data', style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 14),
                    onTap: () {},
                  ),
                  const Divider(color: AppColors.bgSurface, height: 1, indent: 60),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                    title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
        content: Text(
          'This will permanently delete your account. You have 30 days to recover it.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await apiClient.delete('/users/profile');
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/otp', (_) => false);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
