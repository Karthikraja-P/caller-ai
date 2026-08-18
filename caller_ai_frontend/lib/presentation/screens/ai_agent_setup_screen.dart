import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';

class AIAgentSetupScreen extends StatefulWidget {
  const AIAgentSetupScreen({super.key});

  @override
  State<AIAgentSetupScreen> createState() => _AIAgentSetupScreenState();
}

class _AIAgentSetupScreenState extends State<AIAgentSetupScreen> {
  final _nameController = TextEditingController(text: '');
  String _selectedVoiceId = 'en-US-Neural2-A';
  String _selectedPersonality = 'friendly';
  bool _isLoading = false;
  bool _isPlayingVoice = false;
  final _audioPlayer = AudioPlayer();

  final List<Map<String, String>> _voices = [
    {'id': 'en-US-Neural2-A', 'name': 'Rachel', 'desc': 'Female, Warm', 'gender': 'female'},
    {'id': 'en-US-Neural2-D', 'name': 'James', 'desc': 'Male, Professional', 'gender': 'male'},
    {'id': 'en-US-Neural2-F', 'name': 'Aria', 'desc': 'Female, Friendly', 'gender': 'female'},
    {'id': 'en-US-Neural2-J', 'name': 'David', 'desc': 'Male, Calm', 'gender': 'male'},
    {'id': 'en-US-Neural2-H', 'name': 'Sofia', 'desc': 'Female, Energetic', 'gender': 'female'},
    {'id': 'en-US-Neural2-I', 'name': 'Ethan', 'desc': 'Male, Warm', 'gender': 'male'},
  ];

  final List<Map<String, dynamic>> _personalities = [
    {'id': 'professional', 'label': 'Professional', 'icon': Icons.business_center_rounded},
    {'id': 'friendly', 'label': 'Friendly', 'icon': Icons.sentiment_satisfied_rounded},
    {'id': 'concise', 'label': 'Concise', 'icon': Icons.flash_on_rounded},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _previewVoice(String voiceId) async {
    if (_isPlayingVoice) return;
    setState(() => _isPlayingVoice = true);
    try {
      final agentName = _nameController.text.isNotEmpty ? _nameController.text : 'your assistant';
      final resp = await apiClient.post('/ai/call/speak-text', data: {
        'text': "Hi, I'm $agentName. How can I help you today?",
        'voice_id': voiceId,
      });
      final audioUrl = resp.data['audio_url'] as String;
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (_) {
    } finally {
      setState(() => _isPlayingVoice = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_nameController.text.length < 2) return;
    setState(() => _isLoading = true);
    try {
      final agentName = _nameController.text.trim();
      await apiClient.post('/ai/agent/config', data: {
        'agent_name': agentName,
        'voice_id': _selectedVoiceId,
        'personality': _selectedPersonality,
        'language': 'en-US',
        'spam_handling_enabled': true,
        'busy_mode_enabled': false,
        'greeting_template': "Hello, I'm $agentName. How can I help you today?",
      });
      if (mounted) Navigator.pushReplacementNamed(context, '/permissions');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
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
            // Progress bar
            Container(
              height: 4,
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i < 2 ? AppColors.primary : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text('Name Your AI Assistant', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Your AI will answer calls on your behalf',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),

                    // Agent name input
                    TextField(
                      controller: _nameController,
                      maxLength: 20,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g., Alexa, Max, Sara',
                        counterStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),

                    // Live preview bubble
                    if (_nameController.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.aiBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.aiBlue.withOpacity(0.3)),
                          ),
                          child: Text(
                            "Hi, I'm ${_nameController.text}!",
                            style: const TextStyle(
                              color: AppColors.aiBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Text('Choose a Voice', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),

                    // Voice carousel
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _voices.length,
                        itemBuilder: (ctx, i) {
                          final v = _voices[i];
                          final selected = _selectedVoiceId == v['id'];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedVoiceId = v['id']!),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 150,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? AppColors.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(v['name']!, style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w600,
                                        )),
                                        Text(v['desc']!, style: TextStyle(
                                          color: AppColors.textSecondary, fontSize: 11,
                                        )),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _previewVoice(v['id']!),
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isPlayingVoice && _selectedVoiceId == v['id']
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text('Personality', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),

                    // Personality cards
                    Row(
                      children: _personalities.map((p) {
                        final selected = _selectedPersonality == p['id'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPersonality = p['id']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(p['icon'] as IconData, color: Colors.white, size: 24),
                                  const SizedBox(height: 6),
                                  Text(
                                    p['label'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_nameController.text.length >= 2 && !_isLoading)
                            ? _saveAndContinue
                            : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save & Continue'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/permissions'),
                        child: Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
