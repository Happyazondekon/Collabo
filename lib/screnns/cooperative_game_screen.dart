import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../data/couple_words.dart';
import '../models/badge_model.dart';
import '../widgets/badge_unlocked_dialog.dart';

class CooperativeGameScreen extends StatefulWidget {
  final String player1Color;
  final String player2Color;

  const CooperativeGameScreen({
    super.key,
    required this.player1Color,
    required this.player2Color,
  });

  @override
  _CooperativeGameScreenState createState() => _CooperativeGameScreenState();
}

class _CooperativeGameScreenState extends State<CooperativeGameScreen> {
  late ConfettiController _confettiController;
  int teamScore = 0;
  String currentWord = "";
  String hiddenWord = "";
  final TextEditingController _guessController = TextEditingController();
  final List<String> usedWords = [];
  final Random _random = Random();
  bool _showHint = false;
  final int _targetScore = 20;
  int _correctAnswers = 0;
  final List<BadgeModel> _badges = [];
  bool _isCorrectAnimation = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pickNewWord();
    _initBadges();
  }

  void _initBadges() {
    _badges.add(BadgeModel(
      id: 'first_win',
      name: 'Premier Succès',
      description: 'Gagnez votre première partie en coopération',
      isUnlocked: false,
      icon: Icons.emoji_events,
    ));

    _badges.add(BadgeModel(
      id: 'perfect_5',
      name: 'Harmonie Parfaite',
      description: 'Répondez correctement à 5 mots sans erreur',
      isUnlocked: false,
      icon: Icons.favorite,
    ));

    _badges.add(BadgeModel(
      id: 'team_20',
      name: 'Couple en Or',
      description: 'Atteignez 20 points en mode coopératif',
      isUnlocked: false,
      icon: Icons.workspace_premium,
    ));
  }

  void _checkForBadges() {
    List<BadgeModel> newlyUnlockedBadges = [];

    for (var badge in _badges) {
      if (!badge.isUnlocked) {
        bool shouldUnlock = false;

        switch (badge.id) {
          case 'first_win':
            shouldUnlock = teamScore >= _targetScore;
            break;
          case 'perfect_5':
            shouldUnlock = _correctAnswers >= 5;
            break;
          case 'team_20':
            shouldUnlock = teamScore >= 20;
            break;
        }

        if (shouldUnlock) {
          badge.isUnlocked = true;
          newlyUnlockedBadges.add(badge);
        }
      }
    }

    if (newlyUnlockedBadges.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          builder: (context) => BadgeUnlockedDialog(badges: newlyUnlockedBadges),
        );
      });
    }
  }

  void _pickNewWord() {
    List<String> availableWords = coupleWords.where((word) => !usedWords.contains(word)).toList();

    if (availableWords.isEmpty) {
      availableWords = coupleWords;
      usedWords.clear();
    }

    setState(() {
      currentWord = availableWords[_random.nextInt(availableWords.length)];
      usedWords.add(currentWord);
      hiddenWord = _generateHiddenWord(currentWord);
      _guessController.clear();
      _showHint = false;
      _isCorrectAnimation = false;
    });
  }

  String _generateHiddenWord(String word) {
    if (word.length <= 3) return word[0] + "_" * (word.length - 1);

    final revealedIndices = <int>[];
    final lettersToShow = max(1, (word.length * 0.3).floor());

    while (revealedIndices.length < lettersToShow) {
      final index = _random.nextInt(word.length);
      if (index != 0 && !revealedIndices.contains(index)) {
        revealedIndices.add(index);
      }
    }

    String result = "";
    for (int i = 0; i < word.length; i++) {
      result += (i == 0 || revealedIndices.contains(i)) ? word[i] : "_";
    }
    return result;
  }

  void _checkGuess() {
    if (_guessController.text.trim().isEmpty) return;

    if (_guessController.text.trim().toLowerCase() == currentWord.toLowerCase()) {
      setState(() {
        _isCorrectAnimation = true;
      });

      _confettiController.play();
      _correctAnswers++;
      teamScore += 5;

      _checkForBadges();

      Future.delayed(const Duration(seconds: 2), () {
        if (teamScore >= _targetScore) {
          _showVictoryDialog();
        } else {
          _pickNewWord();
        }
      });
    } else {
      _correctAnswers = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Essayez encore !'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _getPlayerColor(1).withOpacity(0.9),
                  _getPlayerColor(2).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  '🎉 Félicitations !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Vous avez gagné ensemble !',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Score final: $teamScore',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                      child: const Text('Accueil'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          teamScore = 0;
                          _correctAnswers = 0;
                          _pickNewWord();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _getTeamColor(),
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Rejouer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getTeamColor() {
    final color1 = _getPlayerColor(1);
    final color2 = _getPlayerColor(2);
    return Color.lerp(color1, color2, 0.5)!;
  }

  Color _getPlayerColor(int playerNumber) {
    final color = playerNumber == 1 ? widget.player1Color : widget.player2Color;
    switch (color) {
      case 'Rouge': return Colors.red[400]!;
      case 'Bleu': return Colors.blue[400]!;
      case 'Rose': return Colors.pink[300]!;
      case 'Vert': return Colors.green[400]!;
      case 'Violet': return Colors.purple[400]!;
      case 'Orange': return Colors.orange[400]!;
      case 'Jaune': return Colors.yellow[600]!;
      default: return Colors.grey;
    }
  }

  void _toggleHint() {
    setState(() {
      _showHint = !_showHint;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = _getTeamColor();
    final player1Color = _getPlayerColor(1);
    final player2Color = _getPlayerColor(2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Coopératif'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [player1Color, player2Color],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink[50]!,
              Colors.purple[50]!,
            ],
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Score Board
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          player1Color.withOpacity(0.1),
                          player2Color.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite, color: player1Color),
                            const SizedBox(width: 5),
                            Icon(Icons.favorite, color: player2Color),
                          ],
                        ),
                        Text(
                          'Score: $teamScore/$_targetScore',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: teamColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: teamColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_correctAnswers/5',
                            style: TextStyle(
                              color: teamColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Word Card
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    transform: _isCorrectAnimation
                        ? (Matrix4.identity()..scale(1.05))
                        : Matrix4.identity(),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.white,
                              teamColor.withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              hiddenWord,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                color: Colors.purple[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_showHint)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text(
                                  '"${currentWord}"',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Input Field
                  TextField(
                    controller: _guessController,
                    decoration: InputDecoration(
                      labelText: 'Votre réponse',
                      labelStyle: TextStyle(color: Colors.grey[700]),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: teamColor, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showHint ? Icons.visibility_off : Icons.visibility,
                          color: teamColor,
                        ),
                        onPressed: _toggleHint,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    onSubmitted: (_) => _checkGuess(),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 25),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _checkGuess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teamColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                          shadowColor: teamColor.withOpacity(0.5),
                        ),
                        child: const Text(
                          'Valider',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            hiddenWord = currentWord;
                          });
                          Future.delayed(const Duration(seconds: 3), () {
                            _pickNewWord();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: teamColor,
                          side: BorderSide(color: teamColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Révéler',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.pink,
                  Colors.red,
                  Colors.purple,
                  Colors.blue,
                  Colors.green,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _guessController.dispose();
    super.dispose();
  }
}