import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class SpamCenterScreen extends StatefulWidget {
  const SpamCenterScreen({super.key});
  @override State<SpamCenterScreen> createState() => _SpamCenterScreenState();
}

class _SpamCenterScreenState extends State<SpamCenterScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await apiClient.get('/spam/stats');
      setState(() { _stats = r.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _showReportSheet() {
    final controller = TextEditingController();
    String category = 'Telemarketer';
    final categories = ['Telemarketer', 'Fraud', 'Robocall', 'Scam', 'Loan', 'Trading', 'Shopping', 'Political', 'Survey', 'Other'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report a Number', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: AppColors.bgSurface,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setModal(() => category = v ?? 'Other'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await apiClient.post('/spam/report', data: {
                      'reported_number': controller.text,
                      'category': category,
                    });
                    if (mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted!')),
                    );
                    _load();
                  },
                  child: const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats ?? {};
    final blocked = stats['total_blocked'] ?? 0;
    final reported = stats['reports_submitted'] ?? 0;
    final accuracy = stats['detection_accuracy'] ?? 94.2;
    final topCats = (stats['top_categories'] as List? ?? []);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Spam Center')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showReportSheet,
        backgroundColor: AppColors.error,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Protection summary card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.success.withOpacity(0.15), AppColors.success.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100, height: 100,
                              child: CircularProgressIndicator(
                                value: accuracy / 100,
                                strokeWidth: 8,
                                backgroundColor: AppColors.bgSurface,
                                color: AppColors.success,
                              ),
                            ),
                            Text(
                              '${accuracy.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your phone is ${accuracy.toStringAsFixed(0)}% protected from spam calls',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statChip('$blocked Blocked', AppColors.error),
                            _statChip('$reported Reported', AppColors.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category chips
                  if (topCats.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Top Spam Categories', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: topCats.map((cat) {
                        final colors = {
                          'Telemarketer': AppColors.spamHigh,
                          'Loan': AppColors.spamMedium,
                          'Fraud': const Color(0xFF7F1D1D),
                          'Trading': AppColors.spamLow,
                          'Scam': const Color(0xFF7C3AED),
                          'Shopping': AppColors.primary,
                        };
                        final color = colors[cat['category']] ?? AppColors.textMuted;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${cat['category']} (${cat['count']})',
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
