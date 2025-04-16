import 'dart:ui';

import 'package:flutter/material.dart';
import 'game_modes_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String? player1Color;
  String? player2Color;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Title and Icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink, size: 60),
                        const SizedBox(height: 15),
                        Text(
                          'Collabo - Notre Histoire',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[300],
                            shadows: [
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.pink[100]!,
                                offset: const Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Créez des souvenirs ensemble',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Color selection card with glassmorphism
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink[100]!.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Text(
                                'Choisissez vos couleurs',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[800],
                                ),
                              ),
                              const SizedBox(height: 25),
                              _buildColorDropdown(
                                value: player1Color,
                                hint: 'Couleur Joueur 1',
                                onChanged: (value) {
                                  setState(() => player1Color = value);
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildColorDropdown(
                                value: player2Color,
                                hint: 'Couleur Joueur 2',
                                onChanged: (value) {
                                  setState(() => player2Color = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildGradientButton(
                          enabled: player1Color != null && player2Color != null,
                          text: 'Jouer',
                          gradientColors: [Colors.pink[300]!, Colors.purple[400]!],
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameModesScreen(
                                  player1Color: player1Color!,
                                  player2Color: player2Color!,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildGradientButton(
                          enabled: player1Color != null && player2Color != null,
                          text: 'Calendrier',
                          gradientColors: [Colors.teal[400]!, Colors.blue[400]!],
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CalendarScreen(
                                  player1Color: player1Color!,
                                  player2Color: player2Color!,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required bool enabled,
    required String text,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: enabled ? gradientColors : [Colors.grey[400]!, Colors.grey[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: enabled ? gradientColors.first.withOpacity(0.4) : Colors.grey,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.pink[100]!.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint, style: TextStyle(color: Colors.grey[700])),
        items: colors.map((colorData) {
          return DropdownMenuItem<String>(
            value: colorData['name'],
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorData['color'],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorData['color'].withOpacity(0.5),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  colorData['name'],
                  style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
        icon: Icon(Icons.arrow_drop_down, color: Colors.pink[300]),
        dropdownColor: Colors.white.withOpacity(0.95),
        style: TextStyle(fontSize: 16, color: Colors.grey[800]),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
