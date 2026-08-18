import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Know Who Calls',
      'desc': 'Identify every caller instantly with AI-powered caller ID and spam protection. Never be caught off guard again.',
      'icon': Icons.person_search_rounded,
      'gradient': [Color(0xFF1F6C92), Color(0xFF0D4A6B)],
    },
    {
      'title': 'AI Answers Your Calls',
      'desc': 'Your AI assistant attends spam calls, extracts loan amounts, trading tips, and deals — then reports back to you.',
      'icon': Icons.smart_toy_rounded,
      'gradient': [Color(0xFF6366F1), Color(0xFF4338CA)],
    },
    {
      'title': 'Never Miss Important Calls',
      'desc': "Busy? Your AI handles calls and diverts contacts to WhatsApp automatically. Stay connected, your way.",
      'icon': Icons.forum_rounded,
      'gradient': [Color(0xFF059669), Color(0xFF047857)],
    },
    {
      'title': 'Your Privacy Matters',
      'desc': 'Transparent data collection. You control what\'s shared. GDPR & DPDP compliant. Delete your data anytime.',
      'icon': Icons.shield_rounded,
      'gradient': [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (ctx, i) {
              final p = _pages[i];
              final colors = p['gradient'] as List<Color>;
              return _OnboardingPage(
                title: p['title'] as String,
                desc: p['desc'] as String,
                icon: p['icon'] as IconData,
                gradientColors: colors,
              );
            },
          ),

          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _currentPage == i ? AppColors.primary : AppColors.textMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _finish,
                          child: Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: _currentPage == _pages.length - 1 ? double.infinity : 120,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Text(
                            _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final List<Color> gradientColors;

  const _OnboardingPage({
    required this.title,
    required this.desc,
    required this.icon,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 160),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, size: 96, color: Colors.white),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
