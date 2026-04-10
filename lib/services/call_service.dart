import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight model returned by [CallService.incomingCallStream].
class IncomingCallData {
  final String callId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final String? conversationId;

  const IncomingCallData({
    required this.callId,
    required this.callerName,
    this.callerAvatar,
    required this.isVideo,
    this.conversationId,
  });
}

/// Handles all Firestore signalling for WebRTC peer-to-peer calls.
///
/// Firestore structure:
///   calls/{callId}
///     callerId, receiverId, callerName, callerAvatar,
///     status: 'ringing' | 'ongoing' | 'ended' | 'declined'
///     type:   'audio' | 'video'
///     offer:  {sdp, type}
///     answer: {sdp, type}
///     createdAt
///   calls/{callId}/callerCandidates/{id}   → ICE candidates from caller
///   calls/{callId}/receiverCandidates/{id} → ICE candidates from receiver
class CallService {
  static final _db = FirebaseFirestore.instance;
  static String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  // ── Create ────────────────────────────────────────────────────────────────

  /// Creates a [calls] document and returns its ID.
  static Future<String> createCall({
    required String receiverId,
    required String callerName,
    String? callerAvatar,
    required bool isVideo,
    String? conversationId,
  }) async {
    final uid = _myUid;
    if (uid == null) throw Exception('Not authenticated');
    final ref = await _db.collection('calls').add({
      'callerId': uid,
      'receiverId': receiverId,
      'callerName': callerName,
      if (callerAvatar != null) 'callerAvatar': callerAvatar,
      if (conversationId != null) 'conversationId': conversationId,
      'status': 'ringing',
      'type': isVideo ? 'video' : 'audio',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ── Incoming calls ────────────────────────────────────────────────────────

  /// Emits the latest ringing call aimed at the current user, or [null] when
  /// there is none. Each new emission with a non-null value means a new call.
  static Stream<IncomingCallData?> incomingCallStream() {
    final uid = _myUid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final data = doc.data();
      return IncomingCallData(
        callId: doc.id,
        callerName: data['callerName'] as String? ?? 'Appel entrant',
        callerAvatar: data['callerAvatar'] as String?,
        isVideo: data['type'] == 'video',
        conversationId: data['conversationId'] as String?,
      );
    });
  }

  // ── Call document ─────────────────────────────────────────────────────────

  /// Real-time updates for a single call document.
  static Stream<DocumentSnapshot> callStream(String callId) =>
      _db.collection('calls').doc(callId).snapshots();

  static Future<void> setStatus(String callId, String status) =>
      _db.collection('calls').doc(callId).update({'status': status});

  static Future<void> setOffer(
          String callId, Map<String, dynamic> offer) =>
      _db.collection('calls').doc(callId).update({'offer': offer});

  static Future<void> setAnswer(
          String callId, Map<String, dynamic> answer) =>
      _db.collection('calls').doc(callId).update({'answer': answer});

  // ── ICE candidates ────────────────────────────────────────────────────────

  static Future<void> addCandidate(
      String callId, bool isCaller, Map<String, dynamic> candidate) =>
      _db
          .collection('calls')
          .doc(callId)
          .collection(
              isCaller ? 'callerCandidates' : 'receiverCandidates')
          .add(candidate);

  /// Returns the stream of the **remote** peer's candidates.
  /// [listenToCaller] = true  → current user is the receiver
  /// [listenToCaller] = false → current user is the caller
  static Stream<QuerySnapshot> remoteCandidatesStream(
          String callId, {required bool listenToCaller}) =>
      _db
          .collection('calls')
          .doc(callId)
          .collection(
              listenToCaller ? 'callerCandidates' : 'receiverCandidates')
          .snapshots();
}
