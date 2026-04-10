import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../models/event_model.dart';

/// Service de notifications locales pour Collabo.
///
/// Couvre :
///   • Notifications immédiates (app au premier plan) :
///       – Nouveau message du partenaire
///       – Nouveau post du partenaire dans le feed
///       – Demande de lien partenaire / ami
///       – Invitation à un jeu à distance
///       – Badge débloqué
///   • Rappels programmés (fonctionnent même quand l'app est fermée) :
///       – Saint-Valentin (14 fév)
///       – Journée de la Femme (8 mars)
///       – Fête des Mères (dernier dimanche de mai)
///       – Fête des Pères (3ème dimanche de juin)
///       – Fête des Amoureux africains (14 juil., adaptable)
///       – Noël (25 déc.)
///       – Jour de l'An (1er jan.)
///       – Anniversaire de couple (J-3, J-1, J)
///       – Anniversaire du partenaire (J-3, J-1, J)
///       – Rappel hebdomadaire romantique (dimanche 19h)
///       – Événements du calendrier de couple (J-1 et J-day)
class CollaboNotificationService {
  // ── Singleton ──────────────────────────────────────────────────
  static final CollaboNotificationService _instance =
      CollaboNotificationService._internal();
  factory CollaboNotificationService() => _instance;
  CollaboNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── SharedPreferences keys ─────────────────────────────────────
  static const _keyEnabled = 'collabo_notifs_enabled';

  // ── Channel IDs ────────────────────────────────────────────────
  static const _chMessages  = 'collabo_messages';
  static const _chSocial    = 'collabo_social';
  static const _chInvites   = 'collabo_invites';
  static const _chReminders = 'collabo_reminders';

  static const Map<String, String> _channelNames = {
    _chMessages:  'Messages',
    _chSocial:    'Activité sociale',
    _chInvites:   'Invitations',
    _chReminders: 'Rappels romantiques',
  };

  // ── Notification IDs ──────────────────────────────────────────
  //   Immédiats
  static const _idMessage         = 1001;
  static const _idPartnerPost     = 1002;
  static const _idCoupleRequest   = 1003;
  static const _idFriendRequest   = 1004;
  static const _idGameInvite      = 1005;
  static const _idBadgeUnlocked   = 1006;

  //   Romantiques annuels
  static const _idValentinePre    = 1101;
  static const _idValentine       = 1102;
  static const _idWomensDay       = 1103;
  static const _idMothersDay      = 1104;
  static const _idFathersDay      = 1105;
  static const _idChristmasPre    = 1106;
  static const _idChristmas       = 1107;
  static const _idNewYear         = 1108;

  //   Anniversaire de couple
  static const _idAnnivPre3       = 1110;
  static const _idAnnivPre1       = 1111;
  static const _idAnniv           = 1112;

  //   Anniversaire partenaire
  static const _idBirthdayPre3    = 1120;
  static const _idBirthdayPre1    = 1121;
  static const _idBirthday        = 1122;

  //   Hebdo
  static const _idWeeklyLove      = 1130;

  //   Calendrier couple (base + index*2 pour J-1, +index*2+1 pour J)
  static const _calBase           = 2000;
  static const _calMaxEvents      = 100;

  //   Test
  static const _idTest            = 9999;

  // ── Couleurs brand ─────────────────────────────────────────────
  static const _colorPrimary = Color(0xFFD0216E);
  static const _colorAccent  = Color(0xFF7C3AED);

