import 'package:flutter/material.dart';
import '../models/badge_model.dart';

class BadgeUnlockedDialog extends StatelessWidget {
  final List<BadgeModel> badges;

  const BadgeUnlockedDialog({
    super.key,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 50,
            ),
            const SizedBox(height: 15),
            Text(
              badges.length == 1 ? 'Badge Débloqué !' : 'Badges Débloqués !',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            for (var badge in badges) ...[
              _buildBadgeItem(badge),
              const SizedBox(height: 15),
            ],
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(BadgeModel badge) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            badge.icon,
            color: Colors.amber[800],
            size: 28,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                badge.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                badge.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}