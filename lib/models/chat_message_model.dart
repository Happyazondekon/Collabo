import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, viewOnce }

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
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'text';
    final type = typeStr == 'image'
        ? MessageType.image
        : typeStr == 'viewOnce'
            ? MessageType.viewOnce
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
                : 'text',
        'viewedByPartner': viewedByPartner,
        if (reaction != null) 'reaction': reaction,
        if (type == MessageType.viewOnce) 'viewOnceDuration': viewOnceDuration,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
