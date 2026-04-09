import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _myUid => _auth.currentUser?.uid;

  // ── Stream messages ────────────────────────────────────────────

  static Stream<List<ChatMessage>> messagesStream(String coupleId) {
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());
  }

  // ── Unread message count (for badge) ─────────────────────────

  static Stream<int> unreadCountStream(String coupleId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .where('viewedByPartner', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) =>
                d.data()['senderUid'] != uid &&
                d.data()['type'] != 'viewOnce')
            .length);
  }

  // ── Send text ──────────────────────────────────────────────────

  static Future<void> sendText(String coupleId, String text) async {
    final uid = _myUid;
    if (uid == null || text.trim().isEmpty) return;
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .add(ChatMessage(
          id: '',
          senderUid: uid,
          text: text.trim(),
          type: MessageType.text,
          viewedByPartner: false,
          createdAt: DateTime.now(),
        ).toMap());
    await _touchConversation(coupleId, text.trim(), false);
  }

  // ── Send image (base64 stored in Firestore, no Storage needed) ────

  static Future<void> sendImage(
      String coupleId, File imageFile, bool viewOnce,
      {int viewOnceDuration = 15}) async {
    final uid = _myUid;
    if (uid == null) return;

    // image_picker already compresses (imageQuality:75, maxWidth:1080)
    // Just read the bytes and encode to base64
    final bytes = await imageFile.readAsBytes();
    final imageData = base64Encode(bytes);

    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .add(ChatMessage(
          id: '',
          senderUid: uid,
          imageData: imageData,
          type: viewOnce ? MessageType.viewOnce : MessageType.image,
          viewedByPartner: false,
          viewOnceDuration: viewOnceDuration,
          createdAt: DateTime.now(),
        ).toMap());
    await _touchConversation(
        coupleId, viewOnce ? '📸 Photo à voir une fois' : '📷 Photo', false);
  }

  // ── Mark view-once as viewed ───────────────────────────────────

  static Future<void> markViewOnceViewed(
      String coupleId, String messageId) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .doc(messageId)
        .update({'viewedByPartner': true});
  }

  // ── Mark messages as seen ──────────────────────────────────────

  static Future<void> markSeen(String coupleId, List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in messageIds) {
      batch.update(
        _db.collection('couples').doc(coupleId).collection('messages').doc(id),
        {'viewedByPartner': true},
      );
    }
    await batch.commit();
  }

  // ── React to a message ─────────────────────────────────────────

  static Future<void> react(
      String coupleId, String messageId, String? emoji) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .doc(messageId)
        .update({'reaction': emoji});
  }

  // ── Delete message ─────────────────────────────────────────────

  static Future<void> deleteMessage(
      String coupleId, String messageId) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // ── Touch conversation metadata ────────────────────────────────

  static Future<void> _touchConversation(
      String coupleId, String preview, bool viewOnce) async {
    await _db.collection('couples').doc(coupleId).set({
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderUid': _myUid,
    }, SetOptions(merge: true));
  }
}
