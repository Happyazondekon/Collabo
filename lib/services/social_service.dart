import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// ─── Moderation word list ─────────────────────────────────────────
// Checked case-insensitively. Covers FR / EN / multilingual slang,
// sexual terms, insults, and phone-number fishing patterns.
const _bannedWords = [
  // ── Gros mots français ──────────────────────────────────────────
  'merde', 'putain', 'pute', 'connard', 'connasse', 'salope', 'enculé',
  'enculer', 'nique', 'niquer', 'baise', 'baiser', 'con', 'cul', 'bite',
  'chier', 'bordel', 'couille', 'couilles', 'couillon', 'foutre', 'va te faire',
  'fils de pute', 'ta gueule', 'ferme ta gueule', 'fdp', 'pd', 'tapette',
  'grosse vache', 'porc', 'ordure', 'raclure', 'salopard', 'saloperie',
  'dégage', 'espèce de',

  // ── Insultes / harcèlement français ─────────────────────────────
  'idiot', 'idiote', 'imbécile', 'débile', 'mongol', 'mongole', 'attardé',
  'bouffon', 'nul', 'nulle', 'laid', 'laide', 'gros lard', 'grosse',
  'vieux con', 'vieille pute', 'crétin', 'crétine',

  // ── Termes sexuels explicites ───────────────────────────────────
  'sexe', 'sexuel', 'pénis', 'vagin', 'orgasme', 'ejac', 'éjac',
  'masturbation', 'masturber', 'branler', 'branlette', 'sodomie',
  'sodomiser', 'fellation', 'cunnilingus', 'porn', 'porno', 'pornographie',
  'nu', 'nue', 'nudes', 'nude', 'strip', 'stripper', 'déshabille',
  'hard porn', 'x video', 'xvideo', 'xnxx', 'xhamster', 'youporn',

  // ── Slang sexual mondial ─────────────────────────────────────────
  'chudai',   // hindi
  'chut',     // hindi slang
  'lund',     // hindi
  'gaand',    // hindi
  'randi',    // hindi
  'harami',   // hindi/urdu
  'wataa',    // argot sexuel
  'wata',
  'boobs', 'boob', 'tits', 'tit', 'dick', 'cock', 'pussy', 'cunt',
  'ass', 'asshole', 'anal', 'boner', 'blowjob', 'handjob', 'cumshot',
  'cum', 'milf', 'dildo', 'vibrator', 'bdsm', 'fetish', 'kinky',
  'squirt', 'creampie', 'gangbang', 'threesome', 'orgy',

  // ── Insultes anglaises ───────────────────────────────────────────
  'fuck', 'fucker', 'fucking', 'shit', 'bastard', 'whore', 'slut',
  'bitch', 'motherfucker', 'mf', 'stfu', 'wtf', 'idiot', 'moron',
  'retard', 'loser', 'dumbass', 'jackass', 'nigger', 'nigga', 'faggot',
  'dyke', 'tranny',

  // ── Numéros de téléphone (patterns) ─────────────────────────────
  // Détecte des suites de 8+ chiffres consécutifs (numéros de tél)
  // NB: géré séparément dans _censorText via regex, mais on liste
  // aussi quelques patterns textuels courants de fishing
  'mon numéro', 'mon numero', 'appelez-moi', 'appelle moi', 'appelle-moi',
  'contactez-moi', 'whatsapp moi', 'whatsap moi', 'wa moi',
  'telegram moi', 'signal moi', 'snapchat moi', 'insta moi',
  'envoie ton numéro', 'envoie ton numero', 'donne ton numéro',
  'donne ton numero', 'dm moi', 'mp moi', 'glisse en mp',

  // ── Spam / arnaque ───────────────────────────────────────────────
  'cliquez ici', 'click here', 'gagnez argent', 'gain rapide',
  'investissement garanti', 'bitcoin gratuit', 'forex', 'pyramide',
  'mlm', 'recrutement urgent', 'offre limitée', 'offre limitee',
];


String _censorText(String text) {
  String result = text;
  // 1. Censure les mots de la liste
  for (final word in _bannedWords) {
    final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b',
        caseSensitive: false);
    result =
        result.replaceAllMapped(pattern, (m) => '*' * m.group(0)!.length);
  }
  // 2. Masque les séquences de 8 chiffres ou plus (numéros de téléphone)
  result = result.replaceAllMapped(
    RegExp(r'\d[\d\s\-\.]{6,}\d'),
    (m) => '*' * m.group(0)!.length,
  );
  return result;
}

bool _containsBannedWord(String text) {
  final lower = text.toLowerCase();
  return _bannedWords.any((w) => lower.contains(w));
}

// ─── Models ───────────────────────────────────────────────────────

class FeedPost {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatar;
  final String? authorAvatarData;
  final String content;
  final String? imageUrl;    // legacy: remote URL
  final String? imageData;  // base64 encoded image (new)
  final List<String> likedBy;
  final int commentCount;
  final int repostCount;
  final String? repostOfId; // null = original
  final String? repostOfAuthorName;
  final String? repostOfContent;
  final DateTime createdAt;

