import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({super.key});
  @override
  State<AIAgentScreen> createState() => _AIAgentScreenState();
}

class _AIAgentScreenState extends State<AIAgentScreen> {
  Map<String, dynamic>? _config;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await apiClient.get('/ai/agent/config');
      setState(() { _config = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _config?[key] = value);
    await apiClient.post('/ai/agent/config', data: {
      ..._config ?? {},
      key: value,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(child: CircularProgressIndicator()),
    );

    if (_config == null) return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('AI Agent')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('No AI agent configured', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/ai-agent-setup'),
              child: const Text('Set Up AI Agent'),
            ),
          ],
        ),
      ),
    );

    final agentName = _config!['agent_name'] ?? 'Assistant';
    final spamEnabled = _config!['spam_handling_enabled'] as bool? ?? true;
    final busyEnabled = _config!['busy_mode_enabled'] as bool? ?? false;
    final waEnabled = _config!['whatsapp_diversion_enabled'] as bool? ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('AI Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.pushNamed(context, '/ai-agent-setup'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Agent identity card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.aiBlue.withOpacity(0.2), AppColors.aiPurple.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.aiBlue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.aiBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: AppColors.aiBlue, size: 44),
                  ),
                  const SizedBox(height: 12),
                  Text(agentName, style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: spamEnabled ? AppColors.success.withOpacity(0.15) : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      spamEnabled ? 'Active - Spam Handling ON' : 'Standby',
                      style: TextStyle(
                        color: spamEnabled ? AppColors.success : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Call handling toggles
            _sectionCard('Call Handling', [
              _toggleRow('Spam Handling', 'AI attends spam calls and extracts details',
                spamEnabled, Icons.security_rounded, AppColors.error,
                (v) => _toggle('spam_handling_enabled', v),
              ),
              const Divider(color: AppColors.bgSurface, height: 1),
              _toggleRow('Busy Mode', 'AI attends calls when you\'re unavailable',
                busyEnabled, Icons.access_time_rounded, AppColors.warning,
                (v) => _toggle('busy_mode_enabled', v),
              ),
              const Divider(color: AppColors.bgSurface, height: 1),
              _toggleRow('WhatsApp Diversion', 'Divert calls to WhatsApp when busy',
                waEnabled, Icons.chat_rounded, AppColors.whatsapp,
                (v) => _toggle('whatsapp_diversion_enabled', v),
              ),
            ]),
            const SizedBox(height: 16),

            // Recent AI activity
            _sectionHeader('Recent AI Activity', onTap: () {
              Navigator.pushNamed(context, '/ai-call-history');
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.call_outlined, size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'No AI calls yet.\nEnable spam handling to get started.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      ),
    ],
  );

  Widget _sectionHeader(String title, {VoidCallback? onTap}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (onTap != null)
        TextButton(onPressed: onTap, child: Text('View All', style: TextStyle(color: AppColors.primary))),
    ],
  );

  Widget _toggleRow(String label, String desc, bool value, IconData icon, Color color, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(desc, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
