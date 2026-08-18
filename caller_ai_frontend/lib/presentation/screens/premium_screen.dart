import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlan = 1; // 0=monthly, 1=yearly, 2=lifetime

  final _plans = [
    {'label': 'Monthly', 'price': '\$4.99', 'period': '/month', 'desc': 'Billed monthly, cancel anytime', 'badge': null},
    {'label': 'Yearly', 'price': '\$39.99', 'period': '/year', 'desc': 'Billed annually', 'badge': 'SAVE 33%'},
    {'label': 'Lifetime', 'price': '\$99.99', 'period': '', 'desc': 'One-time payment, forever access', 'badge': null},
  ];

  final _features = [
    {'feature': 'AI Calls/Month', 'free': '10', 'premium': 'Unlimited'},
    {'feature': 'Ads', 'free': 'Yes', 'premium': 'None'},
    {'feature': 'Busy Mode', 'free': '✗', 'premium': '✓'},
    {'feature': 'WhatsApp Diversion', 'free': '✗', 'premium': '✓'},
    {'feature': 'Spam Protection', 'free': 'Basic', 'premium': 'AI-Powered'},
    {'feature': 'Voice Search', 'free': '✗', 'premium': '✓'},
    {'feature': 'Priority Support', 'free': '✗', 'premium': '✓'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Go Premium')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gold, AppColors.goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Unlock the Full Power\nof Caller AI',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No ads, unlimited AI calls, advanced protection',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pricing cards
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _plans.length,
                itemBuilder: (ctx, i) {
                  final plan = _plans[i];
                  final selected = _selectedPlan == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPlan = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.gold.withOpacity(0.1) : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppColors.gold : AppColors.bgSurface,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (plan['badge'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plan['badge'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const Spacer(),
                          Text(plan['label'] as String, style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13,
                          )),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(plan['price'] as String, style: TextStyle(
                                color: selected ? AppColors.gold : Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              )),
                              Text(plan['period'] as String, style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12,
                              )),
                            ],
                          ),
                          Text(plan['desc'] as String, style: TextStyle(
                            color: AppColors.textMuted, fontSize: 10,
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Feature comparison
            Container(
              decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        Expanded(child: Center(child: Text('Free', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))),
                        Expanded(child: Center(child: Text('Premium', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.bgSurface, height: 1),
                  ..._features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(f['feature']!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                        Expanded(child: Center(child: Text(f['free']!,
                          style: TextStyle(
                            color: f['free'] == '✗' ? AppColors.textMuted : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ))),
                        Expanded(child: Center(child: Text(f['premium']!,
                          style: TextStyle(
                            color: f['premium'] == '✓' || f['premium'] == 'Unlimited'
                                ? AppColors.success
                                : AppColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Subscribe Now - ${_plans[_selectedPlan]['price']}${_plans[_selectedPlan]['period']}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () {}, child: Text('Restore Purchases', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                Text('·', style: TextStyle(color: AppColors.textMuted)),
                TextButton(onPressed: () {}, child: Text('Terms', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
