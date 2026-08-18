import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});
  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  List<dynamic> _calls = [];
  bool _loading = true;
  String _filter = 'all'; // all | missed | ai_handled | spam | blocked

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await apiClient.get('/lookup/recent');
      setState(() {
        _calls = resp.data['lookups'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Call Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.call_outlined, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          'No calls yet.\nCaller AI will log calls as they come in.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildList() => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: _calls.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (ctx, i) => _buildCallItem(_calls[i]),
  );

  Widget _buildCallItem(Map<String, dynamic> call) {
    final name = call['caller_name'] ?? call['phone_number'] ?? 'Unknown';
    final phone = call['phone_number'] ?? '';
    return Dismissible(
      key: Key(phone + i.toString()),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.thumb_down, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: AppColors.bgSurface,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.more_horiz, color: Colors.white),
      ),
      onDismissed: (dir) {
        if (dir == DismissDirection.startToEnd) {
          apiClient.post('/spam/report', data: {
            'reported_number': phone,
            'category': 'Other',
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reported as spam')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(phone, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Now', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                const Icon(Icons.call_received, color: AppColors.success, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  get i => 0;

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Calls', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            ...['All', 'Missed', 'AI Handled', 'Spam', 'Blocked'].map((f) =>
              ListTile(
                title: Text(f, style: const TextStyle(color: Colors.white)),
                trailing: _filter.toLowerCase() == f.toLowerCase()
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _filter = f.toLowerCase());
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
