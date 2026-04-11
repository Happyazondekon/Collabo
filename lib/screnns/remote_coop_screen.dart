import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../utils/app_theme.dart';
import '../services/couple_service.dart';
import '../services/local_storage_service.dart';
import '../models/game_session_model.dart';
import '../Data/couple_words.dart';

/// Remote Cooperative:
/// - One player is the "Voyant" (sees the word, describes verbally)
/// - The other is the "Devineur" (types the guess)
/// - Word stored in Firestore; voyant's UI shows it, devineur's UI hides it.
class RemoteCoopScreen extends StatefulWidget {
  final String coupleId;
  final String myUid;
  final String partnerUid;
  final String myName;
  final String partnerName;
  final List<String> words;

  const RemoteCoopScreen({
    super.key,
    required this.coupleId,
    required this.myUid,
    required this.partnerUid,
    required this.myName,
    required this.partnerName,
    required this.words,
  });

  @override
  State<RemoteCoopScreen> createState() => _RemoteCoopScreenState();
}

class _RemoteCoopScreenState extends State<RemoteCoopScreen> {
  StreamSubscription<RemoteCoopSession?>? _sub;
  RemoteCoopSession? _session;
  bool _initialized = false;
  bool _loading = false;
  bool _sessionSaved = false;

  late final List<String> _wordPool =
      widget.words.isEmpty ? coupleWords : widget.words;
  final List<String> _usedWords = [];
  final Random _random = Random();

  // Devineur local state
  final TextEditingController _guessCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _feedback = '';
  bool _feedbackPositive = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sub =
        RemoteGamesService.remoteCoopStream(widget.coupleId).listen(_onSession);
  }

  void _onSession(RemoteCoopSession? session) {
    if (!mounted) return;
    _initialized = true;
    setState(() => _session = session);

    if (session == null) return;

    // Voyant: when pendingNewWord is true, auto-pick the next word
    if (session.pendingNewWord &&
        session.status != 'finished' &&
        session.voyantUid == widget.myUid) {
      _voyantPickNextWord();
    }
  }

  String _pickWord() {
    final available =
        _wordPool.where((w) => !_usedWords.contains(w)).toList();
    if (available.isEmpty) _usedWords.clear();
    final pool =
        _wordPool.where((w) => !_usedWords.contains(w)).toList();
    final word = pool[_random.nextInt(pool.length)];
    _usedWords.add(word);
    return word;
  }

  Future<void> _startAsVoyant() async {
    setState(() => _loading = true);
    final firstWord = _pickWord();
    await RemoteGamesService.startRemoteCoop(
      coupleId: widget.coupleId,
      voyantUid: widget.myUid,
      devineurUid: widget.partnerUid,
      firstWord: firstWord,
    );
    setState(() => _loading = false);
  }

  Future<void> _voyantPickNextWord() async {
    final newWord = _pickWord();
    await RemoteGamesService.updateCoopWord(
        coupleId: widget.coupleId, newWord: newWord);
  }

  Future<void> _submitGuess() async {
    final guess = _guessCtrl.text.trim();
    if (guess.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _feedback = '';
    });
    _guessCtrl.clear();
    _focusNode.requestFocus();

    final correct = await RemoteGamesService.submitCoopGuess(
      coupleId: widget.coupleId,
      guess: guess,
    );

    if (mounted) {
      setState(() {
        _submitting = false;
        _feedback =
            correct ? 'Bravo ! +5 pts ✨' : 'Pas tout à fait… Réessaie !';
        _feedbackPositive = correct;
      });
    }
  }

  Future<void> _quit() async {
    await RemoteGamesService.deleteRemoteCoop(widget.coupleId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _guessCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // No session yet → show lobby (role selection)
    if (_session == null) {
      return _CoopLobbyView(
        myName: widget.myName,
        partnerName: widget.partnerName,
        loading: _loading,
        onStartAsVoyant: _startAsVoyant,
        onCancel: () => Navigator.pop(context),
      );
    }

    // Finished
    if (_session!.status == 'finished') {
      if (!_sessionSaved) {
        _sessionSaved = true;
        LocalStorageService().saveSession(GameSessionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          mode: 'cooperatif',
          teamScore: _session!.teamScore,
          playedAt: DateTime.now(),
          wordsGuessed: _session!.wordsGuessed,
        ));
      }
      return _CoopResultView(
        teamScore: _session!.teamScore,
        wordsGuessed: _session!.wordsGuessed,
        onPlayAgain: () async {
          await RemoteGamesService.deleteRemoteCoop(widget.coupleId);
          if (mounted) Navigator.pop(context);
        },
      );
    }

    final isVoyant = _session!.voyantUid == widget.myUid;

    if (isVoyant) {
      return _VoyantView(
        session: _session!,
        myName: widget.myName,
        partnerName: widget.partnerName,
        onQuit: _quit,
      );
    } else {
      return _DevineurView(
        session: _session!,
        myName: widget.myName,
        partnerName: widget.partnerName,
        guessCtrl: _guessCtrl,
        focusNode: _focusNode,
        feedback: _feedback,
        feedbackPositive: _feedbackPositive,
        submitting: _submitting,
        onSubmit: _submitGuess,
        onQuit: _quit,
      );
    }
  }
}

