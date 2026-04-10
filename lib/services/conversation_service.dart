import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

/// Result returned by [ConversationService.startConversationByEmail].
class ConvStartResult {
  final String conversationId;
  final String partnerUid;
  final String partnerName;
  final String? partnerAvatarUrl;

  const ConvStartResult({
    required this.conversationId,
    required this.partnerUid,
    required this.partnerName,
    this.partnerAvatarUrl,
  });
}

class ConversationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _myUid => _auth.currentUser?.uid;

  // ── Build deterministic conversation ID from two UIDs ──────────

  static String buildId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Ensure conversation document exists ────────────────────────

  static Future<String> ensureConversationWith(
      String partnerUid, String partnerName, String? partnerAvatarUrl) async {
    final myUid = _myUid;
    if (myUid == null) throw 'Non connecté';

    // Load my Firestore profile to get pseudo + avatarUrl
    final myDoc = await _db.collection('users').doc(myUid).get();
    final myData = myDoc.data();
    final myName = (myData?['pseudo'] as String?)?.isNotEmpty == true
        ? myData!['pseudo'] as String
        : (myData?['displayName'] as String?) ??
            _auth.currentUser?.displayName ??
            'Moi';
    final myAvatar = myData?['avatarUrl'] as String?;
    final myAvatarData = myData?['avatarData'] as String?;

    final convId = buildId(myUid, partnerUid);
    final ref = _db.collection('conversations').doc(convId);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'members': [myUid, partnerUid],
        'names': {
          myUid: myName,
          partnerUid: partnerName,
        },
        'avatars': {
          if (myAvatar != null && myAvatar.isNotEmpty) myUid: myAvatar,
          if (partnerAvatarUrl != null && partnerAvatarUrl.isNotEmpty)
            partnerUid: partnerAvatarUrl,
        },
        'avatarDatas': {
          if (myAvatarData != null && myAvatarData.isNotEmpty) myUid: myAvatarData,
        },
        'unreadCounts': {myUid: 0, partnerUid: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Update names/avatars in case pseudo or avatar changed
      final updates = <String, dynamic>{
        'names.$myUid': myName,
        'names.$partnerUid': partnerName,
        if (partnerAvatarUrl != null && partnerAvatarUrl.isNotEmpty)
          'avatars.$partnerUid': partnerAvatarUrl,
        if (myAvatar != null && myAvatar.isNotEmpty) 'avatars.$myUid': myAvatar,
        if (myAvatarData != null && myAvatarData.isNotEmpty)
          'avatarDatas.$myUid': myAvatarData,
      };
      await ref.update(updates);
    }
    return convId;
  }

  // ── Start a conversation by searching a user's email ──────────

  /// Searches for a user with [email], creates the conversation if needed,
  /// and returns the result. Throws a [String] message on error.
  static Future<ConvStartResult> startConversationByEmail(String email) async {
    final myUid = _myUid;
    if (myUid == null) throw 'Non connecté';

    final emailLower = email.trim().toLowerCase();
    final myEmail = _auth.currentUser?.email?.toLowerCase();
    if (emailLower == myEmail) {
      throw 'Vous ne pouvez pas vous écrire à vous-même.';
    }
    if (emailLower.isEmpty) throw 'Veuillez entrer un email.';

    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: emailLower)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw 'Aucun utilisateur trouvé avec cet email.';
    }

    final doc = snap.docs.first;
    final partnerUid = doc.id;
    final data = doc.data();
    final partnerName = (data['pseudo'] as String?)?.isNotEmpty == true
        ? data['pseudo'] as String
        : data['displayName'] as String? ?? 'Inconnu';
    final partnerAvatar = data['avatarUrl'] as String?;

    final convId = await ensureConversationWith(partnerUid, partnerName, partnerAvatar);

    return ConvStartResult(
      conversationId: convId,
      partnerUid: partnerUid,
      partnerName: partnerName,
      partnerAvatarUrl: partnerAvatar,
    );
  }

  // ── Stream of all the user's conversations ─────────────────────

  static Stream<List<ConversationModel>> myConversationsStream() {
    final uid = _myUid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('conversations')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ConversationModel.fromMap(d.id, d.data()))
          .toList();
      // Sort client-side: conversations with messages first, then newest
      list.sort((a, b) {
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });
      return list;
    });
  }

  // ── Total unread count across all conversations ─────────────────

  static Stream<int> totalUnreadStream() {
    final uid = _myUid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('conversations')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs.fold<int>(0, (acc, d) {
              final unread = (d.data()['unreadCounts'] as Map?) ?? {};
              return acc + ((unread[uid] ?? 0) as num).toInt();
            }));
  }

  // ── Messages stream ────────────────────────────────────────────

  static Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());
  }

  // ── Send text message ──────────────────────────────────────────

  static Future<void> sendText(
    String conversationId,
    String text, {
    String? replyToId,
    String? replyToText,
    String? replyToSenderUid,
  }) async {
    final uid = _myUid;
    if (uid == null || text.trim().isEmpty) return;
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(ChatMessage(
          id: '',
          senderUid: uid,
          text: text.trim(),
          type: MessageType.text,
          viewedByPartner: false,
          replyToId: replyToId,
          replyToText: replyToText,
          replyToSenderUid: replyToSenderUid,
          createdAt: DateTime.now(),
        ).toMap());
    await _touch(conversationId, text.trim());
  }

  // ── Send image (base64 in Firestore) ──────────────────────────

  static Future<void> sendImage(
      String conversationId, File imageFile, bool viewOnce,
      {int viewOnceDuration = 15,
      String? replyToId,
      String? replyToText,
      String? replyToSenderUid}) async {
    final uid = _myUid;
    if (uid == null) return;

    final bytes = await imageFile.readAsBytes();
    final imageData = base64Encode(bytes);

    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(ChatMessage(
          id: '',
          senderUid: uid,
          imageData: imageData,
          type: viewOnce ? MessageType.viewOnce : MessageType.image,
          viewedByPartner: false,
          viewOnceDuration: viewOnceDuration,
          replyToId: replyToId,
          replyToText: replyToText,
          replyToSenderUid: replyToSenderUid,
          createdAt: DateTime.now(),
        ).toMap());
    await _touch(
        conversationId, viewOnce ? '📸 Photo à voir une fois' : '📷 Photo');
  }

  // ── Reset my unread counter (call when opening a conversation) ─

  static Future<void> resetUnread(String conversationId) async {
    final uid = _myUid;
    if (uid == null) return;
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCounts.$uid': 0,
    });
  }

  // ── Mark view-once as viewed ───────────────────────────────────

  static Future<void> markViewOnceViewed(
      String conversationId, String messageId) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'viewedByPartner': true});
  }

  // ── React to a message ─────────────────────────────────────────

  static Future<void> react(
      String conversationId, String messageId, String? emoji) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'reaction': emoji});
  }

  // ── Delete a message ───────────────────────────────────────────

  static Future<void> deleteMessage(
      String conversationId, String messageId) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // ── Send call message (logged after the call ends) ────────────

  static Future<void> sendCallMessage(
    String conversationId, {
    required bool isVideo,
    required bool missed,
    int duration = 0,
  }) async {
    final uid = _myUid;
    if (uid == null) return;
    final preview = missed
        ? (isVideo ? '📹 Appel vidéo manqué' : '📞 Appel manqué')
        : (isVideo ? '📹 Appel vidéo' : '📞 Appel');
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(ChatMessage(
          id: '',
          senderUid: uid,
          type: MessageType.call,
          viewedByPartner: false,
          callIsVideo: isVideo,
          callMissed: missed,
          callDuration: duration,
          createdAt: DateTime.now(),
        ).toMap());
    await _touch(conversationId, preview);
  }

  // ── Update conversation metadata after sending ─────────────────

  static Future<void> _touch(String conversationId, String preview) async {
    final uid = _myUid;
    if (uid == null) return;

    // Read doc to find partner uid for the unread increment
    final snap = await _db.collection('conversations').doc(conversationId).get();
    if (!snap.exists) return;

    final members = (snap.data()!['members'] as List?)?.cast<String>() ?? [];
    final partnerUid = members.firstWhere((u) => u != uid, orElse: () => '');

    final update = <String, dynamic>{
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderUid': uid,
      'unreadCounts.$uid': 0,
    };
    if (partnerUid.isNotEmpty) {
      update['unreadCounts.$partnerUid'] = FieldValue.increment(1);
    }

    await _db.collection('conversations').doc(conversationId).update(update);
  }
}
