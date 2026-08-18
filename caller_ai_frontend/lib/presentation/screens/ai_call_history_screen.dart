import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class AICallHistoryScreen extends StatefulWidget {
  const AICallHistoryScreen({super.key});
  @override State<AICallHistoryScreen> createState() => _AICallHistoryScreenState();
}

class _AICallHistoryScreenState extends State<AICallHistoryScreen> {
  List<dynamic> _calls = [];
  bool _loading = true;
  int? _expandedIndex;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await apiClient.get('/ai/call/history');
      setState(() { _calls = r.data['calls'] ?? []; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('AI Call History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          "Your AI agent hasn't handled any calls yet.\nEnable spam handling or busy mode to get started.",
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _calls.length,
                  itemBuilder: (ctx, i) {
                    final c = _calls[i] as Map<String, dynamic>;
                    final expanded = _expandedIndex == i;
                    final isSpam = c['call_type'] == 'spam';
                    return GestureDetector(
                      onTap: () => setState(() => _expandedIndex = expanded ? null : i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: expanded ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c['caller_number'] ?? 'Unknown',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSpam
                                        ? AppColors.spamHigh.withOpacity(0.2)
                                        : AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isSpam ? 'SPAM' : 'BUSY',
                                    style: TextStyle(
                                      color: isSpam ? AppColors.spamHigh : AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  expanded ? Icons.expand_less : Icons.expand_more,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (c['summary'] != null)
                              Text(
                                c['summary'] as String,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                maxLines: expanded ? null : 1,
                                overflow: expanded ? null : TextOverflow.ellipsis,
                              ),
                            if (expanded) ...[
                              const SizedBox(height: 16),
                              const Divider(color: AppColors.bgSurface),
                              const SizedBox(height: 12),
                              Text('Full Transcript', style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600,
                              )),
                              const SizedBox(height: 8),
                              ...(c['full_transcript'] as List? ?? []).map((msg) {
                                final isAI = (msg['speaker'] ?? '') == 'ai';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAI ? 'AI ${c['agent_name']}' : 'Caller',
                                        style: TextStyle(
                                          color: isAI ? AppColors.aiBlue : AppColors.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          msg['text'] ?? '',
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if ((c['extracted_entities'] as List? ?? []).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Extracted Details', style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600,
                                )),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: (c['extracted_entities'] as List).map((e) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.aiBlue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.aiBlue.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      '${e['type']}: ${e['value']}',
                                      style: const TextStyle(color: AppColors.aiBlue, fontSize: 11),
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
