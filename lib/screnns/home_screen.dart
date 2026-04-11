import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import '../services/couple_service.dart';
import '../services/conversation_service.dart';
import '../utils/app_theme.dart';
import 'game_modes_screen.dart';
import 'calendar_screen.dart';
import 'gallery_screen.dart';
import 'history_screen.dart';
import 'notre_histoire_screen.dart';
import 'conversations_list_screen.dart';
import 'profile_screen.dart';
import 'feed_screen.dart';
import 'call_screen.dart';
import '../services/call_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  int _chatUnreadCount = 0;
  int _pendingInviteCount = 0;
  int _pendingGameCount = 0;

  // Valeurs précédentes pour détecter les augmentations
  int _prevChatUnread   = 0;
  int _prevInviteCount  = 0;
  int _prevGameCount    = 0;
  String? _lastScheduledCoupleId;

  StreamSubscription<UserProfile?>? _profileSub;
  StreamSubscription<int>? _chatUnreadSub;
  StreamSubscription<List<CoupleRequest>>? _inviteSub;
  StreamSubscription<int>? _gameInviteSub;
  StreamSubscription<IncomingCallData?>? _incomingCallSub;
  final _shownCallIds = <String>{};

  // Color theme state — shown in sheet before game
  Color _primaryColor = const Color(0xFFD0216E);
  Color _accentColor = const Color(0xFF7C3AED);

  static const _colorOptions = [
    {'name': 'Rose',   'color': Color(0xFFD0216E)},
    {'name': 'Rouge',  'color': Colors.red},
    {'name': 'Violet', 'color': Color(0xFF7C3AED)},
    {'name': 'Bleu',   'color': Colors.blue},
    {'name': 'Vert',   'color': Color(0xFF10B981)},
    {'name': 'Orange', 'color': Colors.orange},
    {'name': 'Corail', 'color': Color(0xFFFF6B6B)},
  ];

  @override
  void initState() {
    super.initState();
    CoupleService.ensureProfileExists();
    _checkPendingWarning();
    _inviteSub = CoupleService.pendingInvitesStream().listen((list) {
      if (!mounted) return;
      final n = list.length;
      if (n > _prevInviteCount) {
        // Nouvelle demande reçue → notification
        final latest = list.isNotEmpty ? list.last : null;
        if (latest != null) {
          CollaboNotificationService()
              .showCoupleRequest(fromName: latest.fromName);
        }
      }
      _prevInviteCount = n;
      setState(() => _pendingInviteCount = n);
    });
    // Listen to profile: game invite badge + romantic reminders scheduling
    _profileSub = CoupleService.myProfileStream().listen((profile) {
      final coupleId = profile?.coupleId;
      _gameInviteSub?.cancel();
      if (coupleId != null) {
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        _gameInviteSub =
            RemoteGamesService.pendingRemoteGameStream(coupleId, myUid)
                .listen((n) {
          if (!mounted) return;
          if (n > _prevGameCount) {
            CollaboNotificationService().showGameInvite(
              partnerName: profile?.pseudo ?? profile?.displayName,
            );
          }
          _prevGameCount = n;
          setState(() => _pendingGameCount = n);
        });
        // Schedule romantic reminders once per coupleId load
        if (_lastScheduledCoupleId != coupleId) {
          _lastScheduledCoupleId = coupleId;
          CollaboNotificationService().scheduleRomanticReminders(
            partnerName:      profile?.pseudo ?? profile?.displayName,
            anniversaryDate:  profile?.anniversaryDate,
            partnerBirthday:  profile?.partnerUid != null ? null : null,
          );
        }
      } else {
        if (mounted) setState(() => _pendingGameCount = 0);
      }
    });
    _chatUnreadSub = ConversationService.totalUnreadStream().listen((n) {
      if (!mounted) return;
      // Notifier uniquement si l'utilisateur n'est pas déjà sur l'onglet Chat
      if (n > _prevChatUnread && _currentNavIndex != 2) {
        CollaboNotificationService().showNewMessage();
      }
      _prevChatUnread = n;
      setState(() => _chatUnreadCount = n);
    });
    _listenIncomingCalls();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _chatUnreadSub?.cancel();
    _inviteSub?.cancel();
    _gameInviteSub?.cancel();
    _incomingCallSub?.cancel();
    super.dispose();
  }

  void _navigateToTab(int index) => setState(() => _currentNavIndex = index);

  Future<void> _checkPendingWarning() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final warning = doc.data()?['pendingWarning'] as String?;
    if (warning == null || warning.isEmpty) return;
    // Effacer l'avertissement pour ne pas le réafficher
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'pendingWarning': FieldValue.delete()});
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 26),
            const SizedBox(width: 10),
            const Text('Avertissement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(warning, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );
  }

  void _listenIncomingCalls() {
    _incomingCallSub = CallService.incomingCallStream().listen((call) {
      if (!mounted || call == null) return;
      if (_shownCallIds.contains(call.callId)) return;
      _shownCallIds.add(call.callId);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallPage(
            callId: call.callId,
            callerName: call.callerName,
            callerAvatar: call.callerAvatar,
            isVideo: call.isVideo,
            conversationId: call.conversationId,
          ),
        ),
      );
    });
  }

  /// Opens a bottom sheet for color selection, then pushes GameModesScreen.
  void _startGame(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => _ColorPickerSheet(
        primaryColor: _primaryColor,
        accentColor: _accentColor,
        colorOptions: _colorOptions,
        onPrimaryChanged: (c) => setState(() => _primaryColor = c),
        onAccentChanged: (c) => setState(() => _accentColor = c),
        onPlay: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameModesScreen(
                primaryColor: _primaryColor,
                accentColor: _accentColor,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeContent(
        onNavigate: _navigateToTab,
        onPlay: () => _startGame(context),
      ),
      const FeedScreen(),
      const ConversationsListScreen(),
      GameModesScreen(primaryColor: _primaryColor, accentColor: _accentColor),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(child: pages[_currentNavIndex]),
          _BottomNav(
            currentIndex: _currentNavIndex,
            onTap: _navigateToTab,
            badges: [0, 0, _chatUnreadCount, _pendingGameCount, _pendingInviteCount],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Color picker bottom sheet
// ─────────────────────────────────────────────

class _ColorPickerSheet extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  final List<Map<String, dynamic>> colorOptions;
  final ValueChanged<Color> onPrimaryChanged;
  final ValueChanged<Color> onAccentChanged;
  final VoidCallback onPlay;

  const _ColorPickerSheet({
    required this.primaryColor,
    required this.accentColor,
    required this.colorOptions,
    required this.onPrimaryChanged,
    required this.onAccentChanged,
    required this.onPlay,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _primary;
  late Color _accent;

  @override
  void initState() {
    super.initState();
    _primary = widget.primaryColor;
    _accent = widget.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          // preview swatch
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_primary, _accent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Personnalisez votre partie',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text('Choisissez vos couleurs avant de commencer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
          const SizedBox(height: 24),

          _ColorRow(
            label: 'Couleur principale',
            selected: _primary,
            options: widget.colorOptions,
            onChanged: (c) {
              setState(() => _primary = c);
              widget.onPrimaryChanged(c);
            },
          ),
          const SizedBox(height: 18),
          _ColorRow(
            label: 'Couleur accent',
            selected: _accent,
            options: widget.colorOptions,
            onChanged: (c) {
              setState(() => _accent = c);
              widget.onAccentChanged(c);
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                elevation: 0,
              ),
              child: const Text('Choisir un mode de jeu',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color selected;
  final List<Map<String, dynamic>> options;
  final ValueChanged<Color> onChanged;

  const _ColorRow({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: options.map((opt) {
            final color = opt['color'] as Color;
            final isSelected = color.toARGB32() == selected.toARGB32();
            return GestureDetector(
              onTap: () => onChanged(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 38 : 32,
                height: isSelected ? 38 : 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Home Content
// ─────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback onPlay;

  const _HomeContent({required this.onNavigate, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    return StreamBuilder<UserProfile?>(
      stream: CoupleService.myProfileStream(),
      builder: (ctx, snap) {
        final profile = snap.data;
        final firstName = profile?.pseudo?.isNotEmpty == true
            ? profile!.pseudo!
            : user?.displayName?.split(' ').first ?? 'vous';
        final avatarData = profile?.avatarData;
        final hasCustomPhoto = avatarData != null && avatarData.isNotEmpty;
        final avatarUrl = hasCustomPhoto
            ? null
            : (profile?.avatarUrl ?? user?.photoURL);
        final initial = (profile?.pseudo?.isNotEmpty == true
                ? profile!.pseudo![0]
                : user?.displayName?.isNotEmpty == true
                    ? user!.displayName![0]
                    : 'C')
            .toUpperCase();
        final coupled = profile?.partnerUid != null;

        return CustomScrollView(
      slivers: [
        // ── App Bar ──────────────────────────────────────────────
        SliverAppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          pinned: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/cologo.png',
                    width: 28, height: 28, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text('Collabo',
                  style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => onNavigate(3),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: hasCustomPhoto
                      ? MemoryImage(base64Decode(avatarData!)) as ImageProvider
                      : avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                  child: !hasCustomPhoto && avatarUrl == null
                      ? Text(
                          initial,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14))
                      : null,
                ),
              ),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ────────────────────────────────────
                _GreetingSection(firstName: firstName, coupled: coupled),
                const SizedBox(height: 24),

                // ── Play CTA ─────────────────────────────────────
                _PlayButton(onPlay: onPlay),
                const SizedBox(height: 28),

                // ── Section title ────────────────────────────────
                const Text('Votre espace',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 14),

                // ── Feature grid ─────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.auto_stories_rounded,
                        iconColor: AppColors.accent,
                        bgColor: AppColors.accentLight,
                        title: 'Notre Histoire',
                        subtitle: 'Anecdotes & souvenirs',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotreHistoireScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.photo_library_rounded,
                        iconColor: const Color(0xFF0EA5E9),
                        bgColor: const Color(0xFFE0F2FE),
                        title: 'Galerie',
                        subtitle: 'Photos clés',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GalleryScreen(coupleId: profile?.coupleId)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.calendar_month_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFEDE9FE),
                        title: 'Calendrier',
                        subtitle: 'Vos moments',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CalendarScreen(coupleId: profile?.coupleId)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _FeatureCard(
                        icon: Icons.history_rounded,
                        iconColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFFD1FAE5),
                        title: 'Historique',
                        subtitle: 'Vos scores & résultats',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Greeting section
// ─────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  final String firstName;
  final bool coupled;

  const _GreetingSection({required this.firstName, required this.coupled});

  @override
  Widget build(BuildContext context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Bonjour, $firstName 👋',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coupled
                              ? 'Prêts à jouer ensemble ?'
                              : 'Invitez votre partenaire pour jouer',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/cologo.png',
                        width: 52, height: 52, fit: BoxFit.cover),
                  ),
                ],
              ),
              if (!coupled) ...[
                const SizedBox(height: 14),
                Center(
                  child: Image.asset(
                    'assets/couple_solo.webp',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    // Navigate to profile tab to link account
                    final homeState = context
                        .findAncestorStateOfType<_HomeScreenState>();
                    homeState?._navigateToTab(3);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_rounded,
                            color: AppColors.primary, size: 16),
                        SizedBox(width: 8),
                        Text('Lier mon compte partenaire',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: AppColors.primary, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
  }
}

// ─────────────────────────────────────────────
// Play CTA button
// ─────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final VoidCallback onPlay;
  const _PlayButton({required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Image.asset('assets/couple_game.webp', width: 72, height: 72),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jouer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text('Une partie ensemble',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Feature card
// ─────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMedium)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// Chat tab wrapper (stream-aware)
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> badges;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    this.badges = const [0, 0, 0, 0],
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'ACCUEIL'},
      {'icon': Icons.people_rounded, 'label': 'FEED'},
      {'icon': Icons.chat_bubble_rounded, 'label': 'CHAT'},
      {'icon': Icons.extension_rounded, 'label': 'JEUX'},
      {'icon': Icons.person_rounded, 'label': 'PROFIL'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final isActive = i == currentIndex;
            final hasBadge =
                !isActive && i < badges.length && badges[i] > 0;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 18 : 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(items[i]['icon'] as IconData,
                            color: isActive
                                ? Colors.white
                                : AppColors.textMedium,
                            size: 22),
                        if (hasBadge)
                          Positioned(
                            top: -3,
                            right: -5,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Text(items[i]['label'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
