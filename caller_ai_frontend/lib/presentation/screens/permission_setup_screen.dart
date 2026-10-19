import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  final Map<String, PermissionStatus> _statuses = {};

  final List<Map<String, dynamic>> _permissions = [
    {
      'key': 'notifications',
      'label': 'Notifications',
      'desc': 'Get alerts for incoming voicemails and security updates',
      'icon': Icons.notifications_rounded,
      'iconColor': const Color(0xFF8B5CF6),
      'required': false,
      'permission': Permission.notification,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    for (final p in _permissions) {
      final status = await (p['permission'] as Permission).status;
      setState(() => _statuses[p['key'] as String] = status);
    }
  }

  Future<void> _requestPermission(Map<String, dynamic> p) async {
    final permission = p['permission'] as Permission;
    final status = await permission.request();
    setState(() => _statuses[p['key'] as String] = status);
    if (status.isPermanentlyDenied && p['required'] == true) {
      await openAppSettings();
    }
  }

  bool get _canContinue {
    for (final p in _permissions) {
      if (p['required'] == true) {
        final s = _statuses[p['key']];
        if (s == null || s.isDenied || s.isPermanentlyDenied) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress dots
              Row(
                children: List.generate(3, (i) => Container(
                  width: i == 2 ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
              const SizedBox(height: 32),
              Text('Permissions Needed', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Enable notifications to receive alerts for new incoming voicemails',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 32),

              Expanded(
                child: ListView.separated(
                  itemCount: _permissions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final p = _permissions[i];
                    final key = p['key'] as String;
                    final status = _statuses[key];
                    final isGranted = status?.isGranted ?? false;
                    final isDenied = status?.isPermanentlyDenied ?? false;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDenied && p['required'] == true
                              ? AppColors.error.withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: (p['iconColor'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              p['icon'] as IconData,
                              color: p['iconColor'] as Color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(p['label'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (p['required'] == true) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Required',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(p['desc'] as String,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          isGranted
                              ? const Icon(Icons.check_circle, color: AppColors.success)
                              : GestureDetector(
                                  onTap: () => _requestPermission(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                    ),
                                    child: Text('Grant',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canContinue
                      ? () => Navigator.pushReplacementNamed(context, '/onboarding')
                      : null,
                  child: const Text('Continue to App'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
