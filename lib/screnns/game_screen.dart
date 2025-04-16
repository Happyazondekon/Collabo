import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../data/couple_words.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final String player1Color;
  final String player2Color;

  const GameScreen({
    super.key,
    required this.player1Color,
    required this.player2Color,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ConfettiController _confettiController;
  int player1Score = 0;
  int player2Score = 0;
  String currentWord = "";
  String hiddenWord = "";
  bool isPlayer1Turn = true;
  final TextEditingController _guessController = TextEditingController();
  final List<String> usedWords = [];
  final Random _random = Random();
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pickNewWord();
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
    if (_guessController.text.trim().isEmpty) return;

    if (_guessController.text.trim().toLowerCase() == currentWord.toLowerCase()) {
      _confettiController.play();

      setState(() {
        if (isPlayer1Turn) {
          player1Score += 5;
        } else {
          player2Score += 5;
        }
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (player1Score >= 19 || player2Score >= 19) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                winner: player1Score >= 19 ? 1 : 2,
                player1Color: widget.player1Color,
                player2Color: widget.player2Color,
              ),
            ),
          );
        } else {
          setState(() {
            isPlayer1Turn = !isPlayer1Turn;
          });
          _pickNewWord();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Essaie encore !'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
    final currentPlayerColor = _getPlayerColor(isPlayer1Turn ? 1 : 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collabo - Notre Histoire'),
        centerTitle: true,
        automaticallyImplyLeading: false,
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
                // Score Board
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPlayerScore(1),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      _buildPlayerScore(2),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Current Turn Indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  decoration: BoxDecoration(
                    color: currentPlayerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tour du Joueur ${isPlayer1Turn ? 1 : 2}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: currentPlayerColor,
                    ),
                  ),
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
                          currentPlayerColor.withOpacity(0.1),
                          currentPlayerColor.withOpacity(0.05),
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
                  decoration: InputDecoration(
                    labelText: 'Votre réponse',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: currentPlayerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: currentPlayerColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showHint ? Icons.visibility_off : Icons.visibility,
                        color: currentPlayerColor,
                      ),
                      onPressed: _toggleHint,
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
                      onPressed: _checkGuess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPlayerColor,
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
                      onPressed: () {
                        setState(() {
                          hiddenWord = currentWord;
                        });
                        Future.delayed(const Duration(seconds: 3), () {
                          _pickNewWord();
                          setState(() {
                            isPlayer1Turn = !isPlayer1Turn;
                          });
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      ),
                      child: Text(
                        'Révéler',
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

  Widget _buildPlayerScore(int playerNumber) {
    final isActive = (playerNumber == 1 && isPlayer1Turn) || (playerNumber == 2 && !isPlayer1Turn);

    return Column(
      children: [
        Text(
          'Joueur $playerNumber',
          style: TextStyle(
            color: _getPlayerColor(playerNumber),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? _getPlayerColor(playerNumber).withOpacity(0.1) : null,
            shape: BoxShape.circle,
          ),
          child: Text(
            playerNumber == 1 ? '$player1Score' : '$player2Score',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _getPlayerColor(playerNumber),
            ),
          ),
        ),
      ],
    );
  }
}