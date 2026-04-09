import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'dart:math';
import '../Data/couple_words.dart';
import '../models/game_session_model.dart';
import '../services/local_storage_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class TimedGameScreen extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  final List<String>? customWords;
  final int durationSeconds;

  const TimedGameScreen({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    this.customWords,
    this.durationSeconds = 60,
  });

  @override
  State<TimedGameScreen> createState() => _TimedGameScreenState();
}

class _TimedGameScreenState extends State<TimedGameScreen> {
  late ConfettiController _confetti;
  int _score = 0;
  String _currentWord = '';
  String _hiddenWord = '';
  final TextEditingController _guessCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _usedWords = [];
  final Random _random = Random();
  int _wordsGuessed = 0;

  late int _timeLeft;
  Timer? _timer;
  bool _gameActive = false;

  String _feedback = '';
  bool _feedbackPositive = false;

  late List<String> _wordPool;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _wordPool = widget.customWords ?? List.from(coupleWords);
    _timeLeft = widget.durationSeconds;
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    _guessCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startGame() {
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
    setState(() => _gameActive = true);
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
    return word.split('').asMap().entries
        .map((e) => indices.contains(e.key) ? e.value : '_')
        .join();
  }

  void _checkGuess() {
    if (!_gameActive) return;
    final guess = _guessCtrl.text.trim().toLowerCase();
    if (guess.isEmpty) return;
    _guessCtrl.clear();
    _focusNode.requestFocus();

    if (guess == _currentWord.toLowerCase()) {
      _confetti.play();
      _wordsGuessed++;
      setState(() {
        _score += 5;
        _feedback = '+5 pts ✨';
        _feedbackPositive = true;
      });
      Future.delayed(const Duration(milliseconds: 400), _pickNewWord);
    } else {
      setState(() {
        _feedback = 'Pas tout à fait !';
        _feedbackPositive = false;
      });
    }
  }

  Future<void> _endGame() async {
    setState(() => _gameActive = false);
    final session = GameSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mode: 'chrono',
      teamScore: _score,
      playedAt: DateTime.now(),
      wordsGuessed: _wordsGuessed,
      totalWords: _wordsGuessed,
    );
    await LocalStorageService().saveSession(session);
    await LocalStorageService().incrementStat('games_played');
    await LocalStorageService().incrementStat('words_guessed', _wordsGuessed);
    await LocalStorageService().checkAndUpdateAchievements();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        score: _score,
        words: _wordsGuessed,
        primaryColor: widget.primaryColor,
        accentColor: widget.accentColor,
        onReplay: () {
          Navigator.pop(context);
          setState(() {
            _score = 0;
            _timeLeft = widget.durationSeconds;
            _wordsGuessed = 0;
            _usedWords.clear();
            _gameActive = false;
          });
          _startGame();
        },
        onHome: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        ),
      ),
    );
  }

  Color get _timerColor {
    if (_timeLeft > 30) return widget.primaryColor;
    if (_timeLeft > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Contre-la-Montre',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
        actions: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 15,
            colors: [widget.primaryColor, widget.accentColor, Colors.amber],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Timer + score row
              Row(
                children: [
                  // Timer
                  Expanded(
                    child: _TimerCard(
                        timeLeft: _timeLeft,
                        total: widget.durationSeconds,
                        color: _timerColor),
                  ),
                  const SizedBox(width: 12),
                  // Score
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: widget.primaryColor.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.star_rounded,
                              color: widget.primaryColor, size: 22),
                          const SizedBox(height: 4),
                          Text('$_score',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: widget.primaryColor)),
                          const Text('points',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMedium)),
                        ],
                      ),
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
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_rounded,
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          size: 36),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _hiddenWord,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${_currentWord.length} lettres',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium)),
                      const SizedBox(height: 16),
                      if (_feedback.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _feedbackPositive
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_feedback,
                              style: TextStyle(
                                  color: _feedbackPositive
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _focusNode,
                        controller: _guessCtrl,
                        onSubmitted: (_) => _checkGuess(),
                        enabled: _gameActive,
                        decoration: const InputDecoration(
                          hintText: 'Devinez vite…',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textDark),
                      ),
                    ),
                    GestureDetector(
                      onTap: _gameActive ? _checkGuess : null,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            widget.primaryColor,
                            widget.accentColor
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _gameActive ? _pickNewWord : null,
                icon: const Icon(Icons.skip_next_rounded, size: 16),
                label: const Text('Passer'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMedium),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  final int timeLeft;
  final int total;
  final Color color;

  const _TimerCard(
      {required this.timeLeft,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.timer_rounded, color: color, size: 22),
          const SizedBox(height: 4),
          Text('$timeLeft',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const Text('secondes',
              style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: timeLeft / total,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameOverDialog extends StatelessWidget {
  final int score;
  final int words;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _GameOverDialog(
      {required this.score,
      required this.words,
      required this.primaryColor,
      required this.accentColor,
      required this.onReplay,
      required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded,
                  color: Color(0xFF8B5CF6), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Temps écoulé !',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text('Score : $score pts • $words mots',
                style: TextStyle(
                    fontSize: 15,
                    color: primaryColor,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onHome,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Accueil',
                        style: TextStyle(color: primaryColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReplay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Rejouer',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
