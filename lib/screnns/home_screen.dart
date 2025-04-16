import 'package:flutter/material.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? player1Color;
  String? player2Color;
  final List<Map<String, dynamic>> colors = [
    {'name': 'Rouge', 'color': Colors.red[400]!},
    {'name': 'Bleu', 'color': Colors.blue[400]!},
    {'name': 'Rose', 'color': Colors.pink[300]!},
    {'name': 'Vert', 'color': Colors.green[400]!},
    {'name': 'Violet', 'color': Colors.purple[400]!},
    {'name': 'Orange', 'color': Colors.orange[400]!},
    {'name': 'Jaune', 'color': Colors.yellow[600]!},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFfff5f5), Color(0xFFfef9ff)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Titre avec icône
              Column(
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Colors.pink,
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Collabo - Notre Histoire',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Carte de sélection des couleurs
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Choisissez vos couleurs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Sélecteur Joueur 1
                      _buildColorDropdown(
                        value: player1Color,
                        hint: 'Couleur Joueur 1',
                        onChanged: (value) {
                          setState(() {
                            player1Color = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Sélecteur Joueur 2
                      _buildColorDropdown(
                        value: player2Color,
                        hint: 'Couleur Joueur 2',
                        onChanged: (value) {
                          setState(() {
                            player2Color = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Bouton de démarrage
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (player1Color != null && player2Color != null)
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GameScreen(
                          player1Color: player1Color!,
                          player2Color: player2Color!,
                        ),
                      ),
                    );
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: Colors.pink[100],
                  ),
                  child: const Text(
                    'Commencer le jeu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Note en bas
              const SizedBox(height: 30),
              Text(
                'Créez des souvenirs ensemble',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorDropdown({
    required String? value,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint),
        items: colors.map((colorData) {
          return DropdownMenuItem<String>(
            value: colorData['name'],
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorData['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(colorData['name']),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        icon: const Icon(Icons.arrow_drop_down),
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}