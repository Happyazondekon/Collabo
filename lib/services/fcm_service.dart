import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Gère Firebase Cloud Messaging :
///   • Sauvegarde le token FCM dans Firestore pour que les Cloud Functions
///     puissent envoyer des notifs push même app fermée.
///   • Affiche une notif locale quand un message FCM arrive au premier plan.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    // 1. Demande de permission (iOS / Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Enregistrement du token
    await _saveToken(await _fcm.getToken());

    // 3. Rafraîchissement automatique du token
    _fcm.onTokenRefresh.listen(_saveToken);

    // 4. Messages reçus AU PREMIER PLAN → notif locale
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5. Tap sur une notif alors que l'app était en arrière-plan (ouverte)
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);

    // 6. Tap sur la notif de lancement (app était fermée)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onNotificationOpened(initial);
  }

  Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
      debugPrint('📲 FCM token saved');
    } catch (e) {
      debugPrint('⚠️ FCM token save failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    final type = message.data['type'] as String? ?? '';
    switch (type) {
      case 'message':
        CollaboNotificationService().showNewMessage(
          senderName: notif.title ?? 'Nouveau message',
        );
        break;
      case 'call':
        // L'écran d'appel entrant est géré séparément via Firestore stream.
        // On affiche juste une notif discrète si déjà dans l'appli.
        CollaboNotificationService().showMissedCall(
          callerName: notif.title ?? 'Appel',
          isVideo: message.data['isVideo'] == 'true',
        );
        break;
      case 'partner_post':
        CollaboNotificationService().showPartnerPost(
          partnerName: notif.title ?? 'Votre partenaire',
        );
        break;
      case 'game_invite':
        CollaboNotificationService().showGameInvite(
          partnerName: notif.title ?? 'Votre partenaire',
        );
        break;
      default:
        // Notif générique
        CollaboNotificationService().showNewMessage(
          senderName: notif.title ?? 'Collabo',
        );
    }
  }

  void _onNotificationOpened(RemoteMessage message) {
    // La navigation sera gérée selon le type quand le contexte l'app est prêt.
    final type = message.data['type'] as String? ?? '';
    debugPrint('🔔 Notification ouverte - type: $type');
    // Vous pouvez ajouter ici un navigateur global si nécessaire.
  }
}
