
import 'package:flutter/material.dart';
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  bool isUnlocked;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });
}