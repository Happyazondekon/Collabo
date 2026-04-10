import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class GalleryPhoto {
  final String id;
  final String imageData; // base64-encoded image
  final String title;
  final String addedBy;
  final DateTime savedAt;
  final DateTime? photoDate; // user-chosen date for the photo

  GalleryPhoto({
    required this.id,
    required this.imageData,
    required this.title,
    required this.addedBy,
    required this.savedAt,
    this.photoDate,
  });

  factory GalleryPhoto.fromMap(String id, Map<String, dynamic> map) =>
      GalleryPhoto(
        id: id,
        imageData: map['imageData'] as String? ?? '',
        title: map['title'] as String? ?? 'Photo',
        addedBy: map['addedBy'] as String? ?? '',
        savedAt: (map['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        photoDate: (map['photoDate'] as Timestamp?)?.toDate(),
      );
}

class GalleryService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static String? get _myUid => _auth.currentUser?.uid;

  final _picker = ImagePicker();

  /// Live stream of photos for a couple, newest first.
  Stream<List<GalleryPhoto>> photosStream(String coupleId) {
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('gallery')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GalleryPhoto.fromMap(d.id, d.data()))
            .toList());
  }

  /// Pick from gallery and upload. Returns false if user cancelled.
  Future<bool> pickAndAddPhoto(String coupleId,
      {String title = '', DateTime? photoDate}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (picked == null) return false;

    final uid = _myUid;
    if (uid == null) return false;

    final bytes = await File(picked.path).readAsBytes();
    final imageData = base64Encode(bytes);

    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('gallery')
        .add({
      'imageData': imageData,
      'title': title.trim().isEmpty ? 'Photo' : title.trim(),
      'addedBy': uid,
      'savedAt': FieldValue.serverTimestamp(),
      if (photoDate != null) 'photoDate': Timestamp.fromDate(photoDate),
    });
    return true;
  }

  Future<void> deletePhoto(String coupleId, String photoId) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('gallery')
        .doc(photoId)
        .delete();
  }
}
