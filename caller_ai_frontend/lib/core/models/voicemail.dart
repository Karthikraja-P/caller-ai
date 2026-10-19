class Voicemail {
  final String id;
  final String callerNumber;
  final String destinationNumber;
  final int durationSeconds;
  final String status;
  final String? transcription;
  final bool isRead;
  final DateTime createdAt;

  const Voicemail({
    required this.id,
    required this.callerNumber,
    required this.destinationNumber,
    required this.durationSeconds,
    required this.status,
    this.transcription,
    required this.isRead,
    required this.createdAt,
  });

  factory Voicemail.fromJson(Map<String, dynamic> json) {
    return Voicemail(
      id: json['id'] as String? ?? '',
      callerNumber: json['caller_number'] as String? ?? 'Unknown',
      destinationNumber: json['destination_number'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'completed',
      transcription: json['transcription'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caller_number': callerNumber,
    'destination_number': destinationNumber,
    'duration_seconds': durationSeconds,
    'status': status,
    'transcription': transcription,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };

  Voicemail copyWith({
    String? id,
    String? callerNumber,
    String? destinationNumber,
    int? durationSeconds,
    String? status,
    String? transcription,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Voicemail(
      id: id ?? this.id,
      callerNumber: callerNumber ?? this.callerNumber,
      destinationNumber: destinationNumber ?? this.destinationNumber,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      transcription: transcription ?? this.transcription,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
