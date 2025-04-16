import 'package:flutter/material.dart';
import 'cooperative_game_screen.dart';
import 'game_screen.dart';
import 'timed_game_screen.dart';
import '../models/game_difficulty.dart';

class GameModesScreen extends StatelessWidget {
  final String player1Color;
  final String player2Color;

  const GameModesScreen({
    super.key,
    required this.player1Color,
    required this.player2Color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modes de Jeu'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink[300]!, Colors.purple[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                'Choisissez votre aventure',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Découvrez différentes façons de jouer ensemble',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  children: [
                    _buildModeCard(
                      context,
                      title: 'Compétitif',
                      description: 'Affrontez-vous pour être le premier à gagner',
                      icon: Icons.sports_kabaddi,
                      gradientColors: [Colors.red[300]!, Colors.orange[300]!],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              player1Color: player1Color,
                              player2Color: player2Color,
                              difficulty: GameDifficulty.normal,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildModeCard(
                      context,
                      title: 'Coopératif',
                      description: 'Collaborez pour deviner des mots et gagner des badges',
                      icon: Icons.people,
                      gradientColors: [Colors.blue[300]!, Colors.teal[300]!],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CooperativeGameScreen(
                              player1Color: player1Color,
                              player2Color: player2Color,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildModeCard(
                      context,
                      title: 'Contre-la-Montre',
                      description: 'Devinez le maximum de mots avant la fin du temps',
                      icon: Icons.timer,
                      gradientColors: [Colors.purple[300]!, Colors.indigo[300]!],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TimedGameScreen(
                              player1Color: player1Color,
                              player2Color: player2Color,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildModeCard(
                      context,
                      title: 'Personnalisé',
                      description: 'Jouez avec vos propres mots et phrases',
                      icon: Icons.edit,
                      gradientColors: [Colors.green[300]!, Colors.lightGreen[300]!],
                      onTap: () {
                        _showCustomWordDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
      BuildContext context, {
        required String title,
        required String description,
        required IconData icon,
        required List<Color> gradientColors,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: gradientColors[0].withOpacity(0.2),
          highlightColor: gradientColors[0].withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomWordDialog(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    final List<String> _customWords = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.pink[50]!, Colors.purple[50]!],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mots Personnalisés',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot ou phrase',
                      hintText: 'Ex: Notre premier baiser',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        setState(() {
                          _customWords.add(_controller.text);
                          _controller.clear();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Ajouter',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_customWords.isNotEmpty) ...[
                    Text(
                      'Vos mots:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _customWords.length,
                        itemBuilder: (context, index) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white.withOpacity(0.7),
                            child: ListTile(
                              title: Text(_customWords[index]),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.pink[300],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _customWords.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple[800],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        onPressed: _customWords.isEmpty
                            ? null
                            : () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GameScreen(
                                player1Color: player1Color,
                                player2Color: player2Color,
                                difficulty: GameDifficulty.normal,
                                customWords: _customWords,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Jouer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}