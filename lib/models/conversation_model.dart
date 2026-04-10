import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> members;
  final Map<String, String> names;   // uid → displayName
  final Map<String, String> avatars; // uid → avatarUrl
  final Map<String, String> avatarDatas; // uid → base64 custom photo
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts; // uid → unread count

  const ConversationModel({
    required this.id,
    required this.members,
    required this.names,
    required this.avatars,
    this.avatarDatas = const {},
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCounts,
  });

  String partnerUid(String myUid) =>
      members.firstWhere((u) => u != myUid, orElse: () => '');

  String partnerName(String myUid) =>
      names[partnerUid(myUid)] ?? 'Inconnu';

  String? partnerAvatar(String myUid) {
    final uid = partnerUid(myUid);
    return uid.isEmpty ? null : avatars[uid];
  }

  String? partnerAvatarData(String myUid) {
    final uid = partnerUid(myUid);
    return uid.isEmpty ? null : avatarDatas[uid];
  }

  int myUnread(String myUid) => unreadCounts[myUid] ?? 0;

  factory ConversationModel.fromMap(String id, Map<String, dynamic> map) {
    final membersRaw = (map['members'] as List?)?.cast<String>() ?? [];
    final namesRaw =
        (map['names'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    final avatarsRaw =
        (map['avatars'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    final avatarDatasRaw =
        (map['avatarDatas'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {};
    final unreadRaw = (map['unreadCounts'] as Map?) ?? {};

    return ConversationModel(
      id: id,
      members: membersRaw,
      names: namesRaw,
      avatars: avatarsRaw,
      avatarDatas: avatarDatasRaw,
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: {
        for (final e in unreadRaw.entries) e.key.toString(): (e.value as num).toInt()
      },
    );
  }
}