  FeedPost({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorAvatar,
    this.authorAvatarData,
    required this.content,
    this.imageUrl,
    this.imageData,
    required this.likedBy,
    required this.commentCount,
    required this.repostCount,
    this.repostOfId,
    this.repostOfAuthorName,
    this.repostOfContent,
    required this.createdAt,
  });

  bool get isRepost => repostOfId != null;

  factory FeedPost.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FeedPost(
      id: doc.id,
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'Anonyme',
      authorAvatar: d['authorAvatar'] as String?,
      authorAvatarData: d['authorAvatarData'] as String?,
      content: d['content'] as String? ?? '',
      imageUrl: d['imageUrl'] as String?,
      imageData: d['imageData'] as String?,
      likedBy: (d['likedBy'] as List?)?.cast<String>() ?? [],
      commentCount: d['commentCount'] as int? ?? 0,
      repostCount: d['repostCount'] as int? ?? 0,
      repostOfId: d['repostOfId'] as String?,
      repostOfAuthorName: d['repostOfAuthorName'] as String?,
      repostOfContent: d['repostOfContent'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FeedComment {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorAvatar;
  final String? authorAvatarData;
  final String content;
  final DateTime createdAt;

  FeedComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorAvatar,
    this.authorAvatarData,
    required this.content,
    required this.createdAt,
  });

  factory FeedComment.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FeedComment(
      id: doc.id,
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'Anonyme',
      authorAvatar: d['authorAvatar'] as String?,
      authorAvatarData: d['authorAvatarData'] as String?,
      content: d['content'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────

class SocialService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('feed_posts');

  // ── Returns true if the text is acceptable ────────────────────
  static bool isTextClean(String text) => !_containsBannedWord(text);

  // ── Feed stream ───────────────────────────────────────────────
  static Stream<List<FeedPost>> feedStream({int limit = 50}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(FeedPost.fromDoc).toList());
  }

  // ── Pick image from gallery/camera ──────────────────────────
  static Future<String?> pickImageAsBase64(
      {ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (picked == null) return null;
    final bytes = await File(picked.path).readAsBytes();
    return base64Encode(bytes);
  }

  // ── Create post ───────────────────────────────────────────────
  /// Returns null on success, or an error message string if blocked.
  static Future<String?> createPost({
    required String content,
    String? imageUrl,
    String? imageData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'Non authentifié.';

    final trimmed = content.trim();
    if (trimmed.isEmpty) return 'Le post ne peut pas être vide.';
    if (trimmed.length > 500) {
      return 'Le post ne peut pas dépasser 500 caractères.';
    }

    // Censor rather than block — replaces banned words with asterisks
    final censored = _censorText(trimmed);

    final profileSnap =
        await _db.collection('users').doc(user.uid).get();
    final profileData = profileSnap.data();
    final authorName = profileData?['pseudo'] as String? ??
        profileData?['displayName'] as String? ??
        user.displayName ??
        'Utilisateur';
    final authorAvatar = profileData?['avatarUrl'] as String?;
    final authorAvatarData = profileData?['avatarData'] as String?;

    await _posts.add({
      'authorUid': user.uid,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      if (authorAvatarData != null) 'authorAvatarData': authorAvatarData,
      'content': censored,
      'imageUrl': imageUrl,
      'imageData': imageData,
      'likedBy': [],
      'commentCount': 0,
      'repostCount': 0,
      'repostOfId': null,
      'repostOfAuthorName': null,
      'repostOfContent': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  }

  // ── Repost ────────────────────────────────────────────────────
  static Future<String?> repost({
    required FeedPost original,
    String comment = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'Non authentifié.';

    final censored = _censorText(comment.trim());

    final profileSnap =
        await _db.collection('users').doc(user.uid).get();
    final profileData = profileSnap.data();
    final authorName = profileData?['pseudo'] as String? ??
        profileData?['displayName'] as String? ??
        user.displayName ??
        'Utilisateur';
    final authorAvatar = profileData?['avatarUrl'] as String?;
    final authorAvatarData = profileData?['avatarData'] as String?;

    final batch = _db.batch();
    final newRef = _posts.doc();
    batch.set(newRef, {
      'authorUid': user.uid,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      if (authorAvatarData != null) 'authorAvatarData': authorAvatarData,
      'content': censored,
      'imageUrl': null,
      'likedBy': [],
      'commentCount': 0,
      'repostCount': 0,
      'repostOfId': original.id,
      'repostOfAuthorName': original.authorName,
      'repostOfContent': original.content,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_posts.doc(original.id), {
      'repostCount': FieldValue.increment(1),
    });
    await batch.commit();
    return null;
  }

  // ── Toggle like ───────────────────────────────────────────────
  static Future<void> toggleLike(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _posts.doc(postId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final liked =
        ((snap.data()!['likedBy'] as List?)?.cast<String>() ?? []);
    if (liked.contains(uid)) {
      await ref.update({
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'likedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  // ── Comments stream ───────────────────────────────────────────
  static Stream<List<FeedComment>> commentsStream(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(FeedComment.fromDoc).toList());
  }

  // ── Add comment ───────────────────────────────────────────────
  static Future<String?> addComment({
    required String postId,
    required String content,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'Non authentifié.';

    final trimmed = content.trim();
    if (trimmed.isEmpty) return 'Le commentaire ne peut pas être vide.';
    if (trimmed.length > 300) {
      return 'Le commentaire ne peut pas dépasser 300 caractères.';
    }

    final censored = _censorText(trimmed);

    final profileSnap =
        await _db.collection('users').doc(user.uid).get();
    final profileData = profileSnap.data();
    final authorName = profileData?['pseudo'] as String? ??
        profileData?['displayName'] as String? ??
        user.displayName ??
        'Utilisateur';
    final authorAvatar = profileData?['avatarUrl'] as String?;
    final authorAvatarData = profileData?['avatarData'] as String?;

    final batch = _db.batch();
    final commentRef =
        _posts.doc(postId).collection('comments').doc();
    batch.set(commentRef, {
      'authorUid': user.uid,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      if (authorAvatarData != null) 'authorAvatarData': authorAvatarData,
      'content': censored,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_posts.doc(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
    return null;
  }

  // ── Delete post (own only) ────────────────────────────────────
  static Future<void> deletePost(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _posts.doc(postId).get();
    if (!snap.exists) return;
    if (snap.data()!['authorUid'] != uid) return; // not owner
    await _posts.doc(postId).delete();
  }

  // ── Report post ───────────────────────────────────────────────
  static Future<void> reportPost(String postId, String reason) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('reports').add({
      'postId': postId,
      'reportedBy': uid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ADMIN — methodes réservées à heyhappyproject@gmail.com
  // ═══════════════════════════════════════════════════════════════

  static const _adminEmail = 'heyhappyproject@gmail.com';

  static bool get isAdmin =>
      _auth.currentUser?.email?.toLowerCase() == _adminEmail;

  /// Supprime n'importe quel post (admin uniquement).
  static Future<void> adminDeletePost(String postId) async {
    if (!isAdmin) return;
    await _posts.doc(postId).delete();
  }

  /// Résout un signalement (le marque comme traité).
  static Future<void> resolveReport(String reportId,
      {bool deleted = false}) async {
    if (!isAdmin) return;
    await _db.collection('reports').doc(reportId).update({
      'resolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
      'postDeleted': deleted,
    });
  }

  /// Stream de tous les signalements non résolus.
  static Stream<List<AdminReport>> reportsStream({bool onlyOpen = true}) {
    Query<Map<String, dynamic>> q = _db
        .collection('reports')
        .orderBy('createdAt', descending: true);
    if (onlyOpen) q = q.where('resolved', isEqualTo: false);
    return q.snapshots().map((s) =>
        s.docs.map(AdminReport.fromDoc).toList());
  }

  /// Stream de tous les posts (feed complet, admin).
  static Stream<List<FeedPost>> allPostsStream({int limit = 100}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(FeedPost.fromDoc).toList());
  }

  /// Stream de tous les utilisateurs (admin).
  static Stream<List<AdminUser>> allUsersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AdminUser.fromDoc).toList());
  }

  /// Statistiques globales (snapshot unique).
  static Future<AdminStats> getStats() async {
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _posts.count().get(),
      _db.collection('reports').where('resolved', isEqualTo: false).count().get(),
      _db.collection('couples').count().get(),
      _db.collection('reports').count().get(),
    ]);
    return AdminStats(
      totalUsers:    results[0].count ?? 0,
      totalPosts:    results[1].count ?? 0,
      openReports:   results[2].count ?? 0,
      totalCouples:  results[3].count ?? 0,
      totalReports:  results[4].count ?? 0,
    );
  }
}

// ─── Admin models ─────────────────────────────────────────────────

class AdminReport {
  final String id;
  final String postId;
  final String reportedBy;
  final String reason;
  final DateTime createdAt;
  final bool resolved;

  AdminReport({
    required this.id,
    required this.postId,
    required this.reportedBy,
    required this.reason,
    required this.createdAt,
    required this.resolved,
  });

  factory AdminReport.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdminReport(
      id: doc.id,
      postId: d['postId'] as String? ?? '',
      reportedBy: d['reportedBy'] as String? ?? '',
      reason: d['reason'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolved: d['resolved'] as bool? ?? false,
    );
  }
}

class AdminUser {
  final String uid;
  final String displayName;
  final String? pseudo;
  final String? email;
  final String? avatarUrl;
  final String? coupleId;
  final DateTime? createdAt;

  AdminUser({
    required this.uid,
    required this.displayName,
    this.pseudo,
    this.email,
    this.avatarUrl,
    this.coupleId,
    this.createdAt,
  });

  factory AdminUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdminUser(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? 'Inconnu',
      pseudo: d['pseudo'] as String?,
      email: d['email'] as String?,
      avatarUrl: d['avatarUrl'] as String?,
      coupleId: d['coupleId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminStats {
  final int totalUsers;
  final int totalPosts;
  final int openReports;
  final int totalCouples;
  final int totalReports;

  AdminStats({
    required this.totalUsers,
    required this.totalPosts,
    required this.openReports,
    required this.totalCouples,
    required this.totalReports,
  });
}
