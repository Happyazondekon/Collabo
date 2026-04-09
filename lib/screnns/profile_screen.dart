import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/achievement_model.dart';
import '../services/auth_service.dart';
import '../services/couple_service.dart';
import '../services/local_storage_service.dart';
import '../utils/app_theme.dart';
import 'achievements_screen.dart';
import 'whatsapp_upload_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, int> _stats = {};
  List<AchievementModel> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    CoupleService.ensureProfileExists();
  }

  Future<void> _loadLocalData() async {
    final stats = await LocalStorageService().getStats();
    final achievements = await LocalStorageService().getAchievements();
    if (mounted) {
      setState(() {
        _stats = stats;
        _achievements = achievements;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se déconnecter',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;

    return SafeArea(
      child: StreamBuilder<UserProfile?>(
        stream: CoupleService.myProfileStream(),
        builder: (ctx, profileSnap) {
          final profile = profileSnap.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                const Text('Profil',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 24),

                // Clean avatar card — no gradient
                _AvatarCard(user: user, profile: profile),
                const SizedBox(height: 16),

                // Pending invite banner (comes ABOVE partner section)
                _PendingInviteBanner(profile: profile),

                // Partner section
                _PartnerSection(profile: profile),
                const SizedBox(height: 16),

                // Dates card
                _DatesCard(profile: profile),
                const SizedBox(height: 16),

                // Stats
                _StatsRow(stats: _stats),
                const SizedBox(height: 20),

                // Achievements
                _SectionHeader(
                  title: 'Succès',
                  subtitle: '$unlocked/$total débloqués',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AchievementsScreen())),
                ),
                const SizedBox(height: 12),
                _AchievementsPreview(achievements: _achievements),
                const SizedBox(height: 20),

                // Actions
                _ActionTile(
                  icon: Icons.chat_rounded,
                  label: 'Importer une conversation WhatsApp',
                  subtitle: 'Personnalisez vos mots de jeu',
                  color: const Color(0xFF25D366),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WhatsAppUploadScreen())),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Se déconnecter',
                  subtitle: user?.email ?? '',
                  color: Colors.red.shade400,
                  onTap: () => _signOut(context),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Avatar Card ─────────────────────────────────────────────────────

class _AvatarCard extends StatefulWidget {
  final AppUser? user;
  final UserProfile? profile;
  const _AvatarCard({required this.user, required this.profile});

  @override
  State<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<_AvatarCard> {
  static const _avatarOptions = [
    'https://api.dicebear.com/7.x/avataaars/png?seed=Lily&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Max&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Sophie&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Felix&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Mia&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Tom&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Luna&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Zoe&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Noah&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Emma&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Alex&size=120',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Theo&size=120',
  ];

  void _showEditProfile(BuildContext context) {
    final pseudoCtrl = TextEditingController(
      text: widget.profile?.pseudo ?? widget.user?.displayName ?? '',
    );
    String? selectedUrl = widget.profile?.avatarUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Modifier le profil',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 20),
                const Text('Pseudo / Nom affiché',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium)),
                const SizedBox(height: 8),
                TextField(
                  controller: pseudoCtrl,
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: 'Votre pseudo…',
                    counterText: '',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.primary, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Choisir un avatar',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: _avatarOptions.map((url) {
                    final isSelected = selectedUrl == url;
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedUrl = url),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        color: AppColors.primarySoft,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary),
                                          ),
                                        ),
                                      ),
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primarySoft,
                              child: const Icon(Icons.person_rounded,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final pseudo = pseudoCtrl.text.trim();
                      await CoupleService.updateProfile(
                        pseudo: pseudo.isEmpty ? null : pseudo,
                        avatarUrl: selectedUrl,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Sauvegarder',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.profile?.avatarUrl ?? widget.user?.photoURL;
    final initial = (widget.profile?.pseudo?.isNotEmpty == true
            ? widget.profile!.pseudo![0]
            : widget.user?.displayName?.isNotEmpty == true
                ? widget.user!.displayName![0]
                : widget.user?.email?.isNotEmpty == true
                    ? widget.user!.email![0]
                    : '?')
        .toUpperCase();
    final name = widget.profile?.pseudo?.isNotEmpty == true
        ? widget.profile!.pseudo!
        : widget.user?.displayName?.isNotEmpty == true
            ? widget.user!.displayName!
            : 'Joueur';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primarySoft,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(initial,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showEditProfile(context),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(widget.user?.email ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMedium)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Membre Collabo',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditProfile(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Modifier',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending invite banner ───────────────────────────────────────────

class _PendingInviteBanner extends StatelessWidget {
  final UserProfile? profile;
  const _PendingInviteBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile?.partnerUid != null) return const SizedBox.shrink();
    return StreamBuilder<List<CoupleRequest>>(
      stream: CoupleService.pendingInvitesStream(),
      builder: (ctx, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();
        final req = requests.first;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${req.fromName} vous invite !',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textDark)),
                    Text(req.fromEmail,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium)),
                  ],
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => CoupleService.acceptInvite(req),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Accepter',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => CoupleService.declineInvite(req.id),
                    child: const Text('Refuser',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Partner section ─────────────────────────────────────────────────

class _PartnerSection extends StatelessWidget {
  final UserProfile? profile;
  const _PartnerSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_border_rounded,
                  size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Mon partenaire',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          if (profile?.partnerUid != null)
            _PartnerLinked(profile: profile!)
          else
            _PartnerUnlinked(),
        ],
      ),
    );
  }
}

class _PartnerLinked extends StatefulWidget {
  final UserProfile profile;
  const _PartnerLinked({required this.profile});

  @override
  State<_PartnerLinked> createState() => _PartnerLinkedState();
}

class _PartnerLinkedState extends State<_PartnerLinked> {
  UserProfile? _partnerProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  Future<void> _loadPartner() async {
    final p =
        await CoupleService.getPartnerProfile(widget.profile.partnerUid!);
    if (mounted) setState(() { _partnerProfile = p; _loading = false; });
  }

  Future<void> _unlink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Délier ce compte ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Vous ne partagerez plus de données avec ce partenaire.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Délier'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CoupleService.unlinkPartner(
          widget.profile.partnerUid!, widget.profile.coupleId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)));
    }
    final name = _partnerProfile?.displayName ?? 'Partenaire';
    final email = _partnerProfile?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accentLight,
          backgroundImage: _partnerProfile?.avatarUrl != null
              ? NetworkImage(_partnerProfile!.avatarUrl!)
              : null,
          child: _partnerProfile?.avatarUrl == null
              ? Text(initial,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 16))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textDark)),
              Text(email,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20)),
          child: const Text('Connectés',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32))),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _unlink,
          child: const Icon(Icons.link_off_rounded,
              size: 18, color: AppColors.textLight),
        ),
      ],
    );
  }
}

