import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class CallOverlayScreen extends StatelessWidget {
  final String callerNumber;
  final String callerName;
  final int spamScore;
  final bool aiHandling;

  const CallOverlayScreen({
    super.key,
    required this.callerNumber,
    required this.callerName,
    this.spamScore = 0,
    this.aiHandling = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSpam = spamScore > 70;
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.92),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Spam banner
            if (isSpam)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: AppColors.spamHigh,
                child: const Text(
                  '⚠️  SPAM ALERT  ⚠️',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
              ),

            const Spacer(),

            // Caller info
            CircleAvatar(
              radius: 50,
              backgroundColor: isSpam
                  ? AppColors.spamHigh.withOpacity(0.2)
                  : AppColors.primary.withOpacity(0.2),
              child: Text(
                callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isSpam ? AppColors.spamHigh : AppColors.primary,
                  fontSize: 40, fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(callerName, style: const TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 4),
            Text(callerNumber, style: TextStyle(color: Colors.white70, fontSize: 16)),
            if (isSpam) ...[
              const SizedBox(height: 8),
              Text(
                'Spam Score: $spamScore/100',
                style: const TextStyle(color: AppColors.spamHigh, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 32),

            // AI status
            if (aiHandling)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.aiBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.aiBlue.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smart_toy_rounded, color: AppColors.aiBlue),
                    SizedBox(width: 10),
                    Text(
                      'Max is handling this call',
                      style: TextStyle(color: AppColors.aiBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    icon: Icons.call, color: AppColors.success, label: 'Answer',
                    onTap: () => Navigator.pop(context),
                  ),
                  _actionButton(
                    icon: Icons.smart_toy_rounded, color: AppColors.aiBlue, label: 'AI Handle',
                    onTap: () => Navigator.pushReplacementNamed(context, '/ai-voice-call'),
                  ),
                  _actionButton(
                    icon: Icons.chat_rounded, color: AppColors.whatsapp, label: 'WhatsApp',
                    onTap: () {
                      apiClient.post('/whatsapp/send-message', data: {
                        'to_number': callerNumber,
                        'message': "Hi, I'm currently unavailable. Please message me on WhatsApp.",
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _actionButton(
                    icon: Icons.block_rounded, color: AppColors.error, label: 'Block',
                    onTap: () {
                      apiClient.post('/blocklist', data: {'phone_number': callerNumber});
                      Navigator.pop(context);
                    },
                  ),
                  _actionButton(
                    icon: Icons.arrow_downward_rounded, color: Colors.grey, label: 'Dismiss',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
