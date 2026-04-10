import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Displays a user avatar:
/// - [avatarData] (base64 custom photo) takes priority
/// - falls back to [avatarUrl] (network image)
/// - falls back to the first letter of [name]
class UserAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? avatarData;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.avatarData,
    this.radius = 20,
    this.backgroundColor = AppColors.primarySoft,
    this.textColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = avatarData != null && avatarData!.isNotEmpty;
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    ImageProvider? imageProvider;
    if (hasData) {
      imageProvider = MemoryImage(base64Decode(avatarData!));
    } else if (hasUrl) {
      imageProvider = NetworkImage(avatarUrl!);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initial,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );
  }
}
