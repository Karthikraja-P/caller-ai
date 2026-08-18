import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../blocs/auth_bloc.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTab = 0;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _agentConfig;
  Map<String, dynamic>? _spamStats;
  List<dynamic> _recentCalls = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiClient.get('/users/profile').then((r) => r.data),
        apiClient.get('/ai/agent/config').then((r) => r.data).catchError((_) => null),
        apiClient.get('/spam/stats').then((r) => r.data),
        apiClient.get('/lookup/recent').then((r) => r.data),
      ]);
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _agentConfig = results[1] as Map<String, dynamic>?;
        _spamStats = results[2] as Map<String, dynamic>?;
        final recentData = results[3] as Map<String, dynamic>?;
        _recentCalls = recentData?['lookups'] ?? [];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading ? _buildShimmer() : _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    final name = _profile?['display_name'] ?? 'User';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Caller AI', style: TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
          )),
          const Spacer(),
          // Notification
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          // Avatar
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            _buildSearchBar(),
            const SizedBox(height: 16),

            // Stats row
            _buildStatsRow(),
            const SizedBox(height: 16),

            // AI Agent card
            if (_agentConfig != null) _buildAIAgentCard(),
            const SizedBox(height: 16),

            // Recent calls
            _buildRecentCalls(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/number-search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgCard),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Text(
              'Enter number to identify...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.flag, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('+91', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      {
        'value': _recentCalls.length.toString(),
        'label': 'Total Lookups',
        'color': AppColors.primary,
        'icon': Icons.search,
      },
      {
        'value': (_agentConfig != null ? '12' : '0'),
        'label': 'AI Handled',
        'color': AppColors.success,
        'icon': Icons.smart_toy_rounded,
      },
      {
        'value': (_spamStats?['total_blocked'] ?? 0).toString(),
        'label': 'Spam Blocked',
        'color': AppColors.error,
        'icon': Icons.shield_rounded,
      },
    ];

    return Row(
      children: stats.map((s) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20),
              const SizedBox(height: 8),
              Text(
                s['value'] as String,
                style: TextStyle(
                  color: s['color'] as Color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s['label'] as String,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildAIAgentCard() {
    final agentName = _agentConfig!['agent_name'] ?? 'Assistant';
    final isActive = _agentConfig!['spam_handling_enabled'] == true;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/ai-agent'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.aiBlue.withOpacity(0.2), AppColors.aiPurple.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.aiBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.aiBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.aiBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agentName, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.success : AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'Active - Spam Handling ON' : 'Standby',
                        style: TextStyle(
                          color: isActive ? AppColors.success : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCalls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Calls', style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/call-log'),
              child: Text('See All', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentCalls.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.call_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 8),
                Text(
                  'No recent calls',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentCalls.length.clamp(0, 8),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _buildCallItem(_recentCalls[i]),
          ),
      ],
    );
  }

  Widget _buildCallItem(Map<String, dynamic> call) {
    final phone = call['phone_number'] ?? '';
    final name = call['caller_name'] ?? phone;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                Text(phone, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.call_received, color: AppColors.success, size: 16),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.bgCard,
      highlightColor: AppColors.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(5, (_) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
          )),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    const tabs = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.history_rounded, 'label': 'Call Log'},
      {'icon': Icons.smart_toy_rounded, 'label': 'AI Agent'},
      {'icon': Icons.shield_rounded, 'label': 'Spam'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    const routes = [null, '/call-log', '/ai-agent', '/spam-center', '/settings'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedTab = i);
                    final route = routes[i];
                    if (route != null) Navigator.pushNamed(context, route);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[i]['icon'] as IconData,
                        color: selected ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i]['label'] as String,
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
