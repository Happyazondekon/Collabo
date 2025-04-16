import 'package:flutter/material.dart';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../data/couple_words.dart';

class TimedGameScreen extends StatefulWidget {
  final String player1Color;
  final String player2Color;

  const TimedGameScreen({
    super.key,
    required this.player1Color,
    required this.player2Color,
  });

  @override
  _TimedGameScreenState createState() => _TimedGameScreenState();
}

class _TimedGameScreenState extends State<TimedGameScreen> {
  late ConfettiController _confettiController;
  int score = 0;
  String currentWord = "";
  String hiddenWord = "";
  final TextEditingController _guessController = TextEditingController();
  final List<String> usedWords = [];
  final Random _random = Random();
  bool _showHint = false;

  // Timer variables
  int _timeLeft = 60; // 60 seconds
  late Timer _timer;
  bool _isGameActive = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _startGame();
  }

  void _startGame() {
    _pickNewWord();
    _startTimer();
    setState(() {
      _isGameActive = true;
      score = 0;
    });
  }

  void _startTimer() {
    _timeLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _endGame();
        }
      });
    });
  }

  void _endGame() {
    _timer.cancel();
    setState(() {
      _isGameActive = false;
    });
    _showGameOverDialog();
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
    });
  }

  String _generateHiddenWord(String word) {
    if (word.length <= 3) return word[0] + "_" * (word.length - 1);

    // Show 30% of letters randomly
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
    if (!_isGameActive || _guessController.text.trim().isEmpty) return;

    if (_guessController.text.trim().toLowerCase() == currentWord.toLowerCase()) {
      _confettiController.play();
      setState(() {
        score += 5;
      });
      _pickNewWord();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Essayez encore !'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            '⏱️ Temps écoulé !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La partie est terminée',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 15),
              Text(
                'Score final: $score',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Retour à l\'accueil'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[300],
              ),
              child: const Text('Rejouer'),
            ),
          ],
        );
      },
    );
  }

  Color _getTeamColor() {
    // Mélange des couleurs des deux joueurs
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contre la montre'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // Ajoutez cette ligne
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getPlayerColor(1).withOpacity(0.7),
                _getPlayerColor(2).withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFfff5f5), Color(0xFFfef9ff)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Timer and Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: _timeLeft > 10 ? Colors.white : Colors.red[50],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer,
                            color: _timeLeft > 10 ? Colors.blue[400] : Colors.red[400],
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$_timeLeft s',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _timeLeft > 10 ? Colors.blue[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Score
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[400]),
                          const SizedBox(width: 10),
                          Text(
                            'Score: $score',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: teamColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Word Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [
                          teamColor.withOpacity(0.1),
                          teamColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          hiddenWord,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_showHint)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Text(
                              '"${currentWord}"',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Input Field
                TextField(
                  controller: _guessController,
                  enabled: _isGameActive,
                  decoration: InputDecoration(
                    labelText: 'Votre réponse',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: teamColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: teamColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showHint ? Icons.visibility_off : Icons.visibility,
                        color: teamColor,
                      ),
                      onPressed: _isGameActive ? _toggleHint : null,
                    ),
                  ),
                  onSubmitted: (_) => _checkGuess(),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isGameActive ? _checkGuess : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teamColor,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Valider',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: _isGameActive
                          ? () {
                        setState(() {
                          hiddenWord = currentWord;
                        });
                        Future.delayed(const Duration(seconds: 1), () {
                          _pickNewWord();
                        });
                      }
                          : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      ),
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
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
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _guessController.dispose();
    if (_isGameActive) _timer.cancel();
    super.dispose();
  }
}