  // ═══════════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      _configureTimezone();

      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final ok = await _plugin.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onTapped,
      );

      if (ok == true) {
        _initialized = true;
        await _createChannels();

        if (await isFirstLaunch()) {
          // Premier lancement : demande permissions + auto-enable
          final granted = await requestPermissions();
          await setEnabled(granted);
          debugPrint('🆕 Premier lancement – notifications ${granted ? "activées" : "refusées"}');
        } else if (await isEnabled()) {
          debugPrint('🔄 Notifications déjà activées – reprogrammation via profil');
        }
        debugPrint('✅ CollaboNotificationService initialisé');
      }
    } catch (e) {
      debugPrint('❌ Erreur init CollaboNotificationService: $e');
    }
  }

  void _configureTimezone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      final name = switch (offset.inHours) {
        0     => 'Africa/Abidjan',
        1     => 'Africa/Lagos',
        2     => 'Africa/Cairo',
        3     => 'Africa/Nairobi',
        int h when h >= 4 => 'Asia/Dubai',
        _     => 'Europe/Paris',
      };
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('🕐 Timezone Collabo: $name (UTC${offset.inHours >= 0 ? '+' : ''}${offset.inHours})');
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Paris'));
      } catch (_) {}
    }
  }

  void _onTapped(NotificationResponse r) {
    debugPrint('💬 Notification Collabo tappée – payload: ${r.payload}');
    // Navigation conditionnelle possible ici selon r.payload
  }

  // ═══════════════════════════════════════════════════════════════
  // CRÉATION DES CANAUX ANDROID
  // ═══════════════════════════════════════════════════════════════

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chMessages, 'Messages',
      description: 'Nouveaux messages de votre amour',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chSocial, 'Activité sociale',
      description: 'Posts et interactions de votre partenaire',
      importance: Importance.defaultImportance,
      playSound: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chInvites, 'Invitations',
      description: 'Demandes de lien et invitations de jeu',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chReminders, 'Rappels romantiques',
      description: 'Fêtes, anniversaires et rendez-vous amoureux',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
    debugPrint('📢 Canaux Collabo créés');
  }

  // ═══════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ═══════════════════════════════════════════════════════════════

  Future<bool> requestPermissions() async {
    try {
      final notif = await Permission.notification.request();
      if (notif.isDenied || notif.isPermanentlyDenied) return false;

      final alarm = await Permission.scheduleExactAlarm.request();
      if (alarm.isDenied) {
        debugPrint('⚠️ Permission alarme exacte refusée – notifications approximatives');
      }
      return notif.isGranted;
    } catch (e) {
      debugPrint('❌ Erreur permissions: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    final notif  = await Permission.notification.status;
    final alarm  = await Permission.scheduleExactAlarm.status;
    return notif.isGranted && alarm.isGranted;
  }

  // ═══════════════════════════════════════════════════════════════
  // ÉTAT DES NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<bool> isFirstLaunch() async {
    final p = await SharedPreferences.getInstance();
    return !p.containsKey(_keyEnabled);
  }

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyEnabled) ?? true;
  }

  Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyEnabled, v);
    if (!v) await cancelAll();
    debugPrint(v ? '🔔 Notifications Collabo activées' : '🔕 Notifications Collabo désactivées');
  }

  Future<bool> isSystemEnabled() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // NOTIFICATIONS IMMÉDIATES (déclenchées par la logique de l'app)
  // ═══════════════════════════════════════════════════════════════

  /// Nouveau message du partenaire. Appeler quand _chatUnreadCount augmente.
  Future<void> showNewMessage({String? senderName}) async {
    if (!await isEnabled()) return;
    await _show(
      id: _idMessage,
      channelId: _chMessages,
      title: '💬 Nouveau message${senderName != null ? ' de $senderName' : ''}',
      body: 'Votre amour vous a écrit – répondez-lui ! 💕',
      payload: 'tab:chat',
      color: _colorPrimary,
    );
  }

  /// Nouveau post du partenaire dans le feed social.
  Future<void> showPartnerPost({String? partnerName}) async {
    if (!await isEnabled()) return;
    await _show(
      id: _idPartnerPost,
      channelId: _chSocial,
      title: '✨ ${partnerName ?? 'Votre amour'} a partagé un moment',
      body: 'Découvrez ce qu\'il·elle a publié dans la communauté 💞',
      payload: 'tab:feed',
      color: _colorAccent,
    );
  }

  /// Nouvelle demande de lien partenaire reçue.
  Future<void> showCoupleRequest({required String fromName}) async {
    if (!await isEnabled()) return;
    await _show(
      id: _idCoupleRequest,
      channelId: _chInvites,
      title: '💌 $fromName veut se lier à vous',
      body: 'Acceptez sa demande pour commencer votre aventure sur Collabo 💕',
      payload: 'tab:profile',
      color: _colorPrimary,
    );
  }

  /// Nouvelle demande d'ami reçue.
  Future<void> showFriendRequest({required String fromName}) async {
    if (!await isEnabled()) return;
    await _show(
      id: _idFriendRequest,
      channelId: _chInvites,
      title: '🤝 $fromName vous envoie une demande',
      body: 'Acceptez pour l\'ajouter à vos proches sur Collabo',
      payload: 'tab:profile',
      color: _colorAccent,
    );
  }

  /// Partenaire en attente sur un jeu à distance.
  Future<void> showGameInvite({
    String? partnerName,
    String gameType = '',
  }) async {
    if (!await isEnabled()) return;
    final label = switch (gameType) {
      'competitive' => 'Compétitif 🏆',
      'coop'        => 'Coopératif 🤝',
      'timed'       => 'Contre-la-Montre ⏱️',
      _             => 'en ligne 🎮',
    };
    await _show(
      id: _idGameInvite,
      channelId: _chInvites,
      title: '🎮 ${partnerName ?? 'Votre amour'} vous défie !',
      body: 'Une partie $label vous attend – rejoignez-le·la !',
      payload: 'tab:games:$gameType',
      color: _colorAccent,
    );
  }

  /// Badge romantique débloqué.
  Future<void> showBadgeUnlocked({required String badgeName}) async {
    if (!await isEnabled()) return;
    await _show(
      id: _idBadgeUnlocked,
      channelId: _chSocial,
      title: '🏅 Nouveau badge débloqué !',
      body: 'Félicitations ! Vous avez gagné le badge « $badgeName » 🎉',
      payload: 'tab:profile',
      color: _colorPrimary,
    );
  }

  /// Appel manqué de la part du partenaire.
  Future<void> showMissedCall({String? callerName, bool isVideo = false}) async {
    if (!await isEnabled()) return;
    await _show(
      id: 1007,
      channelId: _chMessages,
      title: isVideo
          ? '📹 Appel vidéo manqué${callerName != null ? ' de $callerName' : ''}'
          : '📞 Appel manqué${callerName != null ? ' de $callerName' : ''}',
      body: 'Rappeler votre amour dès que possible 💕',
      payload: 'tab:chat',
      color: _colorPrimary,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RAPPELS ROMANTIQUES PROGRAMMÉS (fonctionnent app fermée)
  // ═══════════════════════════════════════════════════════════════

  /// Programme tous les rappels romantiques récurrents.
  /// À appeler après chaque chargement du profil utilisateur pour
  /// intégrer les dates personnalisées (anniversaire, BD partenaire).
  ///
  /// [partnerName]     : prénom ou pseudo du partenaire
  /// [anniversaryDate] : date de début de la relation
  /// [partnerBirthday] : date de naissance du partenaire
  Future<void> scheduleRomanticReminders({
    String?   partnerName,
    DateTime? anniversaryDate,
    DateTime? partnerBirthday,
  }) async {
    if (!await isEnabled() || !await hasPermissions()) return;

    final partner = partnerName ?? 'votre amour';

    // ── Saint-Valentin (14 février) ─────────────────────────────
    await _scheduleYearly(
      id: _idValentinePre,
      month: 2, day: 11, hour: 18, minute: 0,
      title: '💝 Saint-Valentin dans 3 jours !',
      body: 'Pensez à préparer quelque chose de spécial pour $partner 🌹',
      channelId: _chReminders,
    );
    await _scheduleYearly(
      id: _idValentine,
      month: 2, day: 14, hour: 8, minute: 0,
      title: '❤️ Joyeuse Saint-Valentin !',
      body: 'Dites à $partner combien vous l\'aimez aujourd\'hui 💌',
      channelId: _chReminders,
    );

    // ── Journée Internationale des Femmes (8 mars) ──────────────
    await _scheduleYearly(
      id: _idWomensDay,
      month: 3, day: 8, hour: 8, minute: 30,
      title: '🌸 Journée de la Femme',
      body: 'Célébrez et chérissez $partner aujourd\'hui et chaque jour 💐',
      channelId: _chReminders,
    );

    // ── Fête des Mères (dernier dimanche de mai) ─────────────────
    await _scheduleVariableYearly(
      id: _idMothersDay,
      dateResolver: _mothersDay,
      hour: 9, minute: 0,
      title: '🌺 Bonne Fête des Mères !',
      body: 'Pensez à souhaiter un beau dimanche aux mamans de votre vie 💕',
      channelId: _chReminders,
    );

    // ── Fête des Pères (3ème dimanche de juin) ───────────────────
    await _scheduleVariableYearly(
      id: _idFathersDay,
      dateResolver: _fathersDay,
      hour: 9, minute: 0,
      title: '🎖️ Bonne Fête des Pères !',
      body: 'Célébrez les papas de votre entourage 💙',
      channelId: _chReminders,
    );

    // ── Veille de Noël + Noël ────────────────────────────────────
    await _scheduleYearly(
      id: _idChristmasPre,
      month: 12, day: 24, hour: 17, minute: 0,
      title: '🎄 Joyeux réveillon de Noël !',
      body: 'Passez une belle soirée magique avec $partner 🕯️✨',
      channelId: _chReminders,
    );
    await _scheduleYearly(
      id: _idChristmas,
      month: 12, day: 25, hour: 8, minute: 0,
      title: '🎅 Joyeux Noël !',
      body: 'Profitez de cette journée spéciale avec $partner 🎁',
      channelId: _chReminders,
    );

    // ── Jour de l'An ─────────────────────────────────────────────
    await _scheduleYearly(
      id: _idNewYear,
      month: 1, day: 1, hour: 0, minute: 1,
      title: '🎆 Bonne et heureuse année !',
      body: 'Que cette nouvelle année avec $partner soit pleine de bonheur 🥂',
      channelId: _chReminders,
    );

    // ── Rappel hebdomadaire romantique (dimanche 19h) ────────────
    await _scheduleWeekly(
      id: _idWeeklyLove,
      weekday: DateTime.sunday,
      hour: 19, minute: 0,
      title: '💑 Soirée en amoureux ?',
      body: 'Profitez de ce dimanche pour vous retrouver sur Collabo 🥂',
      channelId: _chReminders,
    );

    // ── Anniversaire de couple ───────────────────────────────────
    if (anniversaryDate != null) {
      final now = DateTime.now();
      final years = now.year - anniversaryDate.year;
      final yearStr = years <= 0
          ? '1 an'
          : '$years an${years > 1 ? 's' : ''}';

      // J-3 (gérer le changement de mois proprement)
      final pre3 = DateTime(now.year, anniversaryDate.month,
          anniversaryDate.day).subtract(const Duration(days: 3));
      await _scheduleYearly(
        id: _idAnnivPre3,
        month: pre3.month, day: pre3.day, hour: 18, minute: 0,
        title: '💍 Anniversaire de couple dans 3 jours !',
        body: 'Préparez quelque chose de mémorable pour $partner 🎉',
        channelId: _chReminders,
      );

      // J-1
      final pre1 = DateTime(now.year, anniversaryDate.month,
          anniversaryDate.day).subtract(const Duration(days: 1));
      await _scheduleYearly(
        id: _idAnnivPre1,
        month: pre1.month, day: pre1.day, hour: 18, minute: 0,
        title: '💍 Demain : votre anniversaire de couple !',
        body: '$yearStr d\'amour avec $partner – préparez-vous 💕',
        channelId: _chReminders,
      );

      // Jour J
      await _scheduleYearly(
        id: _idAnniv,
        month: anniversaryDate.month, day: anniversaryDate.day, hour: 8, minute: 0,
        title: '🎉 Joyeux anniversaire de couple !',
        body: '$yearStr ensemble avec $partner ! Que cet amour brille toujours ✨',
        channelId: _chReminders,
        color: _colorPrimary,
      );
    }

    // ── Anniversaire du partenaire ───────────────────────────────
    if (partnerBirthday != null) {
      final now = DateTime.now();

      // J-3
      final bPre3 = DateTime(now.year, partnerBirthday.month,
          partnerBirthday.day).subtract(const Duration(days: 3));
      await _scheduleYearly(
        id: _idBirthdayPre3,
        month: bPre3.month, day: bPre3.day, hour: 18, minute: 0,
        title: '🎂 Anniversaire de $partner dans 3 jours !',
        body: 'N\'oubliez pas de lui préparer quelque chose de spécial 🎁',
        channelId: _chReminders,
      );

      // J-1
      final bPre1 = DateTime(now.year, partnerBirthday.month,
          partnerBirthday.day).subtract(const Duration(days: 1));
      await _scheduleYearly(
        id: _idBirthdayPre1,
        month: bPre1.month, day: bPre1.day, hour: 18, minute: 0,
        title: '🎂 Demain : c\'est l\'anniversaire de $partner !',
        body: 'Préparez-vous à lui souhaiter un merveilleux anniversaire 🥳',
        channelId: _chReminders,
      );

      // Jour J
      await _scheduleYearly(
        id: _idBirthday,
        month: partnerBirthday.month, day: partnerBirthday.day, hour: 8, minute: 0,
        title: '🎉 Joyeux anniversaire $partner !',
        body: 'Souhaitez-lui un beau jour plein de joie et d\'amour 💕',
        channelId: _chReminders,
      );
    }

    debugPrint('💕 Rappels romantiques Collabo programmés (partenaire: $partner)');
  }

  /// Programme des rappels J-1 + J-day pour chaque événement du calendrier de couple.
  /// Annule automatiquement les anciens rappels du calendrier avant de reprogrammer.
  Future<void> scheduleCalendarEventReminders(
      List<EventModel> events) async {
    if (!await isEnabled()) return;

    // Annuler tous les rappels calendrier existants
    for (int i = 0; i < _calMaxEvents; i++) {
      await _plugin.cancel(_calBase + i * 2);
      await _plugin.cancel(_calBase + i * 2 + 1);
    }

    final now = tz.TZDateTime.now(tz.local);
    int scheduled = 0;

    for (int i = 0; i < events.length && i < _calMaxEvents; i++) {
      final event = events[i];
      final eventDay = DateTime(
          event.date.year, event.date.month, event.date.day);

      // Ignorer les événements passés
      if (eventDay.isBefore(
          DateTime(now.year, now.month, now.day))) continue;

      // J-1 à 10h00
      final dayBefore = eventDay.subtract(const Duration(days: 1));
      final tzDayBefore = tz.TZDateTime.from(
          dayBefore.copyWith(hour: 10, minute: 0, second: 0, millisecond: 0),
          tz.local);
      if (tzDayBefore.isAfter(now)) {
        await _scheduleOnce(
          id: _calBase + i * 2,
          scheduledDate: tzDayBefore,
          title: '📅 Rappel : « ${event.title} » demain',
          body: event.description.isNotEmpty
              ? event.description
              : 'Un moment à deux prévu pour demain 💕',
          channelId: _chReminders,
          payload: 'calendar:${event.id}',
        );
      }

      // Jour J à 8h30
      final tzDayOf = tz.TZDateTime.from(
          eventDay.copyWith(hour: 8, minute: 30, second: 0, millisecond: 0),
          tz.local);
      if (tzDayOf.isAfter(now)) {
        await _scheduleOnce(
          id: _calBase + i * 2 + 1,
          scheduledDate: tzDayOf,
          title: '💕 Aujourd\'hui : « ${event.title} »',
          body: event.description.isNotEmpty
              ? event.description
              : 'Profitez pleinement de ce moment ensemble 🌟',
          channelId: _chReminders,
          payload: 'calendar:${event.id}',
        );
      }
      scheduled++;
    }

    debugPrint('📅 $scheduled événements du calendrier programmés');
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS INTERNES – SHOW & SCHEDULE
  // ═══════════════════════════════════════════════════════════════

  /// Affiche une notification immédiate.
  Future<void> _show({
    required int    id,
    required String channelId,
    required String title,
    required String body,
    String?         payload,
    Color           color = _colorPrimary,
  }) async {
    try {
      if (!_initialized) await initialize();
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelNames[channelId] ?? channelId,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: color,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Erreur _show ($id): $e');
    }
  }

  /// Notification programmée à une date et heure précise (une seule fois).
  Future<void> _scheduleOnce({
    required int            id,
    required tz.TZDateTime  scheduledDate,
    required String         title,
    required String         body,
    required String         channelId,
    String?                 payload,
    Color                   color = _colorPrimary,
  }) async {
    try {
      if (!_initialized) await initialize();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelNames[channelId] ?? channelId,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: color,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Erreur _scheduleOnce ($id): $e');
    }
  }

  /// Notification annuelle récurrente (même jour/mois chaque année).
  Future<void> _scheduleYearly({
    required int    id,
    required int    month,
    required int    day,
    required int    hour,
    required int    minute,
    required String title,
    required String body,
    required String channelId,
    String?         payload,
    Color           color = _colorPrimary,
  }) async {
    // Garde-fou : day hors plage (ex. 0 si date - 3 franchit le mois)
    if (day < 1 || day > 31) return;
    try {
      if (!_initialized) await initialize();
      final scheduledDate = _nextYearlyOccurrence(month, day, hour, minute);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelNames[channelId] ?? channelId,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: color,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: payload,
      );
      debugPrint('📅 Rappel annuel ($id): $title → $scheduledDate');
    } catch (e) {
      debugPrint('❌ Erreur _scheduleYearly ($id/$month-$day): $e');
    }
  }

  /// Notification annuelle à date variable (Fetë des Mères, Fête des Pères…).
  Future<void> _scheduleVariableYearly({
    required int                     id,
    required DateTime Function(int)  dateResolver,
    required int                     hour,
    required int                     minute,
    required String                  title,
    required String                  body,
    required String                  channelId,
    Color                            color = _colorPrimary,
  }) async {
    try {
      if (!_initialized) await initialize();
      final now = DateTime.now();
      DateTime target = dateResolver(now.year)
          .copyWith(hour: hour, minute: minute, second: 0, millisecond: 0);
      if (target.isBefore(now)) {
        target = dateResolver(now.year + 1)
            .copyWith(hour: hour, minute: minute, second: 0, millisecond: 0);
      }
      final scheduledDate = tz.TZDateTime.from(target, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelNames[channelId] ?? channelId,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: color,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('📅 Rappel variable ($id): $title → $scheduledDate');
    } catch (e) {
      debugPrint('❌ Erreur _scheduleVariableYearly ($id): $e');
    }
  }

  /// Notification hebdomadaire récurrente (même jour de la semaine).
  Future<void> _scheduleWeekly({
    required int    id,
    required int    weekday,   // DateTime.monday … DateTime.sunday
    required int    hour,
    required int    minute,
    required String title,
    required String body,
    required String channelId,
    Color           color = _colorPrimary,
  }) async {
    try {
      if (!_initialized) await initialize();
      final scheduledDate = _nextWeekday(weekday, hour, minute);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelNames[channelId] ?? channelId,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: color,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      debugPrint('📅 Rappel hebdo ($id): $title (wd=$weekday ${hour}h${minute.toString().padLeft(2, '0')})');
    } catch (e) {
      debugPrint('❌ Erreur _scheduleWeekly ($id): $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCUL DES DATES
  // ═══════════════════════════════════════════════════════════════

  tz.TZDateTime _nextYearlyOccurrence(
      int month, int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(tz.local, now.year, month, day, hour, minute);
    if (dt.isBefore(now)) {
      dt = tz.TZDateTime(tz.local, now.year + 1, month, day, hour, minute);
    }
    return dt;
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    int daysUntil = (weekday - now.weekday + 7) % 7;
    if (daysUntil == 0 && dt.isBefore(now)) daysUntil = 7;
    return dt.add(Duration(days: daysUntil));
  }

  /// Dernier dimanche de mai → Fête des Mères (France/Belgique/Suisse/Afrique)
  DateTime _mothersDay(int year) {
    final lastMay = DateTime(year, 5, 31);
    return lastMay.subtract(Duration(days: lastMay.weekday % 7));
  }

  /// 3ème dimanche de juin → Fête des Pères
  DateTime _fathersDay(int year) {
    final firstJune = DateTime(year, 6, 1);
    final daysToSunday = (7 - firstJune.weekday) % 7;
    return firstJune
        .add(Duration(days: daysToSunday))
        .add(const Duration(days: 14));
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITAIRES
  // ═══════════════════════════════════════════════════════════════

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('🗑️ Toutes les notifications Collabo annulées');
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<List<PendingNotificationRequest>> getPending() =>
      _plugin.pendingNotificationRequests();

  Future<Map<String, dynamic>> getStats() async {
    final pending = await getPending();
    return {
      'pendingCount':  pending.length,
      'enabled':       await isEnabled(),
      'hasPermissions': await hasPermissions(),
      'systemEnabled': await isSystemEnabled(),
      'pendingIds':    pending.map((n) => n.id).toList(),
    };
  }

  Future<void> debug() async {
    debugPrint('=== DEBUG CollaboNotificationService ===');
    final stats = await getStats();
    debugPrint('📊 Stats: $stats');
    final now = tz.TZDateTime.now(tz.local);
    debugPrint('🕐 TZDateTime locale: $now | tz: ${tz.local.name}');
    debugPrint('=== FIN DEBUG ===');
  }

  // ═══════════════════════════════════════════════════════════════
  // TEST
  // ═══════════════════════════════════════════════════════════════

  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    await _show(
      id: _idTest,
      channelId: _chMessages,
      title: '✅ Collabo – Notifications actives !',
      body: 'Vos rappels amoureux sont bien configurés 💕',
    );
  }

  Future<void> scheduleTestIn({int seconds = 5}) async {
    if (!_initialized) await initialize();
    final dt =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _scheduleOnce(
      id: _idTest + 1,
      scheduledDate: dt,
      title: '⏰ Test programmé Collabo',
      body: 'Cette notification était prévue dans $seconds secondes ! ✅',
      channelId: _chReminders,
    );
    debugPrint('⏰ Test programmé pour: $dt');
  }
}
