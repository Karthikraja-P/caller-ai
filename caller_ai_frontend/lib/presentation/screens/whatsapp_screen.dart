import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});
  @override State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  Map<String, dynamic>? _status;
  List<dynamic> _diversions = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiClient.get('/whatsapp/status').then((r) => r.data),
        apiClient.get('/whatsapp/history').then((r) => r.data),
      ]);
      setState(() {
        _status = results[0] as Map<String, dynamic>;
        _diversions = (results[1] as Map)['diversions'] ?? [];
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status?['connected'] == true;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('WhatsApp Bridge'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: connected ? AppColors.success : AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connection card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: connected
                            ? AppColors.whatsapp.withOpacity(0.3)
                            : AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.whatsapp.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.chat_rounded, color: AppColors.whatsapp, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connected ? 'WhatsApp Connected' : 'Not Connected',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              if (_status?['phone_number'] != null)
                                Text(_status!['phone_number'], style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _load,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.whatsapp),
                            foregroundColor: AppColors.whatsapp,
                          ),
                          child: const Text('Test'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active diversions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Diversions', style: Theme.of(context).textTheme.titleMedium),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Contact'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.whatsapp),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_diversions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'No active diversions.\nAdd a contact to divert calls to WhatsApp.',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...(_diversions.map((d) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.whatsapp.withOpacity(0.2),
                            child: Text(
                              (d['contact_name'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: AppColors.whatsapp),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['contact_name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                                Text(d['contact_number'] ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: d['is_active'] == true,
                            onChanged: (v) async {
                              if (v) {
                                await apiClient.post('/whatsapp/divert', data: {'phone_number': d['contact_number']});
                              } else {
                                await apiClient.delete('/whatsapp/divert/${d['contact_number']}');
                              }
                              _load();
                            },
                            activeColor: AppColors.whatsapp,
                          ),
                        ],
                      ),
                    ))).toList(),
                ],
              ),
            ),
    );
  }
}
