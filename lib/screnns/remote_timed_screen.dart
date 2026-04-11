import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../utils/app_theme.dart';
import '../services/couple_service.dart';
import '../services/local_storage_service.dart';
import '../models/game_session_model.dart';
import '../Data/couple_words.dart';

/// Remote Timed: both players race the same 60s timer simultaneously.
/// Server timestamp ensures synchronization.
/// Scores are synced in real-time; final comparison shown at the end.
class RemoteTimedScreen extends StatefulWidget {
  final String coupleId;
  final String myUid;
  final String partnerUid;
  final String myName;
  final String partnerName;
  final List<String> words;

  const RemoteTimedScreen({
    super.key,
    required this.coupleId,
    required this.myUid,
    required this.partnerUid,
    required this.myName,
    required this.partnerName,
    required this.words,
  });

  @override
  State<RemoteTimedScreen> createState() => _RemoteTimedScreenState();
}

class _RemoteTimedScreenState extends State<RemoteTimedScreen> {
  StreamSubscription<RemoteTimedSession?>? _sub;
  RemoteTimedSession? _session;
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
  bool _gameActive = false;
  bool _sessionSaved = false;

  Timer? _timer;
  int _timeLeft = 60;
  bool _scorePushed = false;

  late final List<String> _wordPool =
      widget.words.isEmpty ? coupleWords : widget.words;

  @override
  void initState() {
    super.initState();
    _sub =
        RemoteGamesService.remoteTimedStream(widget.coupleId).listen(_onSession);
  }

  void _onSession(RemoteTimedSession? session) async {
    if (!mounted) return;
    if (!_initialized) {
      _initialized = true;
      if (session == null) {
        // I'm first — create and wait
        await RemoteGamesService.createRemoteTimed(
          coupleId: widget.coupleId,
          myUid: widget.myUid,
        );
        return;
      }
      if (session.status == 'waiting' &&
          session.player1Uid != widget.myUid &&
          session.player2Uid == null) {
        // I'm second — join and start timer
        await RemoteGamesService.joinRemoteTimed(
          coupleId: widget.coupleId,
          myUid: widget.myUid,
        );
        return;
      }
    }

    setState(() => _session = session);
    if (session == null) return;

    // Game started — initialize local timer from server start time
    if (session.status == 'playing' && !_gameActive && session.startTime != null) {
      final elapsed =
          DateTime.now().difference(session.startTime!).inSeconds;
      final remaining = session.durationSeconds - elapsed;
      if (remaining > 0) {
        _startLocalGame(remaining);
      } else {
        // Already expired before we even got the update
        _endGame();
      }
    }

    if (session.status == 'finished' && _gameActive) {
      _timer?.cancel();
      setState(() => _gameActive = false);
    }
  }

