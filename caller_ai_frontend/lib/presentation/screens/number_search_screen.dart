import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class NumberSearchScreen extends StatefulWidget {
  const NumberSearchScreen({super.key});
  @override
  State<NumberSearchScreen> createState() => _NumberSearchScreenState();
}

class _NumberSearchScreenState extends State<NumberSearchScreen> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  final List<String> _recent = ['+91 98765 43210', '+1 415 555 2671'];

  Future<void> _search() async {
    if (_controller.text.isEmpty) return;
    setState(() { _loading = true; _result = null; });
    try {
      final resp = await apiClient.get('/lookup', queryParameters: {
        'phone_number': '+91${_controller.text.replaceAll(' ', '')}',
      });
      setState(() { _result = resp.data; _loading = false; });
      if (!_recent.contains(_controller.text)) {
        setState(() => _recent.insert(0, _controller.text));
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Number Search')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search input
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('+91', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(hintText: 'Enter phone number'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent chips
            if (_recent.isNotEmpty) ...[
              Text('Recent Searches', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _recent.map((r) => GestureDetector(
                  onTap: () { _controller.text = r.replaceAll('+91 ', ''); _search(); },
                  child: Chip(
                    label: Text(r, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: AppColors.bgSurface,
                    side: BorderSide.none,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Loading shimmer
            if (_loading) Shimmer.fromColors(
              baseColor: AppColors.bgCard,
              highlightColor: AppColors.bgSurface,
              child: Container(height: 300, decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
              )),
            ),

            // Result card
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    final name = r['caller_name'] ?? 'Unknown Caller';
    final carrier = r['carrier'] ?? 'Unknown';
    final country = r['country'] ?? 'Unknown';
    final lineType = r['line_type'] ?? 'Unknown';
    final spam = r['spam_analytics'] as Map<String, dynamic>? ?? {};
    final score = spam['score'] as int? ?? 0;
    final categories = (spam['categories'] as List?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + badge
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                )),
              ),
              if (r['verification_status'] == 'verified')
                const Icon(Icons.verified, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 4),
          Text('+91 ${_controller.text}', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Info grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _infoItem(Icons.signal_cellular_alt, 'Carrier', carrier),
              _infoItem(Icons.map, 'Country', country),
              _infoItem(Icons.phone_android, 'Type', lineType),
              _infoItem(Icons.access_time, 'Latency', '${r['latency_ms']}ms'),
            ],
          ),
          const SizedBox(height: 20),

          // Spam score
          Text('Spam Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                score > 70 ? AppColors.spamHigh : score > 40 ? AppColors.spamMedium : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$score/100', style: TextStyle(
                color: score > 70 ? AppColors.spamHigh : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              )),
              Row(
                children: categories.take(3).map((c) => Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.spamHigh.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(c, style: const TextStyle(color: AppColors.spamHigh, fontSize: 11)),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              _actionBtn(Icons.block, 'Block', AppColors.error, () {
                apiClient.post('/blocklist', data: {'phone_number': '+91${_controller.text}'});
              }),
              const SizedBox(width: 8),
              _actionBtn(Icons.flag, 'Report', AppColors.warning, () {
                apiClient.post('/spam/report', data: {
                  'reported_number': '+91${_controller.text}',
                  'category': 'Other',
                });
              }),
              const SizedBox(width: 8),
              _actionBtn(Icons.smart_toy_rounded, 'AI Handle', AppColors.aiBlue, () {}),
              const SizedBox(width: 8),
              _actionBtn(Icons.chat, 'WhatsApp', AppColors.whatsapp, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 6),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    ],
  );

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
}