class _PartnerUnlinked extends StatefulWidget {
  @override
  State<_PartnerUnlinked> createState() => _PartnerUnlinkedState();
}

class _PartnerUnlinkedState extends State<_PartnerUnlinked> {
  bool _showInput = false;
  final _emailCtrl = TextEditingController();
  String? _error;
  bool _sending = false;

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _sending = true; _error = null; });
    try {
      await CoupleService.sendInvite(email);
      if (mounted) {
        setState(() { _showInput = false; _sending = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation envoyée à $email !'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _sending = false; });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showInput) {
      return GestureDetector(
        onTap: () => setState(() => _showInput = true),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Inviter mon partenaire',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Email de votre partenaire',
            errorText: _error,
            prefixIcon: const Icon(Icons.email_outlined,
                color: AppColors.primary, size: 20),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () =>
                    setState(() { _showInput = false; _error = null; }),
                child: const Text('Annuler',
                    style: TextStyle(color: AppColors.textMedium)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text("Envoyer l'invitation",
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Dates card ──────────────────────────────────────────────────────

class _DatesCard extends StatelessWidget {
  final UserProfile? profile;
  const _DatesCard({required this.profile});

  Future<void> _pickDate(BuildContext context, DateTime? current, String label,
      Future<void> Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(DateTime.now().year - 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: label,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) await onPicked(picked);
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Ajouter';
    const m = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Dates importantes',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          _DateRow(
            icon: Icons.favorite_rounded,
            iconColor: AppColors.primary,
            label: 'Anniversaire de couple',
            dateText: _fmt(profile?.anniversaryDate),
            isSet: profile?.anniversaryDate != null,
            onTap: () => _pickDate(
              context,
              profile?.anniversaryDate,
              'Anniversaire de couple',
              (d) => CoupleService.updateDates(anniversaryDate: d),
            ),
          ),
          const Divider(height: 20, color: Color(0xFFF0F0F0)),
          _DateRow(
            icon: Icons.cake_rounded,
            iconColor: AppColors.accent,
            label: 'Mon anniversaire',
            dateText: _fmt(profile?.birthday),
            isSet: profile?.birthday != null,
            onTap: () => _pickDate(
              context,
              profile?.birthday,
              'Mon anniversaire',
              (d) => CoupleService.updateDates(birthday: d),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String dateText;
  final bool isSet;
  final VoidCallback onTap;

  const _DateRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.dateText,
    required this.isSet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text(dateText,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isSet ? AppColors.textMedium : AppColors.primary)),
              ],
            ),
          ),
          Icon(
            isSet ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
            size: 16,
            color: AppColors.textLight,
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ───────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'label': 'Parties',
        'value': stats['gamesPlayed'] ?? 0,
        'icon': Icons.sports_esports_rounded,
        'color': AppColors.primary,
      },
      {
        'label': 'Mots',
        'value': stats['wordsGuessed'] ?? 0,
        'icon': Icons.text_fields_rounded,
        'color': AppColors.accent,
      },
      {
        'label': 'Série',
        'value': stats['streak'] ?? 0,
        'icon': Icons.local_fire_department_rounded,
        'color': Colors.orange,
      },
    ];

    return Row(
      children: items.map((item) {
        final color = item['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              children: [
                Icon(item['icon'] as IconData, color: color, size: 24),
                const SizedBox(height: 8),
                Text('${item['value']}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 2),
                Text(item['label'] as String,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionHeader(
      {required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Achievements preview ────────────────────────────────────────────

class _AchievementsPreview extends StatelessWidget {
  final List<AchievementModel> achievements;
  const _AchievementsPreview({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final preview = achievements.take(6).toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: preview.map((a) => _AchievementBadge(achievement: a)).toList(),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final AchievementModel achievement;
  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final color =
        achievement.isUnlocked ? achievement.color : Colors.grey.shade300;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: achievement.isUnlocked
            ? color.withValues(alpha: 0.12)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: achievement.isUnlocked
                ? color.withValues(alpha: 0.3)
                : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(achievement.icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                  fontSize: 9,
                  color: achievement.isUnlocked
                      ? AppColors.textDark
                      : Colors.grey.shade400,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Action tile ─────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textDark)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
