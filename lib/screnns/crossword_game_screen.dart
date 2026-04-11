import 'package:flutter/material.dart';
import '../services/couple_service.dart';
import '../utils/app_theme.dart';

class CrosswordGameScreen extends StatefulWidget {
  final String coupleId;
  final String myUid;
  final String partnerUid;
  final String myName;
  final String partnerName;

  const CrosswordGameScreen({
    super.key,
    required this.coupleId,
    required this.myUid,
    required this.partnerUid,
    required this.myName,
    required this.partnerName,
  });

  @override
  State<CrosswordGameScreen> createState() => _CrosswordGameScreenState();
}

class _CrosswordGameScreenState extends State<CrosswordGameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<CrosswordSession?>(
        stream: CoupleService.crosswordStream(widget.coupleId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final session = snap.data;

          // ── No active session ──
          if (session == null) {
            return _LobbyView(
              myName: widget.myName,
              partnerName: widget.partnerName,
              onPropose: () => CoupleService.startCrossword(
                coupleId: widget.coupleId,
                myUid: widget.myUid,
                partnerUid: widget.partnerUid,
              ),
              onBack: () => Navigator.pop(context),
            );
          }

          final isDefinisseur = session.definisseurUid == widget.myUid;

          // ── Setup phase ──
          if (session.status == 'setup') {
            if (isDefinisseur) {
              return _SetupView(
                coupleId: widget.coupleId,
                partnerName: widget.partnerName,
                onCancel: () => CoupleService.resetCrossword(widget.coupleId),
              );
            } else {
              return _WaitingView(
                partnerName: widget.partnerName,
                onBack: () => Navigator.pop(context),
              );
            }
          }

          // ── Playing ──
          if (session.status == 'playing') {
            if (isDefinisseur) {
              return _DefinisseurPlayingView(
                session: session,
                partnerName: widget.partnerName,
                onBack: () => Navigator.pop(context),
              );
            } else {
              return _DevineurView(
                session: session,
                coupleId: widget.coupleId,
                myUid: widget.myUid,
                onBack: () => Navigator.pop(context),
              );
            }
          }

          // ── Won / Lost ──
          return _ResultView(
            session: session,
            isDefinisseur: isDefinisseur,
            myName: widget.myName,
            partnerName: widget.partnerName,
            onReplay: () => CoupleService.swapCrosswordRoles(
              coupleId: widget.coupleId,
              newDefinisseurUid: widget.partnerUid, // swap
              newDevineurUid: widget.myUid,
            ),
            onQuit: () {
              CoupleService.resetCrossword(widget.coupleId);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

// ─── Lobby ─────────────────────────────────────────────────────────

class _LobbyView extends StatelessWidget {
  final String myName;
  final String partnerName;
  final VoidCallback onPropose;
  final VoidCallback onBack;

  const _LobbyView({
    required this.myName,
    required this.partnerName,
    required this.onPropose,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textDark, size: 20),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mots Croisés',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark)),
                    Text('Jeu à distance',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMedium)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.grid_on_rounded,
                        size: 50, color: AppColors.primary),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Jouez ensemble\nà distance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        height: 1.2),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Vous et $partnerName pouvez jouer même sans être au même endroit.\nUn propose un mot, l\'autre devine.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                        height: 1.6),
                  ),
                  const SizedBox(height: 40),
                  // How it works
                  _HowItWorksRow(
                      icon: Icons.lightbulb_outline_rounded,
                      text: 'Je propose un mot + indice'),
                  const SizedBox(height: 12),
                  _HowItWorksRow(
                      icon: Icons.psychology_rounded,
                      text: '$partnerName devine lettre par lettre'),
                  const SizedBox(height: 12),
                  _HowItWorksRow(
                      icon: Icons.swap_horiz_rounded,
                      text: 'On inverse les rôles après chaque manche'),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onPropose,
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text('Je propose un mot',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HowItWorksRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark, height: 1.4)),
        ),
      ],
    );
  }
}

