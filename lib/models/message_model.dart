enum MessageType {
  text,
  image,
  audio,
  video,
  emergency,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isEmergency;
  final String? replyToId;
  final Map<String, dynamic>? metadata;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    this.isEmergency = false,
    this.replyToId,
    this.metadata,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${map['status']}',
        orElse: () => MessageStatus.sent,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      isEmergency: map['isEmergency'] ?? false,
      replyToId: map['replyToId'],
      metadata: map['metadata'],
    );
  }

  /// Create a voice message
  factory MessageModel.voiceMessage({
    required String id,
    required String senderId,
    required String receiverId,
    required String voiceFilePath,
    required int voiceDuration,
    required DateTime timestamp,
    bool isEmergency = false,
    String? replyToId,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      content: 'Voice message',
      type: MessageType.audio,
      timestamp: timestamp,
      isEmergency: isEmergency,
      replyToId: replyToId,
      metadata: {
        'voiceFilePath': voiceFilePath,
        'voiceDuration': voiceDuration,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isEmergency': isEmergency,
      'replyToId': replyToId,
      'metadata': metadata,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    bool? isEmergency,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isEmergency: isEmergency ?? this.isEmergency,
      replyToId: replyToId ?? this.replyToId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Check if this is a voice message
  bool get isVoiceMessage => type == MessageType.audio;

  /// Get voice file path from metadata
  String? get voiceFilePath => metadata?['voiceFilePath'];

  /// Get voice duration from metadata
  int get voiceDuration => metadata?['voiceDuration'] ?? 0;

  /// Format voice duration as MM:SS
  String get formattedVoiceDuration {
    final minutes = voiceDuration ~/ 60;
    final seconds = voiceDuration % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, content: $content, type: $type, status: $status)';
  }
}