  void _startLocalGame(int remainingSeconds) {
    _timeLeft = remainingSeconds;
    _gameActive = true;
    _pickNewWord();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _endGame();
      }
    });
    setState(() {});
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
      _usedWords.add(_currentWord);
      _hiddenWord = _makeHidden(_currentWord);
      _guessCtrl.clear();
      _feedback = '';
    });
  }

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

  Future<void> _checkGuess() async {
    if (!_gameActive) return;
    final guess = _guessCtrl.text.trim().toLowerCase();
    if (guess.isEmpty) return;
    _guessCtrl.clear();
    _focusNode.requestFocus();

    if (guess == _currentWord.toLowerCase()) {
      final newScore = _myScore + 5;
      setState(() {
        _myScore = newScore;
        _feedback = '+5 pts ✨';
        _feedbackPositive = true;
      });
      // Sync score to Firestore
      if (_session != null) {
        await RemoteGamesService.updateTimedScore(
          coupleId: widget.coupleId,
          myUid: widget.myUid,
          session: _session!,
          score: newScore,
        );
      }
      Future.delayed(const Duration(milliseconds: 400), _pickNewWord);
    } else {
      setState(() {
        _feedback = 'Pas tout à fait !';
        _feedbackPositive = false;
      });
    }
  }

  Future<void> _endGame() async {
    if (_scorePushed) return;
    _scorePushed = true;
    setState(() => _gameActive = false);

    // Push final score and mark as finished
    if (_session != null && mounted) {
      await RemoteGamesService.updateTimedScore(
        coupleId: widget.coupleId,
        myUid: widget.myUid,
        session: _session!,
        score: _myScore,
      );
      await RemoteGamesService.finishRemoteTimed(widget.coupleId);
    }
  }

  Future<void> _quit() async {
    _timer?.cancel();
    await RemoteGamesService.deleteRemoteTimed(widget.coupleId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _guessCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color get _timerColor {
    if (_timeLeft > 30) return AppColors.primary;
    if (_timeLeft > 10) return Colors.orange;
    return Colors.red.shade400;
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

    final status = _session?.status ?? 'waiting';

    if (status == 'waiting') {
      return _TimedWaitingView(
          partnerName: widget.partnerName, onCancel: _quit);
    }

    if (status == 'finished' && !_gameActive) {
      final myFinalScore =
          _session?.scoreFor(widget.myUid) ?? _myScore;
      final partnerFinalScore =
          _session?.partnerScore(widget.myUid) ?? 0;
      final iWon = myFinalScore >= partnerFinalScore;
      if (!_sessionSaved) {
        _sessionSaved = true;
        LocalStorageService().saveSession(GameSessionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          mode: 'chrono',
          player1Score: myFinalScore,
          player2Score: partnerFinalScore,
          winner: iWon ? 1 : 2,
          player1Name: widget.myName,
          player2Name: widget.partnerName,
          playedAt: DateTime.now(),
          wordsGuessed: myFinalScore ~/ 2,
          duration: const Duration(seconds: 60),
        ));
      }
      return _TimedResultView(
        myName: widget.myName,
        partnerName: widget.partnerName,
        myScore: myFinalScore,
        partnerScore: partnerFinalScore,
        iWon: iWon,
        onPlayAgain: () async {
          await RemoteGamesService.deleteRemoteTimed(widget.coupleId);
          if (mounted) Navigator.pop(context);
        },
      );
    }

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
        title: const Text('Chrono — À distance',
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
              // Timer
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 10),
                  decoration: BoxDecoration(
                    color: _timerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded,
                          size: 20, color: _timerColor),
                      const SizedBox(width: 8),
                      Text(
                        '$_timeLeft s',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _timerColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Score row
              Row(
                children: [
                  Expanded(
                    child: _TimedScoreChip(
                      label: widget.myName,
                      score: _myScore,
                      color: AppColors.primary,
                      isMe: true,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('vs',
                        style: TextStyle(
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: _TimedScoreChip(
                      label: widget.partnerName,
                      score: partnerScore,
                      color: AppColors.accent,
                      isMe: false,
                    ),
                  ),
                ],
              ),
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
                      enabled: _gameActive,
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
                    onTap: _gameActive ? _checkGuess : null,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _gameActive
                            ? AppColors.primary
                            : AppColors.textLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 24),
                    ),
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

class _TimedWaitingView extends StatelessWidget {
  final String partnerName;
  final VoidCallback onCancel;
  const _TimedWaitingView(
      {required this.partnerName, required this.onCancel});

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
                child: const Icon(Icons.timer_rounded,
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
                'Le chrono démarrera automatiquement\nquand votre partenaire rejoindra.',
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

class _TimedResultView extends StatelessWidget {
  final String myName;
  final String partnerName;
  final int myScore;
  final int partnerScore;
  final bool iWon;
  final VoidCallback onPlayAgain;

  const _TimedResultView({
    required this.myName,
    required this.partnerName,
    required this.myScore,
    required this.partnerScore,
    required this.iWon,
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
                  iWon
                      ? Icons.emoji_events_rounded
                      : Icons.timer_off_rounded,
                  size: 80,
                  color: iWon ? Colors.amber.shade600 : AppColors.textMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  iWon ? 'Vous avez gagné ! 🏆' : '$partnerName a gagné !',
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
                    _ScoreChip(
                        label: myName, score: myScore, highlight: iWon),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('vs',
                          style: TextStyle(
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w700)),
                    ),
                    _ScoreChip(
                        label: partnerName,
                        score: partnerScore,
                        highlight: !iWon),
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

class _TimedScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isMe;

  const _TimedScoreChip({
    required this.label,
    required this.score,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isMe ? color : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: isMe ? Colors.white70 : AppColors.textMedium,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$score pts',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isMe ? Colors.white : color)),
        ],
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
              color:
                  highlight ? AppColors.primary : AppColors.textLight),
        ),
      ],
    );
  }
}
