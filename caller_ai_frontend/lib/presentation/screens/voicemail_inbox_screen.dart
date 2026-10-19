import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/voicemail.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/voicemail_bloc.dart';

class VoicemailInboxScreen extends StatefulWidget {
  const VoicemailInboxScreen({super.key});

  @override
  State<VoicemailInboxScreen> createState() => _VoicemailInboxScreenState();
}

class _VoicemailInboxScreenState extends State<VoicemailInboxScreen> {
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    context.read<VoicemailBloc>().add(VoicemailFetchRequested(unreadOnly: _unreadOnly));
  }

  void _toggleFilter(bool unreadOnly) {
    if (_unreadOnly == unreadOnly) return;
    setState(() => _unreadOnly = unreadOnly);
    context.read<VoicemailBloc>().add(VoicemailFetchRequested(unreadOnly: unreadOnly));
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day}/${dt.year}';
    }
  }

  void _showDeleteDialog(BuildContext context, Voicemail vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Delete Voicemail?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete the recording from telephony storage and remove the message for ${vm.callerNumber}.',
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
              context.read<VoicemailBloc>().add(VoicemailDeleteRequested(id: vm.id));
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
        title: const Text('Voicemail', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<VoicemailBloc>().add(VoicemailFetchRequested(unreadOnly: _unreadOnly)),
          ),
        ],
      ),
      body: BlocConsumer<VoicemailBloc, VoicemailState>(
        listener: (context, state) {
          if (state is VoicemailLoaded && state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(state.operationError!),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Messages'),
            selected: !_unreadOnly,
            onSelected: (_) => _toggleFilter(false),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            labelStyle: TextStyle(color: !_unreadOnly ? Colors.white : Colors.white70),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Unread Only'),
            selected: _unreadOnly,
            onSelected: (_) => _toggleFilter(true),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            labelStyle: TextStyle(color: _unreadOnly ? Colors.white : Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, VoicemailState state) {
    if (state is VoicemailLoading || state is VoicemailInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is VoicemailError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(state.message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => context.read<VoicemailBloc>().add(VoicemailFetchRequested(unreadOnly: _unreadOnly)),
              ),
            ],
          ),
        ),
      );
    }

    if (state is VoicemailLoaded) {
      if (state.messages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.voicemail_rounded, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                _unreadOnly ? 'No unread voicemails' : 'No voicemails yet',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'When callers leave a recorded message, it will appear here.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        itemCount: state.messages.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (ctx, i) {
          final vm = state.messages[i];
          final isPlayingThis = state.currentlyPlaying?.id == vm.id;
          final isDeletingThis = state.deletingId == vm.id;
          return _buildVoicemailTile(context, vm, isPlayingThis, state, isDeletingThis);
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVoicemailTile(
    BuildContext context,
    Voicemail vm,
    bool isPlayingThis,
    VoicemailLoaded state,
    bool isDeletingThis,
  ) {
    return Material(
      color: !vm.isRead ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/voicemail-detail', arguments: {'voicemail': vm});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Unread dot
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: !vm.isRead ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
                // Play / Pause circular button
                IconButton(
                  icon: Icon(
                    isPlayingThis && state.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                  onPressed: isDeletingThis
                      ? null
                      : () {
                          if (isPlayingThis) {
                            if (state.isPlaying) {
                              context.read<VoicemailBloc>().add(VoicemailPauseRequested());
                            } else {
                              context.read<VoicemailBloc>().add(VoicemailResumeRequested());
                            }
                          } else {
                            context.read<VoicemailBloc>().add(VoicemailPlayRequested(voicemail: vm));
                          }
                        },
                ),
                const SizedBox(width: 8),
                // Caller details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.callerNumber,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: !vm.isRead ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatDuration(vm.durationSeconds),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                          Text(
                            _formatTime(vm.createdAt),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                if (isDeletingThis)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
                    onPressed: () => _showDeleteDialog(context, vm),
                  ),
              ],
            ),
            // Progress bar if playing
            if (isPlayingThis) ...[
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: state.currentPosition.inMilliseconds
                      .clamp(0, state.totalDuration.inMilliseconds)
                      .toDouble(),
                  max: state.totalDuration.inMilliseconds > 0
                      ? state.totalDuration.inMilliseconds.toDouble()
                      : 1.0,
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    context.read<VoicemailBloc>().add(
                          VoicemailSeekRequested(position: Duration(milliseconds: val.toInt())),
                        );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}
