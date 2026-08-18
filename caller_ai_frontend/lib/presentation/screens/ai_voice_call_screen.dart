import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AIVoiceCallScreen extends StatefulWidget {
  final String callerNumber;
  final String agentName;
  final String callType;

  const AIVoiceCallScreen({
    super.key,
    this.callerNumber = 'Unknown',
    this.agentName = 'Max',
    this.callType = 'spam',
  });

  @override
  State<AIVoiceCallScreen> createState() => _AIVoiceCallScreenState();
}

class _AIVoiceCallScreenState extends State<AIVoiceCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Timer _timer;
  int _seconds = 0;
  String _status = 'Listening...';
  final List<Map<String, String>> _transcript = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      // Simulate live transcript updates
      if (_seconds == 3) {
        setState(() {
          _status = 'Responding...';
          _transcript.add({'speaker': 'ai', 'text': 'Hello, this is ${widget.agentName} speaking. How can I help you today?'});
        });
      } else if (_seconds == 6) {
        setState(() {
          _status = 'Listening...';
          _transcript.add({'speaker': 'caller', 'text': 'Hi, I\'m calling about a loan offer...'});
        });
      } else if (_seconds == 9) {
        setState(() {
          _status = 'Responding...';
          _transcript.add({'speaker': 'ai', 'text': 'Could you tell me more about the interest rate and loan amount?'});
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isSpam = widget.callType == 'spam';
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.callerNumber, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_formattedTime, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSpam ? AppColors.spamHigh.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSpam ? 'SPAM' : 'BUSY',
                      style: TextStyle(
                        color: isSpam ? AppColors.spamHigh : AppColors.primary,
                        fontSize: 12, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // AI Agent avatar with pulse
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (ctx, child) => Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (i) => Transform.scale(
                    scale: 1.0 + (i * 0.2) * _pulseController.value,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.aiBlue.withOpacity(0.05 * (3 - i)),
                      ),
                    ),
                  )),
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.aiBlue.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.aiBlue, width: 2),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: AppColors.aiBlue, size: 52),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.agentName, style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 6),

            // Waveform status
            AnimatedBuilder(
              animation: _waveController,
              builder: (ctx, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _status == 'Listening...' ? Icons.mic_rounded : Icons.volume_up_rounded,
                    color: AppColors.aiBlue,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(_status, style: TextStyle(color: AppColors.aiBlue, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Live transcript
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _transcript.isEmpty
                    ? Center(child: Text('Starting call...', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        reverse: true,
                        itemCount: _transcript.length,
                        itemBuilder: (ctx, i) {
                          final msg = _transcript[_transcript.length - 1 - i];
                          final isAI = msg['speaker'] == 'ai';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAI ? 'AI ${widget.agentName}' : 'Caller',
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
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Action bar
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.person_rounded, size: 18),
                      label: const Text('Take Over'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.call_end, size: 18),
                      label: const Text('End AI Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