// ─── Setup (definisseur fills word + clue) ─────────────────────────

class _SetupView extends StatefulWidget {
  final String coupleId;
  final String partnerName;
  final VoidCallback onCancel;

  const _SetupView({
    required this.coupleId,
    required this.partnerName,
    required this.onCancel,
  });

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _wordCtrl = TextEditingController();
  final _clueCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _wordCtrl.dispose();
    _clueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final word = _wordCtrl.text.trim();
    final clue = _clueCtrl.text.trim();
    if (word.isEmpty) {
      setState(() => _error = 'Entrez un mot');
      return;
    }
    if (word.contains(RegExp(r'[0-9]'))) {
      setState(() => _error = 'Le mot ne doit pas contenir de chiffres');
      return;
    }
    if (clue.isEmpty) {
      setState(() => _error = 'Entrez un indice pour aider votre partenaire');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    await CoupleService.submitCrosswordWord(
        coupleId: widget.coupleId, word: word, clue: clue);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textDark, size: 22),
                  onPressed: widget.onCancel,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Propose un mot',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                      Text('Votre partenaire ne verra que l\'indice',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMedium)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${widget.partnerName} ne verra pas ce mot — seulement votre indice.',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Le mot à deviner',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _wordCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Ex: CHOCOLAT',
                      hintStyle:
                          const TextStyle(color: AppColors.textLight),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  const Text('Indice',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clueCtrl,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ex: Ce qu\'on mange quand on est triste…',
                      hintStyle:
                          const TextStyle(color: AppColors.textLight),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Envoyer à mon partenaire',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Waiting (devineur waits for setup) ───────────────────────────

class _WaitingView extends StatelessWidget {
  final String partnerName;
  final VoidCallback onBack;

  const _WaitingView({required this.partnerName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textDark, size: 20),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                const Text('Mots Croisés',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 3),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '$partnerName prépare\nun mot pour toi…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cette page se mettra à jour\nautomatiquement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textMedium, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Definisseur watching the game ────────────────────────────────

class _DefinisseurPlayingView extends StatelessWidget {
  final CrosswordSession session;
  final String partnerName;
  final VoidCallback onBack;

  const _DefinisseurPlayingView({
    required this.session,
    required this.partnerName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final wrongCount = session.wrongGuesses.length;
    final remaining = session.maxAttempts - wrongCount;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textDark, size: 20),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mots Croisés',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: remaining <= 2
                        ? const Color(0xFFFFEEEE)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$remaining essai${remaining > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: remaining <= 2
                              ? Colors.red
                              : AppColors.primary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            color: AppColors.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$partnerName est en train de deviner…',
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Le mot (vous seul le voyez)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      session.word,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Indice envoyé',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(session.clue,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textDark)),
                  ),
                  const SizedBox(height: 24),
                  const Text('Progression',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium)),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      session.displayWord,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: 6),
                    ),
                  ),
                  if (session.wrongGuesses.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Mauvaises lettres',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: session.wrongGuesses
                          .map((l) => Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEEEE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(l,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red)),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Devineur guesses ─────────────────────────────────────────────

class _DevineurView extends StatelessWidget {
  final CrosswordSession session;
  final String coupleId;
  final String myUid;
  final VoidCallback onBack;

  const _DevineurView({
    required this.session,
    required this.coupleId,
    required this.myUid,
    required this.onBack,
  });

  static const _rows = [
    ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M'],
    ['W', 'X', 'C', 'V', 'B', 'N'],
  ];

  @override
  Widget build(BuildContext context) {
    final wrongCount = session.wrongGuesses.length;
    final remaining = session.maxAttempts - wrongCount;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textDark, size: 20),
                  onPressed: onBack,
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('À toi de deviner !',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: remaining <= 2
                        ? const Color(0xFFFFEEEE)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded,
                          size: 14,
                          color: remaining <= 2
                              ? Colors.red
                              : AppColors.primary),
                      const SizedBox(width: 4),
                      Text('$remaining',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: remaining <= 2
                                  ? Colors.red
                                  : AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Clue
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Indice',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMedium)),
                        const SizedBox(height: 6),
                        Text(session.clue,
                            style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textDark,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Word blanks
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _WordBlanks(session: session),
                  ),
                ),
                const Spacer(),
                // Keyboard
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Column(
                    children: _rows.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: row.map((letter) {
                            final guessed =
                                session.guessedLetters.contains(letter);
                            final isWrong =
                                session.wrongGuesses.contains(letter);
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: guessed
                                    ? null
                                    : () => CoupleService
                                        .guessCrosswordLetter(
                                            coupleId, letter),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  width: 30,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: guessed
                                        ? (isWrong
                                            ? const Color(0xFFFFEEEE)
                                            : AppColors.primarySoft)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(7),
                                    border: Border.all(
                                      color: guessed
                                          ? (isWrong
                                              ? Colors.red.withValues(
                                                  alpha: 0.3)
                                              : AppColors.primary
                                                  .withValues(alpha: 0.3))
                                          : const Color(0xFFE0D6F0),
                                    ),
                                    boxShadow: guessed
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: guessed
                                            ? (isWrong
                                                ? Colors.red
                                                : AppColors.primary)
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordBlanks extends StatelessWidget {
  final CrosswordSession session;
  const _WordBlanks({required this.session});

  @override
  Widget build(BuildContext context) {
    final letters = session.word.split('');
    final letterCount = letters.where((c) => c != ' ').length;

    // Adapt tile size to word length
    final double tileSize = letterCount <= 6
        ? 26
        : letterCount <= 9
            ? 22
            : letterCount <= 12
                ? 18
                : 14;
    final double fontSize = tileSize;
    final double hPadding = letterCount <= 6
        ? 4
        : letterCount <= 9
            ? 3
            : 2;

    Widget buildTile(String c) {
      if (c == ' ') return SizedBox(width: tileSize * 0.6);
      final revealed = session.guessedLetters.contains(c);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              revealed ? c : ' ',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: revealed ? AppColors.primary : AppColors.textDark,
              ),
            ),
            Container(
              width: tileSize,
              height: 3,
              decoration: BoxDecoration(
                color: revealed ? AppColors.primary : AppColors.textMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    // Split into lines of max 8 tiles each for very long words
    if (letterCount > 12) {
      final words = session.word.split(' ');
      final lines = <List<String>>[];
      var current = <String>[];
      for (final word in words) {
        final chars = word.split('');
        if (current.length + chars.length > 8 && current.isNotEmpty) {
          lines.add(current);
          current = [];
        }
        current.addAll(chars);
        current.add(' ');
      }
      if (current.isNotEmpty) lines.add(current);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: line.map(buildTile).toList(),
            ),
          );
        }).toList(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: letters.map(buildTile).toList(),
    );
  }
}

// ─── Result ────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final CrosswordSession session;
  final bool isDefinisseur;
  final String myName;
  final String partnerName;
  final VoidCallback onReplay;
  final VoidCallback onQuit;

  const _ResultView({
    required this.session,
    required this.isDefinisseur,
    required this.myName,
    required this.partnerName,
    required this.onReplay,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final isWon = session.status == 'won';
    final color = isWon ? AppColors.primary : Colors.orange;
    final icon = isWon ? Icons.celebration_rounded : Icons.sentiment_dissatisfied_rounded;
    final devineurName = isDefinisseur ? partnerName : myName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              isWon ? '$devineurName a trouvé !' : 'Pas trouvé cette fois',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  height: 1.2),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Le mot était',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMedium)),
                  const SizedBox(height: 6),
                  Text(session.word,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 4)),
                ],
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: Text(
                  isDefinisseur
                      ? '$partnerName propose maintenant'
                      : 'C\'est ton tour de proposer',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onQuit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMedium,
                  side: const BorderSide(color: Color(0xFFE0D6F0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Quitter',
                    style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
