import 'package:flutter/material.dart';
import '../models/game_session_model.dart';
import '../services/local_storage_service.dart';
import '../utils/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<GameSessionModel> _sessions = [];
  String _filter = 'Tous';
  bool _loading = true;

  final _filters = ['Tous', 'Compétitif', 'Coopératif', 'Chrono'];
  final _modeMap = {
    'Tous': null,
    'Compétitif': 'competitif',
    'Coopératif': 'cooperatif',
    'Chrono': 'chrono',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await LocalStorageService().getSessions();
    setState(() {
      _sessions = sessions.reversed.toList();
      _loading = false;
    });
  }

  List<GameSessionModel> get _filtered {
    final mode = _modeMap[_filter];
    if (mode == null) return _sessions;
    return _sessions.where((s) => s.mode == mode).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historique',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Vos parties jouées',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textMedium)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final active = _filter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3))
                                  ]
                                : null,
                          ),
                          child: Text(f,
                              style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : AppColors.textMedium,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _SessionCard(session: _filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_esports_rounded,
              size: 72, color: AppColors.primary.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          const Text('Aucune partie jouée',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Vos parties apparaîtront ici',
              style:
                  TextStyle(fontSize: 14, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final GameSessionModel session;

  const _SessionCard({required this.session});

  Color get _modeColor {
    switch (session.mode) {
      case 'cooperatif':
        return const Color(0xFF0EA5E9);
      case 'chrono':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.primary;
    }
  }

  IconData get _modeIcon {
    switch (session.mode) {
      case 'cooperatif':
        return Icons.handshake_rounded;
      case 'chrono':
        return Icons.timer_rounded;
      default:
        return Icons.sports_kabaddi_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _modeColor;
    final d = session.playedAt;
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    final date = '${d.day} ${months[d.month - 1]} ${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: Icon(_modeIcon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.modeLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textDark)),
                  const SizedBox(height: 3),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (session.mode == 'cooperatif')
                  _Badge(
                      label: '${session.teamScore ?? 0} pts',
                      color: color)
                else ...[
                  Text(
                      '${session.player1Score} — ${session.player2Score}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text('Joueur ${session.winner} gagne',
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 4),
                Text('${session.wordsGuessed} mots',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
