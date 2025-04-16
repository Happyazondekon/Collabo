import 'package:flutter/material.dart';
import 'screnns/home_screen.dart';

void main() {
  runApp(const CoupleGameApp());
}

class CoupleGameApp extends StatelessWidget {
  const CoupleGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collabo',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}