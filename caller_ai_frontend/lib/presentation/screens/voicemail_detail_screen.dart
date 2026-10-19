import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/voicemail.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/voicemail_bloc.dart';

export '../../core/models/voicemail.dart';

class VoicemailDetailScreen extends StatelessWidget {
  final Voicemail voicemail;

  const VoicemailDetailScreen({super.key, required this.voicemail});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatPosition(Duration pos) {
    final m = pos.inMinutes;
    final s = pos.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Delete Voicemail?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete the audio recording for ${voicemail.callerNumber} from telephony storage.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<VoicemailBloc>().add(VoicemailDeleteRequested(id: voicemail.id));
              Navigator.pop(context); // Return to inbox
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: const Text('Voicemail Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<VoicemailBloc, VoicemailState>(
        builder: (context, state) {
          final loaded = state is VoicemailLoaded ? state : null;
          final isPlayingThis = loaded?.currentlyPlaying?.id == voicemail.id;
          final isPlaying = isPlayingThis && (loaded?.isPlaying ?? false);
          final pos = isPlayingThis ? (loaded?.currentPosition ?? Duration.zero) : Duration.zero;
          final total = isPlayingThis && (loaded?.totalDuration ?? Duration.zero) > Duration.zero
              ? loaded!.totalDuration
              : Duration(seconds: voicemail.durationSeconds);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // Caller Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: const Icon(Icons.person_rounded, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  voicemail.callerNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Received ${voicemail.createdAt.toLocal().toString().split('.')[0]}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // Player Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      // Time Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatPosition(pos), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          Text(_formatDuration(total.inSeconds), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Scrub Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          value: pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                          max: total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0,
                          activeColor: AppColors.primary,
                          inactiveColor: Colors.white24,
                          onChanged: (val) {
                            if (isPlayingThis) {
                              context.read<VoicemailBloc>().add(
                                    VoicemailSeekRequested(position: Duration(milliseconds: val.toInt())),
                                  );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Controls (Rewind 5s, Play/Pause, Forward 5s)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.replay_5_rounded, color: Colors.white70),
                            onPressed: isPlayingThis
                                ? () {
                                    final newPos = pos - const Duration(seconds: 5);
                                    context.read<VoicemailBloc>().add(
                                          VoicemailSeekRequested(
                                            position: newPos < Duration.zero ? Duration.zero : newPos,
                                          ),
                                        );
                                  }
                                : null,
                          ),
                          const SizedBox(width: 24),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 44,
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (isPlayingThis) {
                                  if (isPlaying) {
                                    context.read<VoicemailBloc>().add(VoicemailPauseRequested());
                                  } else {
                                    context.read<VoicemailBloc>().add(VoicemailResumeRequested());
                                  }
                                } else {
                                  context.read<VoicemailBloc>().add(VoicemailPlayRequested(voicemail: voicemail));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.forward_5_rounded, color: Colors.white70),
                            onPressed: isPlayingThis
                                ? () {
                                    final newPos = pos + const Duration(seconds: 5);
                                    context.read<VoicemailBloc>().add(
                                          VoicemailSeekRequested(
                                            position: newPos > total ? total : newPos,
                                          ),
                                        );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Message Actions Card
                Material(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                      ListTile(
                        leading: Icon(
                          voicemail.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          voicemail.isRead ? 'Mark as Unread' : 'Mark as Read',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          context.read<VoicemailBloc>().add(
                                VoicemailMarkReadRequested(id: voicemail.id, isRead: !voicemail.isRead),
                              );
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined, color: AppColors.success),
                        title: const Text('Call Back', style: TextStyle(color: Colors.white)),
                        subtitle: Text(voicemail.callerNumber, style: const TextStyle(color: AppColors.textMuted)),
                        onTap: () {
                          // Standard phone callback
                        },
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          );
        },
      ),
    );
  }
}
