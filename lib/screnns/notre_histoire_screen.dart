import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/couple_service.dart';
import '../utils/app_theme.dart';

class NotreHistoireScreen extends StatelessWidget {
  const NotreHistoireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: CoupleService.myProfileStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final profile = snap.data;
        if (profile?.coupleId == null) {
          return const _NoCoupleState();
        }
        return _HistoireView(coupleId: profile!.coupleId!);
      },
    );
  }
}

// ─── No couple linked ──────────────────────────────────────────────

class _NoCoupleState extends StatelessWidget {
  const _NoCoupleState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notre Histoire',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                    color: AppColors.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.menu_book_rounded,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text('Connectez-vous avec votre partenaire',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 10),
              const Text(
                'Liez vos comptes pour écrire et partager vos anecdotes ensemble.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Aller au profil pour lier',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── History view (coupled) ────────────────────────────────────────

class _HistoireView extends StatefulWidget {
  final String coupleId;
  const _HistoireView({required this.coupleId});

  @override
  State<_HistoireView> createState() => _HistoireViewState();
}

class _HistoireViewState extends State<_HistoireView> {
  final _controller = TextEditingController();
  bool _sending = false;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await CoupleService.addStory(widget.coupleId, text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(StoryEntry entry) async {
    if (entry.authorUid != _myUid) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce souvenir ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Cette entrée sera supprimée définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CoupleService.deleteStory(widget.coupleId, entry.id);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          children: [
            Text('Notre Histoire',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text('souvenirs partagés',
                style: TextStyle(color: AppColors.textMedium, fontSize: 11)),
          ],
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<StoryEntry>>(
              stream: CoupleService.storiesStream(widget.coupleId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) {
                  return const _EmptyStories();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _StoryCard(
                    entry: entries[i],
                    isMe: entries[i].authorUid == _myUid,
                    onDelete: () => _confirmDelete(entries[i]),
                  ),
                );
              },
            ),
          ),
          _ComposeBar(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────

class _EmptyStories extends StatelessWidget {
  const _EmptyStories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.auto_stories_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text('Commencez votre histoire',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text(
            'Écrivez vos anecdotes,\nvos moments précieux, vos souvenirs…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Story card ────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final StoryEntry entry;
  final bool isMe;
  final VoidCallback onDelete;

  const _StoryCard({
    required this.entry,
    required this.isMe,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initial = entry.authorName.isNotEmpty
        ? entry.authorName[0].toUpperCase()
        : '?';
    final borderColor = isMe ? AppColors.primary : AppColors.accent;
    final avatarBg = isMe ? AppColors.primarySoft : AppColors.accentLight;
    final avatarText = isMe ? AppColors.primary : AppColors.accent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarBg,
              child: Text(initial,
                  style: TextStyle(
                      color: avatarText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textDark)),
                      const Spacer(),
                      Text(_formatDate(entry.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textLight)),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.textLight),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(entry.text,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─── Compose bar ───────────────────────────────────────────────────

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _ComposeBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Écrivez un souvenir, une anecdote…',
                hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sending ? AppColors.textLight : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