// ─── Lobby ────────────────────────────────────────────────────────

class _CoopLobbyView extends StatelessWidget {
  final String myName;
  final String partnerName;
  final bool loading;
  final VoidCallback onStartAsVoyant;
  final VoidCallback onCancel;

  const _CoopLobbyView({
    required this.myName,
    required this.partnerName,
    required this.loading,
    required this.onStartAsVoyant,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
          onPressed: onCancel,
        ),
        title: const Text('Coopératif — À distance',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.cooperativeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handshake_rounded,
                      size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choisissez votre rôle',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le Voyant voit le mot et le décrit oralement.\nLe Devineur tape sa réponse.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.5),
              ),
              const Spacer(),
              // Role explanation cards
              _RoleCard(
                icon: Icons.visibility_rounded,
                title: 'Voyant',
                description:
                    'Vous voyez le mot,\nvous le décrivez à voix haute.',
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.keyboard_rounded,
                title: 'Devineur',
                description:
                    'Vous écoutez la description\net tapez votre réponse.',
                color: AppColors.accent,
              ),
              const Spacer(),
              if (loading)
                const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
              else ...[
                ElevatedButton.icon(
                  onPressed: onStartAsVoyant,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Je suis le Voyant',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.keyboard_rounded,
                      color: AppColors.accent),
                  label: const Text(
                    'Je suis le Devineur\n(attendre que mon partenaire démarre)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Voyant view ──────────────────────────────────────────────────

class _VoyantView extends StatelessWidget {
  final RemoteCoopSession session;
  final String myName;
  final String partnerName;
  final VoidCallback onQuit;

  const _VoyantView({
    required this.session,
    required this.myName,
    required this.partnerName,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = session.pendingNewWord || session.currentWord.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textDark),
          onPressed: onQuit,
        ),
        title: Text('Votre rôle : Voyant',
            style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _TeamScoreBar(
                  teamScore: session.teamScore,
                  targetScore: session.targetScore),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: waiting
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: AppColors.primary),
                            const SizedBox(height: 16),
                            const Text('Préparation du prochain mot…',
                                style: TextStyle(
                                    color: AppColors.textMedium,
                                    fontSize: 14)),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_rounded,
                                      size: 16, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text('Le mot à faire deviner',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              session.currentWord.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '${partnerName} est en train de deviner…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMedium),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Décrivez ce mot à voix haute\nsans le prononcer directement.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textLight,
                                  height: 1.5),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Devineur view ────────────────────────────────────────────────

class _DevineurView extends StatelessWidget {
  final RemoteCoopSession session;
  final String myName;
  final String partnerName;
  final TextEditingController guessCtrl;
  final FocusNode focusNode;
  final String feedback;
  final bool feedbackPositive;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onQuit;

  const _DevineurView({
    required this.session,
    required this.myName,
    required this.partnerName,
    required this.guessCtrl,
    required this.focusNode,
    required this.feedback,
    required this.feedbackPositive,
    required this.submitting,
    required this.onSubmit,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = session.pendingNewWord || session.currentWord.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textDark),
          onPressed: onQuit,
        ),
        title: const Text('Votre rôle : Devineur',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _TeamScoreBar(
                  teamScore: session.teamScore,
                  targetScore: session.targetScore),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: waiting
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: AppColors.accent),
                            const SizedBox(height: 16),
                            Text(
                              '${partnerName} choisit le prochain mot…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textMedium,
                                  fontSize: 14),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hearing_rounded,
                                      size: 16, color: AppColors.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${partnerName} vous décrit un mot…',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (feedback.isNotEmpty)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  feedback,
                                  key: ValueKey(feedback),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: feedbackPositive
                                          ? Colors.green.shade600
                                          : Colors.red.shade400),
                                ),
                              ),
                            const SizedBox(height: 24),
                            const Text(
                              'Écoutez votre partenaire\net tapez le mot qu\'il décrit.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMedium,
                                  height: 1.5),
                            ),
                          ],
                        ),
                ),
              ),
              if (!waiting) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: guessCtrl,
                        focusNode: focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onSubmit(),
                        enabled: !submitting,
                        decoration: InputDecoration(
                          hintText: 'Votre réponse…',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: submitting ? null : onSubmit,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: submitting
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded,
                                color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result ───────────────────────────────────────────────────────

class _CoopResultView extends StatelessWidget {
  final int teamScore;
  final int wordsGuessed;
  final VoidCallback onPlayAgain;

  const _CoopResultView({
    required this.teamScore,
    required this.wordsGuessed,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.handshake_rounded,
                    size: 80, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  'Objectif atteint ! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 16),
                Text(
                  '$teamScore points — $wordsGuessed mots devinés',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Rejouer',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour',
                      style: TextStyle(color: AppColors.textMedium)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamScoreBar extends StatelessWidget {
  final int teamScore;
  final int targetScore;
  const _TeamScoreBar({required this.teamScore, required this.targetScore});

  @override
  Widget build(BuildContext context) {
    final progress = (teamScore / targetScore).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Score équipe',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium)),
            Text('$teamScore / $targetScore pts',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.primarySoft,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
