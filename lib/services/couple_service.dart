import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'conversation_service.dart';

// ─── Models ────────────────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String? displayName;
  final String? pseudo;
  final String? avatarUrl;
  final String? avatarData; // base64 custom profile photo (takes priority over avatarUrl)
  final String? email;
  final String? partnerUid;
  final String? coupleId;
  final DateTime? anniversaryDate;
  final DateTime? birthday;
  final List<String> friendUids; // max 2 extra contacts

  UserProfile({
    required this.uid,
    this.displayName,
    this.pseudo,
    this.avatarUrl,
    this.avatarData,
    this.email,
    this.partnerUid,
    this.coupleId,
    this.anniversaryDate,
    this.birthday,
    this.friendUids = const [],
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String?,
      pseudo: map['pseudo'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      avatarData: map['avatarData'] as String?,
      email: map['email'] as String?,
      partnerUid: map['partnerUid'] as String?,
      coupleId: map['coupleId'] as String?,
      anniversaryDate: (map['anniversaryDate'] as Timestamp?)?.toDate(),
      birthday: (map['birthday'] as Timestamp?)?.toDate(),
      friendUids: (map['friendUids'] as List?)?.cast<String>() ?? [],
    );
  }
}

class StoryEntry {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarData;
  final String text;
  final DateTime createdAt;
  final Map<String, List<String>> reactions; // emoji → list of uids

  StoryEntry({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarData,
    required this.text,
    required this.createdAt,
    this.reactions = const {},
  });

  factory StoryEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawReactions = map['reactions'];
    final reactions = <String, List<String>>{};
    if (rawReactions is Map) {
      for (final e in rawReactions.entries) {
        reactions[e.key as String] =
            List<String>.from(e.value as List? ?? []);
      }
    }
    return StoryEntry(
      id: id,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Joueur',
      authorAvatarUrl: map['authorAvatarUrl'] as String?,
      authorAvatarData: map['authorAvatarData'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactions: reactions,
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
        if (authorAvatarData != null) 'authorAvatarData': authorAvatarData,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class StoryComment {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatarUrl;
  final String? authorAvatarData;
  final String text;
  final DateTime createdAt;

  StoryComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorAvatarUrl,
    this.authorAvatarData,
    required this.text,
    required this.createdAt,
  });

  factory StoryComment.fromMap(String id, Map<String, dynamic> map) =>
      StoryComment(
        id: id,
        authorUid: map['authorUid'] as String? ?? '',
        authorName: map['authorName'] as String? ?? 'Joueur',
        authorAvatarUrl: map['authorAvatarUrl'] as String?,
        authorAvatarData: map['authorAvatarData'] as String?,
        text: map['text'] as String? ?? '',
        createdAt:
            (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
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
    String? avatarData, // non-empty = save custom photo; null = no change
  }) async {
    final uid = _myUid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (pseudo != null) updates['pseudo'] = pseudo;
    if (avatarData != null && avatarData.isNotEmpty) {
      // Custom photo takes priority — clear URL-based avatar
      updates['avatarData'] = avatarData;
      updates['avatarUrl'] = FieldValue.delete();
    } else if (avatarUrl != null) {
      // Preset URL avatar — clear any custom photo
      updates['avatarUrl'] = avatarUrl;
      updates['avatarData'] = FieldValue.delete();
    }
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

  // ── Friends (up to 2 extra contacts) ────────────────────────────

  static const int maxFriends = 2;

  /// Adds a friend by email. Throws a user-facing [Exception] on failure.
  static Future<void> addFriend(String email) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Non connecté');

    // Find user by email
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) throw Exception('Aucun utilisateur trouvé avec cet e-mail.');

    final friendUid = q.docs.first.id;
    if (friendUid == myUid) throw Exception('Vous ne pouvez pas vous ajouter vous-même.');

    final myDoc = await _db.collection('users').doc(myUid).get();
    final current =
        List<String>.from((myDoc.data()?['friendUids'] as List?) ?? []);

    if (current.contains(friendUid)) throw Exception('Ce contact est déjà ajouté.');
    if (current.length >= maxFriends) {
      throw Exception('Vous avez déjà $maxFriends contacts (maximum atteint).');
    }

    await _db.collection('users').doc(myUid).update({
      'friendUids': FieldValue.arrayUnion([friendUid]),
    });

    // Pre-create the conversation so the chat tab shows it immediately
    final friendData = q.docs.first.data();
    final friendName = (friendData['displayName'] as String?) ??
        (friendData['pseudo'] as String?) ??
        'Contact';
    final friendAvatar = friendData['avatarUrl'] as String?;
    await ConversationService.ensureConversationWith(
        friendUid, friendName, friendAvatar);
  }

