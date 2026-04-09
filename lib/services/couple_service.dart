import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Models ────────────────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String? displayName;
  final String? pseudo;
  final String? avatarUrl;
  final String? email;
  final String? partnerUid;
  final String? coupleId;
  final DateTime? anniversaryDate;
  final DateTime? birthday;

  UserProfile({
    required this.uid,
    this.displayName,
    this.pseudo,
    this.avatarUrl,
    this.email,
    this.partnerUid,
    this.coupleId,
    this.anniversaryDate,
    this.birthday,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String?,
      pseudo: map['pseudo'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      email: map['email'] as String?,
      partnerUid: map['partnerUid'] as String?,
      coupleId: map['coupleId'] as String?,
      anniversaryDate: (map['anniversaryDate'] as Timestamp?)?.toDate(),
      birthday: (map['birthday'] as Timestamp?)?.toDate(),
    );
  }
}

class StoryEntry {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  StoryEntry({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory StoryEntry.fromMap(String id, Map<String, dynamic> map) {
    return StoryEntry(
      id: id,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Joueur',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class CoupleRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final String fromEmail;
  final String toEmail;

  CoupleRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromEmail,
    required this.toEmail,
  });

  factory CoupleRequest.fromMap(String id, Map<String, dynamic> map) {
    return CoupleRequest(
      id: id,
      fromUid: map['fromUid'] as String? ?? '',
      fromName: map['fromName'] as String? ?? 'Joueur',
      fromEmail: map['fromEmail'] as String? ?? '',
      toEmail: map['toEmail'] as String? ?? '',
    );
  }
}

// ─── Service ───────────────────────────────────────────────────────

class CoupleService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _myUid => _auth.currentUser?.uid;
  static String get _myEmailLower =>
      (_auth.currentUser?.email ?? '').trim().toLowerCase();
  static String get _myName =>
      _auth.currentUser?.displayName ?? 'Joueur';

  static String _buildCoupleId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Profile ─────────────────────────────────────────────────────

  static Future<void> ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email?.trim().toLowerCase(),
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'email': user.email?.trim().toLowerCase(),
        if (user.displayName != null) 'displayName': user.displayName,
      });
    }
  }

  static Stream<UserProfile?> myProfileStream() {
    final uid = _myUid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(uid, snap.data()!);
    });
  }

  static Future<void> updateDates({
    DateTime? anniversaryDate,
    DateTime? birthday,
  }) async {
    final uid = _myUid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (anniversaryDate != null) {
      updates['anniversaryDate'] = Timestamp.fromDate(anniversaryDate);
    }
    if (birthday != null) {
      updates['birthday'] = Timestamp.fromDate(birthday);
    }
    if (updates.isEmpty) return;
    await _db.collection('users').doc(uid).update(updates);
  }

  static Future<void> updateProfile({
    String? pseudo,
    String? avatarUrl,
  }) async {
    final uid = _myUid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (pseudo != null) updates['pseudo'] = pseudo;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (updates.isEmpty) return;
    await _db.collection('users').doc(uid).update(updates);
  }

  static Future<UserProfile?> getPartnerProfile(String partnerUid) async {
    final snap = await _db.collection('users').doc(partnerUid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(partnerUid, snap.data()!);
  }

  // ── Partner Linking ─────────────────────────────────────────────

  static Future<void> sendInvite(String partnerEmail) async {
    final uid = _myUid;
    if (uid == null) throw 'Vous devez être connecté.';
    final email = partnerEmail.trim().toLowerCase();
    if (email == _myEmailLower) {
      throw 'Vous ne pouvez pas vous inviter vous-même.';
    }

    // Check not already coupled
    final mySnap = await _db.collection('users').doc(uid).get();
    if (mySnap.exists && mySnap.data()?['partnerUid'] != null) {
      throw 'Vous êtes déjà connecté avec un partenaire.';
    }

    // Check duplicate request
    final existing = await _db
        .collection('couple_requests')
        .where('fromUid', isEqualTo: uid)
        .where('toEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw 'Une invitation a déjà été envoyée à cet email.';
    }

    await _db.collection('couple_requests').add({
      'fromUid': uid,
      'fromName': _myName,
      'fromEmail': _myEmailLower,
      'toEmail': email,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<CoupleRequest>> pendingInvitesStream() {
    return _db
        .collection('couple_requests')
        .where('toEmail', isEqualTo: _myEmailLower)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CoupleRequest.fromMap(d.id, d.data()))
            .toList());
  }

  static Future<void> acceptInvite(CoupleRequest request) async {
    final uid = _myUid;
    if (uid == null) return;
    final coupleId = _buildCoupleId(uid, request.fromUid);
    final batch = _db.batch();

    batch.set(_db.collection('couples').doc(coupleId), {
      'members': [uid, request.fromUid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('users').doc(uid), {
      'partnerUid': request.fromUid,
      'coupleId': coupleId,
    });

    batch.update(_db.collection('users').doc(request.fromUid), {
      'partnerUid': uid,
      'coupleId': coupleId,
    });

    batch.update(
      _db.collection('couple_requests').doc(request.id),
      {'status': 'accepted'},
    );

    await batch.commit();
  }

  static Future<void> declineInvite(String requestId) async {
    await _db
        .collection('couple_requests')
        .doc(requestId)
        .update({'status': 'declined'});
  }

  static Future<void> unlinkPartner(
      String partnerUid, String coupleId) async {
    final uid = _myUid;
    if (uid == null) return;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {
      'partnerUid': FieldValue.delete(),
      'coupleId': FieldValue.delete(),
    });
    batch.update(_db.collection('users').doc(partnerUid), {
      'partnerUid': FieldValue.delete(),
      'coupleId': FieldValue.delete(),
    });
    await batch.commit();
  }

  // ── Stories ─────────────────────────────────────────────────────

  static Stream<List<StoryEntry>> storiesStream(String coupleId) {
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StoryEntry.fromMap(d.id, d.data())).toList());
  }

  static Future<void> addStory(String coupleId, String text) async {
    final uid = _myUid;
    if (uid == null) return;
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .add({
      'authorUid': uid,
      'authorName': _myName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteStory(String coupleId, String storyId) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .doc(storyId)
        .delete();
  }
}
