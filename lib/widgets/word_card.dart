import 'package:flutter/material.dart';

class WordCard extends StatelessWidget {
  final String word;

  const WordCard({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          word,
          style: const TextStyle(fontSize: 24, letterSpacing: 2),
        ),
      ),
    );
  }
}