  /// Removes a friend by uid.
  static Future<void> removeFriend(String friendUid) async {
    final myUid = _myUid;
    if (myUid == null) return;
    await _db.collection('users').doc(myUid).update({
      'friendUids': FieldValue.arrayRemove([friendUid]),
    });
  }

  /// Fetches all friend profiles for the given [friendUids].
  static Future<List<UserProfile>> getFriendProfiles(
      List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    final results = <UserProfile>[];
    for (final uid in friendUids) {
      final snap = await _db.collection('users').doc(uid).get();
      if (snap.exists) results.add(UserProfile.fromMap(snap.id, snap.data()!));
    }
    return results;
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
    // Read Firestore profile to get current pseudo + avatarUrl
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final name = (data?['pseudo'] as String?)?.isNotEmpty == true
        ? data!['pseudo'] as String
        : (data?['displayName'] as String?) ?? _myName;
    final avatarUrl = data?['avatarUrl'] as String?;
    final avatarData = data?['avatarData'] as String?;
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .add({
      'authorUid': uid,
      'authorName': name,
      if (avatarUrl != null && avatarUrl.isNotEmpty)
        'authorAvatarUrl': avatarUrl,
      if (avatarData != null && avatarData.isNotEmpty)
        'authorAvatarData': avatarData,
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

  // ── Story reactions & comments ────────────────────────────────

  static Future<void> toggleReaction(
      String coupleId, String storyId, String emoji) async {
    final uid = _myUid;
    if (uid == null) return;
    final ref = _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .doc(storyId);
    final snap = await ref.get();
    final reactions =
        (snap.data()?['reactions'] as Map<dynamic, dynamic>?) ?? {};
    final uids = List<String>.from(reactions[emoji] as List? ?? []);
    if (uids.contains(uid)) {
      await ref.update({'reactions.$emoji': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'reactions.$emoji': FieldValue.arrayUnion([uid])});
    }
  }

  static Future<void> addComment(
      String coupleId, String storyId, String text) async {
    final uid = _myUid;
    if (uid == null) return;
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final name = (data?['pseudo'] as String?)?.isNotEmpty == true
        ? data!['pseudo'] as String
        : (data?['displayName'] as String?) ?? _myName;
    final avatarUrl = data?['avatarUrl'] as String?;
    final avatarData = data?['avatarData'] as String?;
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .doc(storyId)
        .collection('comments')
        .add({
      'authorUid': uid,
      'authorName': name,
      if (avatarUrl != null && avatarUrl.isNotEmpty)
        'authorAvatarUrl': avatarUrl,
      if (avatarData != null && avatarData.isNotEmpty)
        'authorAvatarData': avatarData,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<StoryComment>> commentsStream(
      String coupleId, String storyId) {
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('stories')
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StoryComment.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Crossword game ───────────────────────────────────────────────

  static Stream<CrosswordSession?> crosswordStream(String coupleId) {
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('crossword')
        .snapshots()
        .map((s) => s.exists ? CrosswordSession.fromMap(s.data()!) : null);
  }

  static Future<void> startCrossword({
    required String coupleId,
    required String myUid,
    required String partnerUid,
  }) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('crossword')
        .set({
      'word': '',
      'clue': '',
      'guessedLetters': [],
      'definisseurUid': myUid,
      'devineurUid': partnerUid,
      'status': 'setup',
      'maxAttempts': 6,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> submitCrosswordWord({
    required String coupleId,
    required String word,
    required String clue,
  }) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('crossword')
        .update({
      'word': word.trim().toUpperCase(),
      'clue': clue.trim(),
      'guessedLetters': [],
      'status': 'playing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> guessCrosswordLetter(
      String coupleId, String letter) async {
    final ref = _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('crossword');
    final snap = await ref.get();
    if (!snap.exists) return;
    final session = CrosswordSession.fromMap(snap.data()!);
    final upper = letter.toUpperCase();
    if (session.guessedLetters.contains(upper)) return;
    final newGuesses = [...session.guessedLetters, upper];
    final wrongCount =
        newGuesses.where((l) => !session.word.contains(l)).length;
    final isWon = session.word
        .split('')
        .every((c) => c == ' ' || newGuesses.contains(c));
    final isLost = wrongCount >= session.maxAttempts;
    final status = isWon ? 'won' : (isLost ? 'lost' : 'playing');
    await ref.update({
      'guessedLetters': newGuesses,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> resetCrossword(String coupleId) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('crossword')
        .delete();
  }

  static Future<void> swapCrosswordRoles({
    required String coupleId,
    required String newDefinisseurUid,
    required String newDevineurUid,
  }) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('crossword')
        .set({
      'word': '',
      'clue': '',
      'guessedLetters': [],
      'definisseurUid': newDefinisseurUid,
      'devineurUid': newDevineurUid,
      'status': 'setup',
      'maxAttempts': 6,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Profile (Future) ─────────────────────────────────────────────

  static Future<UserProfile?> getMyProfile() async {
    final uid = _myUid;
    if (uid == null) return null;
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(uid, snap.data()!);
  }

  // ── Shared Words (synced between partners via couple document) ───

  static Future<void> saveSharedWords(
      String coupleId, List<String> words) async {
    await _db.collection('couples').doc(coupleId).set({
      'sharedWords': words,
      'sharedWordsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<String>> getSharedWords(String coupleId) async {
    final doc = await _db.collection('couples').doc(coupleId).get();
    final raw = doc.data()?['sharedWords'];
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }
}

// ─── Crossword session model ───────────────────────────────────────

class CrosswordSession {
  final String word;
  final String clue;
  final List<String> guessedLetters;
  final String definisseurUid;
  final String devineurUid;
  final String status; // setup | playing | won | lost
  final int maxAttempts;

  CrosswordSession({
    required this.word,
    required this.clue,
    required this.guessedLetters,
    required this.definisseurUid,
    required this.devineurUid,
    required this.status,
    required this.maxAttempts,
  });

  factory CrosswordSession.fromMap(Map<String, dynamic> map) {
    return CrosswordSession(
      word: (map['word'] as String? ?? '').toUpperCase(),
      clue: map['clue'] as String? ?? '',
      guessedLetters:
          (map['guessedLetters'] as List?)?.cast<String>() ?? [],
      definisseurUid: map['definisseurUid'] as String? ?? '',
      devineurUid: map['devineurUid'] as String? ?? '',
      status: map['status'] as String? ?? 'setup',
      maxAttempts: map['maxAttempts'] as int? ?? 6,
    );
  }

  List<String> get wrongGuesses =>
      guessedLetters.where((l) => !word.contains(l)).toList();

  String get displayWord => word
      .split('')
      .map((c) => c == ' ' ? '  ' : (guessedLetters.contains(c) ? c : '_'))
      .join(' ');
}

// ─────────────────────────────────────────────────────────────────
// Remote game service methods (competitive, cooperative, timed)
// ─────────────────────────────────────────────────────────────────

class RemoteGamesService {
  // ── Remote Competitive ─────────────────────────────────────────

  static Stream<RemoteCompetitiveSession?> remoteCompetitiveStream(
      String coupleId) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('competitive')
        .snapshots()
        .map((s) =>
            s.exists ? RemoteCompetitiveSession.fromMap(s.data()!) : null);
  }

  static Future<void> createRemoteCompetitive({
    required String coupleId,
    required String myUid,
    int targetScore = 10,
  }) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('competitive')
        .set({
      'player1Uid': myUid,
      'player2Uid': null,
      'player1Score': 0,
      'player2Score': 0,
      'status': 'waiting',
      'targetScore': targetScore,
      'winner': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> joinRemoteCompetitive({
    required String coupleId,
    required String myUid,
  }) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('competitive')
        .update({
      'player2Uid': myUid,
      'status': 'playing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateCompetitiveScore({
    required String coupleId,
    required String myUid,
    required RemoteCompetitiveSession session,
    required int newScore,
  }) async {
    final isP1 = session.player1Uid == myUid;
    final Map<String, dynamic> data = {
      isP1 ? 'player1Score' : 'player2Score': newScore,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newScore >= session.targetScore) {
      data['status'] = 'finished';
      data['winner'] = myUid;
    }
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('competitive')
        .update(data);
  }

  static Future<void> deleteRemoteCompetitive(String coupleId) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('competitive')
        .delete();
  }

  // ── Remote Cooperative ─────────────────────────────────────────

  static Stream<RemoteCoopSession?> remoteCoopStream(String coupleId) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('cooperative')
        .snapshots()
        .map((s) => s.exists ? RemoteCoopSession.fromMap(s.data()!) : null);
  }

  static Future<void> startRemoteCoop({
    required String coupleId,
    required String voyantUid,
    required String devineurUid,
    required String firstWord,
    int targetScore = 10,
  }) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('cooperative')
        .set({
      'voyantUid': voyantUid,
      'devineurUid': devineurUid,
      'currentWord': firstWord,
      'teamScore': 0,
      'wordsGuessed': 0,
      'targetScore': targetScore,
      'status': 'playing',
      'pendingNewWord': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> submitCoopGuess({
    required String coupleId,
    required String guess,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('cooperative');
    final snap = await ref.get();
    if (!snap.exists) return false;
    final session = RemoteCoopSession.fromMap(snap.data()!);
    if (guess.trim().toLowerCase() != session.currentWord.toLowerCase()) {
      return false;
    }
    final newScore = session.teamScore + 5;
    final newWords = session.wordsGuessed + 1;
    final finished = newScore >= session.targetScore;
    await ref.update({
      'teamScore': newScore,
      'wordsGuessed': newWords,
      'currentWord': '',
      'pendingNewWord': true,
      'status': finished ? 'finished' : 'playing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  static Future<void> updateCoopWord({
    required String coupleId,
    required String newWord,
  }) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('cooperative')
        .update({
      'currentWord': newWord,
      'pendingNewWord': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteRemoteCoop(String coupleId) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('cooperative')
        .delete();
  }

  // ── Remote Timed ──────────────────────────────────────────────

  static Stream<RemoteTimedSession?> remoteTimedStream(String coupleId) {
    return FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .snapshots()
        .map((s) => s.exists ? RemoteTimedSession.fromMap(s.data()!) : null);
  }

  static Future<void> createRemoteTimed({
    required String coupleId,
    required String myUid,
    int durationSeconds = 60,
  }) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .set({
      'player1Uid': myUid,
      'player2Uid': null,
      'player1Score': 0,
      'player2Score': 0,
      'status': 'waiting',
      'startTime': null,
      'durationSeconds': durationSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> joinRemoteTimed({
    required String coupleId,
    required String myUid,
  }) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .update({
      'player2Uid': myUid,
      'status': 'playing',
      'startTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateTimedScore({
    required String coupleId,
    required String myUid,
    required RemoteTimedSession session,
    required int score,
  }) async {
    final isP1 = session.player1Uid == myUid;
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .update({
      isP1 ? 'player1Score' : 'player2Score': score,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> finishRemoteTimed(String coupleId) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .update({
      'status': 'finished',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteRemoteTimed(String coupleId) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .delete();
  }

  /// Emits the number of remote game modes where the partner is waiting for
  /// the current user to join (status == 'waiting' and player1Uid != myUid).
  /// Combines the competitive and timed document streams without rxdart.
  static Stream<int> pendingRemoteGameStream(
      String coupleId, String myUid) {
    final db = FirebaseFirestore.instance;
    final ctrl = StreamController<int>();
    int comp = 0, timed = 0;

    void emit() {
      if (!ctrl.isClosed) ctrl.add(comp + timed);
    }

    final subComp = db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('competitive')
        .snapshots()
        .listen((s) {
      final d = s.data();
      comp = (d != null &&
              d['status'] == 'waiting' &&
              d['player1Uid'] != myUid)
          ? 1
          : 0;
      emit();
    });

    final subTimed = db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc('timed')
        .snapshots()
        .listen((s) {
      final d = s.data();
      timed = (d != null &&
              d['status'] == 'waiting' &&
              d['player1Uid'] != myUid)
          ? 1
          : 0;
      emit();
    });

    ctrl.onCancel = () {
      subComp.cancel();
      subTimed.cancel();
    };

    return ctrl.stream;
  }
}

class RemoteCompetitiveSession {
  final String player1Uid;
  final String? player2Uid;
  final int player1Score;
  final int player2Score;
  final String status; // waiting | playing | finished
  final int targetScore;
  final String? winner;

  RemoteCompetitiveSession({
    required this.player1Uid,
    this.player2Uid,
    required this.player1Score,
    required this.player2Score,
    required this.status,
    required this.targetScore,
    this.winner,
  });

  factory RemoteCompetitiveSession.fromMap(Map<String, dynamic> map) =>
      RemoteCompetitiveSession(
        player1Uid: map['player1Uid'] as String? ?? '',
        player2Uid: map['player2Uid'] as String?,
        player1Score: map['player1Score'] as int? ?? 0,
        player2Score: map['player2Score'] as int? ?? 0,
        status: map['status'] as String? ?? 'waiting',
        targetScore: map['targetScore'] as int? ?? 10,
        winner: map['winner'] as String?,
      );

  int scoreFor(String uid) =>
      uid == player1Uid ? player1Score : player2Score;

  int partnerScore(String uid) =>
      uid == player1Uid ? player2Score : player1Score;
}

class RemoteCoopSession {
  final String voyantUid;
  final String devineurUid;
  final String currentWord;
  final int teamScore;
  final int wordsGuessed;
  final int targetScore;
  final String status; // playing | finished
  final bool pendingNewWord;

  RemoteCoopSession({
    required this.voyantUid,
    required this.devineurUid,
    required this.currentWord,
    required this.teamScore,
    required this.wordsGuessed,
    required this.targetScore,
    required this.status,
    required this.pendingNewWord,
  });

  factory RemoteCoopSession.fromMap(Map<String, dynamic> map) =>
      RemoteCoopSession(
        voyantUid: map['voyantUid'] as String? ?? '',
        devineurUid: map['devineurUid'] as String? ?? '',
        currentWord: map['currentWord'] as String? ?? '',
        teamScore: map['teamScore'] as int? ?? 0,
        wordsGuessed: map['wordsGuessed'] as int? ?? 0,
        targetScore: map['targetScore'] as int? ?? 10,
        status: map['status'] as String? ?? 'playing',
        pendingNewWord: map['pendingNewWord'] as bool? ?? false,
      );
}

class RemoteTimedSession {
  final String player1Uid;
  final String? player2Uid;
  final int player1Score;
  final int player2Score;
  final String status; // waiting | playing | finished
  final DateTime? startTime;
  final int durationSeconds;

  RemoteTimedSession({
    required this.player1Uid,
    this.player2Uid,
    required this.player1Score,
    required this.player2Score,
    required this.status,
    this.startTime,
    required this.durationSeconds,
  });

  factory RemoteTimedSession.fromMap(Map<String, dynamic> map) =>
      RemoteTimedSession(
        player1Uid: map['player1Uid'] as String? ?? '',
        player2Uid: map['player2Uid'] as String?,
        player1Score: map['player1Score'] as int? ?? 0,
        player2Score: map['player2Score'] as int? ?? 0,
        status: map['status'] as String? ?? 'waiting',
        startTime: (map['startTime'] as Timestamp?)?.toDate(),
        durationSeconds: map['durationSeconds'] as int? ?? 60,
      );

  int scoreFor(String uid) =>
      uid == player1Uid ? player1Score : player2Score;

  int partnerScore(String uid) =>
      uid == player1Uid ? player2Score : player1Score;
}
