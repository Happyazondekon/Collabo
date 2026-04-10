import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, viewOnce, call }

class ChatMessage {
  final String id;
  final String senderUid;
  final String? text;
  /// Base64-encoded image data (stored directly in Firestore, no Storage needed)
  final String? imageData;
  final MessageType type;
  final bool viewedByPartner;
  final String? reaction;
  /// Duration in seconds the recipient can view a viewOnce photo (set by sender)
  final int viewOnceDuration;
  final DateTime createdAt;
  /// Reply context
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderUid;
  /// Call metadata (type == call)
  final bool callIsVideo;
  final bool callMissed;
  final int callDuration; // seconds

  ChatMessage({
    required this.id,
    required this.senderUid,
    this.text,
    this.imageData,
    required this.type,
    required this.viewedByPartner,
    this.reaction,
    this.viewOnceDuration = 15,
    required this.createdAt,
    this.replyToId,
    this.replyToText,
    this.replyToSenderUid,
    this.callIsVideo = false,
    this.callMissed = false,
    this.callDuration = 0,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'text';
    final type = typeStr == 'image'
        ? MessageType.image
        : typeStr == 'viewOnce'
            ? MessageType.viewOnce
            : typeStr == 'call'
                ? MessageType.call
                : MessageType.text;
    return ChatMessage(
      id: id,
      senderUid: map['senderUid'] as String? ?? '',
      text: map['text'] as String?,
      imageData: map['imageData'] as String?,
      type: type,
      viewedByPartner: map['viewedByPartner'] as bool? ?? false,
      reaction: map['reaction'] as String?,
      viewOnceDuration: map['viewOnceDuration'] as int? ?? 15,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToId: map['replyToId'] as String?,
      replyToText: map['replyToText'] as String?,
      replyToSenderUid: map['replyToSenderUid'] as String?,
      callIsVideo: map['callIsVideo'] as bool? ?? false,
      callMissed: map['callMissed'] as bool? ?? false,
      callDuration: map['callDuration'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        if (text != null) 'text': text,
        if (imageData != null) 'imageData': imageData,
        'type': type == MessageType.image
            ? 'image'
            : type == MessageType.viewOnce
                ? 'viewOnce'
                : type == MessageType.call
                    ? 'call'
                    : 'text',
        'viewedByPartner': viewedByPartner,
        if (reaction != null) 'reaction': reaction,
        if (type == MessageType.viewOnce) 'viewOnceDuration': viewOnceDuration,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToText != null) 'replyToText': replyToText,
        if (replyToSenderUid != null) 'replyToSenderUid': replyToSenderUid,
        if (type == MessageType.call) ...{
          'callIsVideo': callIsVideo,
          'callMissed': callMissed,
          'callDuration': callDuration,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };
}
