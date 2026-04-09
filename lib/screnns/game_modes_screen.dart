import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/app_theme.dart';
import '../services/couple_service.dart';
import 'game_screen.dart';
import 'cooperative_game_screen.dart';
import 'timed_game_screen.dart';
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

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 24),
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
