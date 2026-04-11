import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../utils/app_theme.dart';
import '../services/couple_service.dart';
import '../services/local_storage_service.dart';
import '../models/game_session_model.dart';
import '../Data/couple_words.dart';

class RemoteCompetitiveScreen extends StatefulWidget {
  final String coupleId;
  final String myUid;
  final String partnerUid;
  final String myName;
  final String partnerName;
  final List<String> words;

  const RemoteCompetitiveScreen({
    super.key,
    required this.coupleId,
    required this.myUid,
    required this.partnerUid,
    required this.myName,
    required this.partnerName,
    required this.words,
  });

  @override
  State<RemoteCompetitiveScreen> createState() =>
      _RemoteCompetitiveScreenState();
}

class _RemoteCompetitiveScreenState extends State<RemoteCompetitiveScreen> {
  static const _targetScore = 10;

  StreamSubscription<RemoteCompetitiveSession?>? _sub;
  RemoteCompetitiveSession? _session;
  bool _initialized = false;

  // Local game state
  int _myScore = 0;
  String _currentWord = '';
  String _hiddenWord = '';
  final TextEditingController _guessCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _usedWords = [];
  final Random _random = Random();
  String _feedback = '';
  bool _feedbackPositive = false;
  bool _gameStarted = false;
  bool _finishing = false;
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _sub = RemoteGamesService.remoteCompetitiveStream(widget.coupleId)
        .listen(_onSession);
  }

  void _onSession(RemoteCompetitiveSession? session) async {
    if (!mounted) return;

    if (!_initialized) {
      _initialized = true;
      if (session == null) {
        // I'm first — create session and wait
        await RemoteGamesService.createRemoteCompetitive(
          coupleId: widget.coupleId,
          myUid: widget.myUid,
          targetScore: _targetScore,
        );
        return;
      }
      if (session.status == 'waiting' &&
          session.player1Uid != widget.myUid &&
          session.player2Uid == null) {
        // Partner is waiting — join and start
        await RemoteGamesService.joinRemoteCompetitive(
          coupleId: widget.coupleId,
          myUid: widget.myUid,
        );
        return;
      }
    }

    setState(() => _session = session);

    if (session == null) return;

    // When game starts, begin local play
    if (session.status == 'playing' && !_gameStarted) {
      setState(() {
        _gameStarted = true;
        _myScore = session.scoreFor(widget.myUid);
      });
      _pickNewWord();
    }

    // Sync my local score from Firestore if needed (e.g. re-join)
    if (session.status == 'playing' && _gameStarted) {
      final firestoreScore = session.scoreFor(widget.myUid);
      if (firestoreScore > _myScore) {
        setState(() => _myScore = firestoreScore);
      }
    }
  }

  late List<String> _wordPool = widget.words.isEmpty ? coupleWords : widget.words;

  String _makeHidden(String word) {
    if (word.length <= 3) return '${word[0]}${'_' * (word.length - 1)}';
    final show = max(1, (word.length * 0.3).floor());
    final indices = <int>{0};
    while (indices.length < show + 1) {
      indices.add(_random.nextInt(word.length));
    }
    return word
        .split('')
        .asMap()
        .entries
        .map((e) => indices.contains(e.key) ? e.value : '_')
        .join();
  }

  void _pickNewWord() {
    final available =
        _wordPool.where((w) => !_usedWords.contains(w)).toList();
    if (available.isEmpty) {
      _usedWords.clear();
      _pickNewWord();
      return;
    }
    setState(() {
      _currentWord = available[_random.nextInt(available.length)];
      _hiddenWord = _makeHidden(_currentWord);
      _usedWords.add(_currentWord);
      _feedback = '';
    });
  }

  Future<void> _checkGuess() async {
    final guess = _guessCtrl.text.trim().toLowerCase();
    if (guess.isEmpty) return;
    _guessCtrl.clear();
    _focusNode.requestFocus();

    if (guess == _currentWord.toLowerCase()) {
      final newScore = _myScore + 2;
      setState(() {
        _myScore = newScore;
        _feedback = 'Bravo ! +2 pts ✨';
        _feedbackPositive = true;
      });
      if (_session != null) {
        await RemoteGamesService.updateCompetitiveScore(
          coupleId: widget.coupleId,
          myUid: widget.myUid,
          session: _session!,
          newScore: newScore,
        );
      }
      if (newScore >= _targetScore) return; // stream will show result
      Future.delayed(const Duration(milliseconds: 500), _pickNewWord);
    } else {
      setState(() {
        _feedback = 'Pas tout à fait… Réessaie !';
        _feedbackPositive = false;
      });
    }
  }

  void _skipWord() {
    _guessCtrl.clear();
    setState(() {
      _feedback = 'Mot passé';
      _feedbackPositive = false;
    });
    Future.delayed(const Duration(milliseconds: 300), _pickNewWord);
  }

  Future<void> _quit() async {
    await RemoteGamesService.deleteRemoteCompetitive(widget.coupleId);
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
    if (_session == null && !_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final status = _session?.status ?? 'waiting';

    if (status == 'waiting') return _WaitingView(partnerName: widget.partnerName, onCancel: _quit);

    if (status == 'finished') {
      final myScore = _session?.scoreFor(widget.myUid) ?? _myScore;
      final partnerScore = _session?.partnerScore(widget.myUid) ?? 0;
      final myWon = _session?.winner == widget.myUid;
      if (!_sessionSaved) {
        _sessionSaved = true;
        LocalStorageService().saveSession(GameSessionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          mode: 'competitif',
          player1Score: myScore,
          player2Score: partnerScore,
          winner: myWon ? 1 : 2,
          player1Name: widget.myName,
          player2Name: widget.partnerName,
          playedAt: DateTime.now(),
          wordsGuessed: myScore ~/ 2,
        ));
      }
      return _RemoteResultView(
        myName: widget.myName,
        partnerName: widget.partnerName,
        myScore: _session?.scoreFor(widget.myUid) ?? _myScore,
        partnerScore: _session?.partnerScore(widget.myUid) ?? 0,
        myWon: myWon,
        onPlayAgain: () async {
          await RemoteGamesService.deleteRemoteCompetitive(widget.coupleId);
          if (mounted) Navigator.pop(context);
        },
      );
    }

    // Playing
    final partnerScore = _session?.partnerScore(widget.myUid) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textDark),
          onPressed: _quit,
        ),
        title: const Text('Compétitif — À distance',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Score row
              Row(
                children: [
                  _RemoteScoreCard(
                    label: widget.myName,
                    score: _myScore,
                    target: _targetScore,
                    color: AppColors.primary,
                    isMe: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('vs',
                        style: TextStyle(
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ),
                  _RemoteScoreCard(
                    label: widget.partnerName,
                    score: partnerScore,
                    target: _targetScore,
                    color: AppColors.accent,
                    isMe: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bars
              _ProgressBar(
                  myValue: _myScore / _targetScore,
                  partnerValue: partnerScore / _targetScore),
              const SizedBox(height: 20),
              // Word card
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _hiddenWord,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 16),
                      if (_feedback.isNotEmpty)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _feedback,
                            key: ValueKey(_feedback),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _feedbackPositive
                                    ? Colors.green.shade600
                                    : Colors.red.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _guessCtrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _checkGuess(),
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
                  _ActionBtn(
                    icon: Icons.check_rounded,
                    color: AppColors.primary,
                    onTap: _checkGuess,
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.skip_next_rounded,
                    color: AppColors.textMedium,
                    onTap: _skipWord,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-views ────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  final String partnerName;
  final VoidCallback onCancel;
  const _WaitingView({required this.partnerName, required this.onCancel});

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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'En attente de $partnerName…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              const Text(
                'Demandez à votre partenaire d\'ouvrir\nle mode Compétitif sur son téléphone.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: AppColors.textMedium),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteResultView extends StatelessWidget {
  final String myName;
  final String partnerName;
  final int myScore;
  final int partnerScore;
  final bool myWon;
  final VoidCallback onPlayAgain;

  const _RemoteResultView({
    required this.myName,
    required this.partnerName,
    required this.myScore,
    required this.partnerScore,
    required this.myWon,
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
                Icon(
                  myWon ? Icons.emoji_events_rounded : Icons.sports_kabaddi_rounded,
                  size: 80,
                  color: myWon ? Colors.amber.shade600 : AppColors.textMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  myWon ? 'Vous avez gagné ! 🎉' : '${partnerName} a gagné !',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScoreChip(label: myName, score: myScore, highlight: myWon),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('vs',
                          style: TextStyle(
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w700)),
                    ),
                    _ScoreChip(
                        label: partnerName, score: partnerScore, highlight: !myWon),
                  ],
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

// ─── Widgets ──────────────────────────────────────────────────────

class _RemoteScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final int target;
  final Color color;
  final bool isMe;

  const _RemoteScoreCard({
    required this.label,
    required this.score,
    required this.target,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white70 : AppColors.textMedium),
            ),
            const SizedBox(height: 4),
            Text(
              '$score',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isMe ? Colors.white : color),
            ),
            Text(
              '/ $target pts',
              style: TextStyle(
                  fontSize: 11,
                  color: isMe
                      ? Colors.white54
                      : AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double myValue;
  final double partnerValue;
  const _ProgressBar({required this.myValue, required this.partnerValue});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Bar(value: myValue.clamp(0.0, 1.0), color: AppColors.primary),
        const SizedBox(height: 6),
        _Bar(value: partnerValue.clamp(0.0, 1.0), color: AppColors.accent),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  const _Bar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final bool highlight;
  const _ScoreChip(
      {required this.label, required this.score, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
                fontWeight:
                    highlight ? FontWeight.w700 : FontWeight.w400)),
        Text(
          '$score pts',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : AppColors.textLight),
        ),
      ],
    );
  }
}
