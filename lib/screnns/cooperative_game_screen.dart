import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../Data/couple_words.dart';
import '../models/game_session_model.dart';
import '../services/local_storage_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class CooperativeGameScreen extends StatefulWidget {
  final Color primaryColor;
  final Color accentColor;
  final List<String>? customWords;

  const CooperativeGameScreen({
    super.key,
    required this.primaryColor,
    required this.accentColor,
    this.customWords,
  });

  @override
  State<CooperativeGameScreen> createState() => _CooperativeGameScreenState();
}

class _CooperativeGameScreenState extends State<CooperativeGameScreen> {
  late ConfettiController _confetti;
  int _teamScore = 0;
  String _currentWord = '';
  String _hiddenWord = '';
  final TextEditingController _guessCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _usedWords = [];
  final Random _random = Random();
  int _correctStreak = 0;
  int _wordsGuessed = 0;
  final int _targetScore = 10;
  late List<String> _wordPool;
  String _feedback = '';
  bool _feedbackPositive = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _wordPool = widget.customWords ?? List.from(coupleWords);
    _pickNewWord();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _guessCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final guess = _guessCtrl.text.trim().toLowerCase();
    if (guess.isEmpty) return;
    _guessCtrl.clear();
    _focusNode.requestFocus();

    if (guess == _currentWord.toLowerCase()) {
      _confetti.play();
      _correctStreak++;
      _wordsGuessed++;
      setState(() {
        _teamScore += 2;
        _feedback = '+2 pts — Excellent ! 🎉';
        _feedbackPositive = true;
      });

      if (_teamScore >= _targetScore) {
        _endGame(won: true);
        return;
      }
      Future.delayed(const Duration(milliseconds: 700), _pickNewWord);
    } else {
      _correctStreak = 0;
      setState(() {
        _feedback = 'Pas tout à fait… Continuez !';
        _feedbackPositive = false;
      });
    }
  }

  void _showHint() {
    setState(() {
      _hiddenWord = _currentWord; // show full word as hint
      _feedback = 'Indice : $_currentWord';
      _feedbackPositive = false;
    });
  }

  Future<void> _endGame({required bool won}) async {
    final session = GameSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mode: 'cooperatif',
      teamScore: _teamScore,
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
      builder: (_) => _VictoryDialog(
        score: _teamScore,
        won: won,
        primaryColor: widget.primaryColor,
        accentColor: widget.accentColor,
        onReplay: () {
          Navigator.pop(context);
          setState(() {
            _teamScore = 0;
            _wordsGuessed = 0;
            _usedWords.clear();
            _correctStreak = 0;
          });
          _pickNewWord();
        },
        onHome: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        ),
      ),
    );
  }

  double get _progress => (_teamScore / _targetScore).clamp(0.0, 1.0);

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
        title: const Text('Mode Coopératif',
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
            colors: [
              widget.primaryColor,
              widget.accentColor,
              Colors.amber
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Team score card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [widget.primaryColor, widget.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Score équipe',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        Text('$_teamScore / $_targetScore pts',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Hidden word
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
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.handshake_rounded,
                          color: Color(0xFF0EA5E9), size: 36),
                      const SizedBox(height: 16),
                      // Hidden word display
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
                      Text(
                        '${_currentWord.length} lettres',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium),
                      ),
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
                        decoration: const InputDecoration(
                          hintText: 'Devinez le mot…',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _showHint,
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                    label: const Text('Indice'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMedium),
                  ),
                  TextButton.icon(
                    onPressed: _pickNewWord,
                    icon: const Icon(Icons.skip_next_rounded, size: 16),
                    label: const Text('Passer'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _VictoryDialog extends StatelessWidget {
  final int score;
  final bool won;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const _VictoryDialog({
    required this.score,
    required this.won,
    required this.primaryColor,
    required this.accentColor,
    required this.onReplay,
    required this.onHome,
  });

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
                gradient: LinearGradient(
                    colors: [primaryColor, accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  won
                      ? Icons.celebration_rounded
                      : Icons.timer_off_rounded,
                  color: Colors.white,
                  size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              won ? 'Bravo à vous deux !' : 'Pas de victoire cette fois',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Score final : $score pts',
                style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReplay,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Rejouer',
                        style: TextStyle(color: primaryColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Accueil',
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
