import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/app_theme.dart';
import '../services/couple_service.dart';
import '../services/local_storage_service.dart';
import 'game_screen.dart';
import 'cooperative_game_screen.dart';
import 'timed_game_screen.dart';
import 'whatsapp_upload_screen.dart';
import '../models/game_difficulty.dart';

class GameModesScreen extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;

  const GameModesScreen({
    super.key,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<GameModesScreen> createState() => _GameModesScreenState();
}

class _GameModesScreenState extends State<GameModesScreen> {
  StreamSubscription<UserProfile?>? _profileSub;
  String _player1Name = 'Joueur 1';
  String _player2Name = 'Joueur 2';
  List<String>? _customWords; // null = not loaded yet, [] = no words
  bool _loadingWords = true;

  @override
  void initState() {
    super.initState();
    _loadCustomWords();
    _profileSub = CoupleService.myProfileStream().listen((profile) async {
      if (!mounted) return;
      final name1 = profile?.pseudo?.isNotEmpty == true
          ? profile!.pseudo!
          : profile?.displayName ?? 'Joueur 1';
      String name2 = 'Joueur 2';
      if (profile?.partnerUid != null) {
        final partner =
            await CoupleService.getPartnerProfile(profile!.partnerUid!);
        name2 = partner?.pseudo?.isNotEmpty == true
            ? partner!.pseudo!
            : partner?.displayName ?? 'Joueur 2';
      }
      if (mounted) setState(() { _player1Name = name1; _player2Name = name2; });
    });
  }

  Future<void> _loadCustomWords() async {
    final words = await LocalStorageService().getCustomWords();
    if (mounted) setState(() { _customWords = words; _loadingWords = false; });
  }

  Future<void> _goToUpload() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const WhatsAppUploadScreen()));
    // Reload words when coming back
    _loadCustomWords();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingWords) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // No custom words yet → onboarding screen
    if (_customWords == null || _customWords!.isEmpty) {
      return _UploadPromptScreen(onUpload: _goToUpload);
    }

    final words = _customWords!;
    final modes = [
      _mode(
        title: 'Compétitif',
        description: 'Défiez votre partenaire et montrez qui est le plus agile.',
        icon: Icons.sports_kabaddi_rounded,
        gradient: AppColors.competitiveGradient,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => GameScreen(
            primaryColor: widget.primaryColor,
            accentColor: widget.accentColor,
            difficulty: GameDifficulty.normal,
            customWords: words,
            player1Name: _player1Name,
            player2Name: _player2Name,
          ),
        )),
      ),
      _mode(
        title: 'Coopératif',
        description: "L'union fait la force.\nTravaillez ensemble pour gagner.",
        icon: Icons.handshake_rounded,
        gradient: AppColors.cooperativeGradient,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CooperativeGameScreen(
            primaryColor: widget.primaryColor,
            accentColor: widget.accentColor,
            customWords: words,
          ),
        )),
      ),
      _mode(
        title: 'Contre-la-Montre',
        description: 'Rapide et intense.\nBattez le chrono avant la fin.',
        icon: Icons.timer_rounded,
        gradient: AppColors.timedGradient,
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TimedGameScreen(
            primaryColor: widget.primaryColor,
            accentColor: widget.accentColor,
            customWords: words,
          ),
        )),
      ),
      _mode(
        title: 'Personnalisé',
        description: 'Créez vos propres règles pour une session unique.',
        icon: Icons.tune_rounded,
        gradient: AppColors.customGradient,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bientôt disponible !'),
            behavior: SnackBarBehavior.floating,
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('Choisissez votre\naventure',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.2)),
            const SizedBox(height: 8),
            const Text('Découvrez différentes façons de jouer ensemble',
                style: TextStyle(fontSize: 14, color: AppColors.textMedium)),
            const SizedBox(height: 12),
            // Words badge + change button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 5),
                      Text('${words.length} mots importés',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _goToUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 14, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text('Changer',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: modes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _GameModeCard(mode: modes[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }

  Map<String, dynamic> _mode({
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) =>
      {
        'title': title,
        'description': description,
        'icon': icon,
        'gradient': gradient,
        'onTap': onTap,
      };
}

class _UploadPromptScreen extends StatelessWidget {
  final VoidCallback onUpload;
  const _UploadPromptScreen({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Illustration
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF25D366),
                        Color(0xFF128C7E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Colors.white, size: 52),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Jouez avec vos\npropres mots',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'Importez votre conversation WhatsApp pour que les jeux utilisent les mots que vous et votre partenaire utilisez réellement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMedium,
                    height: 1.5),
              ),
              const SizedBox(height: 12),
              // Steps
              const _StepTile(
                number: '1',
                text: 'Ouvrez WhatsApp → votre conversation',
              ),
              const _StepTile(
                number: '2',
                text: 'Menu ··· → "Exporter la discussion" → Sans média',
              ),
              const _StepTile(
                number: '3',
                text: 'Envoyez le fichier .txt sur votre téléphone',
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 22),
                label: const Text('Importer ma conversation',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                  shadowColor:
                      const Color(0xFF25D366).withValues(alpha: 0.4),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String text;
  const _StepTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
                color: Color(0xFF25D366), shape: BoxShape.circle),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                      height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  final Map<String, dynamic> mode;

  const _GameModeCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    final gradient = mode['gradient'] as List<Color>;
    return GestureDetector(
      onTap: mode['onTap'] as VoidCallback,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: gradient.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8))
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(mode['icon'] as IconData,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle),
                    child: Icon(mode['icon'] as IconData,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(mode['title'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(mode['description'] as String,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
