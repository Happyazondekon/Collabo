import 'package:flutter/material.dart';
import 'dart:math';
import '../Data/couple_words.dart';
import '../models/game_difficulty.dart';
import '../services/local_storage_service.dart';
import '../models/game_session_model.dart';
import '../utils/app_theme.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  final GameDifficulty difficulty;
  final List<String>? customWords;
  final String player1Name;
  final String player2Name;

  const GameScreen({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    required this.difficulty,
    this.customWords,
    this.player1Name = 'Joueur 1',
    this.player2Name = 'Joueur 2',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  int _player1Score = 0;
  int _player2Score = 0;
  int _currentPlayer = 1;
  String _currentWord = '';
  String _feedback = '';
  bool _feedbackPositive = false;
  final TextEditingController _guessCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _usedWords = [];
  final Random _random = Random();
  int _wordsGuessed = 0;
  final int _targetScore = 19;
  late List<String> _wordPool;
  String _hiddenWord = '';

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 8).chain(
        CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);
    _wordPool = widget.customWords ?? List.from(coupleWords);
    _pickNewWord();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _guessCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
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

  void _pickNewWord() {
    final available = _wordPool.where((w) => !_usedWords.contains(w)).toList();
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

  void _checkGuess() {
    final guess = _guessCtrl.text.trim().toLowerCase();
    if (guess.isEmpty) return;

    final correct = guess == _currentWord.toLowerCase();
    _guessCtrl.clear();
    _focusNode.requestFocus();

    if (correct) {
      setState(() {
        _wordsGuessed++;
        _feedback = 'Bravo ! +5 pts ✨';
        _feedbackPositive = true;
        if (_currentPlayer == 1) {
          _player1Score += 5;
        } else {
          _player2Score += 5;
        }
      });

      if (_player1Score >= _targetScore || _player2Score >= _targetScore) {
        _endGame();
        return;
      }
      _currentPlayer = _currentPlayer == 1 ? 2 : 1;
      Future.delayed(const Duration(milliseconds: 600), _pickNewWord);
    } else {
      setState(() {
        _feedback = 'Pas tout à fait… Réessaie !';
        _feedbackPositive = false;
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  void _skipWord() {
    _guessCtrl.clear();
    setState(() {
      _feedback = 'Mot passé';
      _feedbackPositive = false;
      _currentPlayer = _currentPlayer == 1 ? 2 : 1;
    });
    Future.delayed(const Duration(milliseconds: 300), _pickNewWord);
  }

  Future<void> _endGame() async {
    final winner = _player1Score > _player2Score ? 1 : 2;
    final session = GameSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mode: 'competitif',
      player1Score: _player1Score,
      player2Score: _player2Score,
      winner: winner,
      playedAt: DateTime.now(),
      wordsGuessed: _wordsGuessed,
      totalWords: _wordsGuessed,
    );
    await LocalStorageService().saveSession(session);
    await LocalStorageService().incrementStat('games_played');
    await LocalStorageService().incrementStat('words_guessed', _wordsGuessed);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          winner: winner,
          player1Score: _player1Score,
          player2Score: _player2Score,
          wordsGuessed: _wordsGuessed,
          primaryColor: widget.primaryColor,
          accentColor: widget.accentColor,          player1Name: widget.player1Name,
          player2Name: widget.player2Name,        ),
      ),
    );
  }

  double get _compliciteGauge {
    final total = _player1Score + _player2Score;
    return (total / (_targetScore * 2)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mode Compétitif',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Score cards
              Row(
                children: [
                  _ScoreCard(
                    label: widget.player1Name,
                    score: _player1Score,
                    color: widget.primaryColor,
                    isActive: _currentPlayer == 1,
                    target: _targetScore,
                  ),
                  const SizedBox(width: 12),
                  _ScoreCard(
                    label: widget.player2Name,
                    score: _player2Score,
                    color: widget.accentColor,
                    isActive: _currentPlayer == 2,
                    target: _targetScore,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Complicité gauge
              _CompliciteGauge(
                  value: _compliciteGauge,
                  primaryColor: widget.primaryColor,
                  accentColor: widget.accentColor),
              const SizedBox(height: 20),
              // Turn indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: (_currentPlayer == 1 ? widget.primaryColor : widget.accentColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded,
                        size: 16,
                        color: _currentPlayer == 1
                            ? widget.primaryColor
                            : widget.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Tour de ${_currentPlayer == 1 ? widget.player1Name : widget.player2Name}',
                      style: TextStyle(
                        color: _currentPlayer == 1
                            ? widget.primaryColor
                            : widget.accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Word card with shake
              Expanded(
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(
                        _shakeCtrl.isAnimating
                            ? _shakeAnim.value * (_shakeCtrl.value < 0.5 ? 1 : -1)
                            : 0,
                        0),
                    child: child,
                  ),
                  child: _WordCard(
                    word: _hiddenWord,
                    primaryColor: widget.primaryColor,
                    feedback: _feedback,
                    feedbackPositive: _feedbackPositive,
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
                        decoration: const InputDecoration(
                          hintText: 'Votre réponse…',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textDark),
                      ),
                    ),
                    GestureDetector(
                      onTap: _checkGuess,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [widget.primaryColor, widget.accentColor]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _skipWord,
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text('Passer ce mot'),
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

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool isActive;
  final int target;

  const _ScoreCard(
      {required this.label,
      required this.score,
      required this.color,
      required this.isActive,
      required this.target});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isActive ? color : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: isActive ? 0.2 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$score',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: color)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (score / target).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompliciteGauge extends StatelessWidget {
  final double value;
  final Color primaryColor;
  final Color accentColor;

  const _CompliciteGauge(
      {required this.value,
      required this.primaryColor,
      required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Complicité',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMedium)),
              Text('${(value * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final String word;
  final Color primaryColor;
  final String feedback;
  final bool feedbackPositive;

  const _WordCard(
      {required this.word,
      required this.primaryColor,
      required this.feedback,
      required this.feedbackPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded,
              color: primaryColor.withValues(alpha: 0.4), size: 36),
          const SizedBox(height: 16),
          Text(word,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.textDark,
                  height: 1.2)),
          const SizedBox(height: 16),
          if (feedback.isNotEmpty)
            AnimatedOpacity(
              opacity: feedback.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: feedbackPositive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  feedback,
                  style: TextStyle(
                      color: feedbackPositive ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
