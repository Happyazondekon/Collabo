import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/couple_service.dart';
import '../utils/app_theme.dart';
import '../widgets/user_avatar.dart';

const _kReactionEmojis = ['❤️', '😂', '😮', '😢', '🥰'];

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
      body: Container(
        color: AppColors.primary,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    size: 44, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Notre Histoire',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Liez vos comptes avec votre partenaire\npour écrire vos souvenirs ensemble.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.6),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text('Aller au profil',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const Spacer(),
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
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFF8),
      body: Column(
        children: [
          // ── Header ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: EdgeInsets.fromLTRB(8, topPad + 8, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notre Histoire',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Vos souvenirs partagés',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                      color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          // ── Story list ──
          Expanded(
            child: StreamBuilder<List<StoryEntry>>(
              stream: CoupleService.storiesStream(widget.coupleId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) return const _EmptyStories();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) => _StoryCard(
                    entry: entries[i],
                    isMe: entries[i].authorUid == _myUid,
                    myUid: _myUid,
                    coupleId: widget.coupleId,
                    onDelete: () => _confirmDelete(entries[i]),
                    isLast: i == entries.length - 1,
                  ),
                );
              },
            ),
          ),
          // ── Compose bar ──
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/couple_histoire.webp',
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ).createShader(b),
              child: const Text(
                'Commencez votre histoire',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Partagez vos anecdotes,\nvos moments précieux, vos souvenirs…',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textMedium, height: 1.65),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Story card ────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final StoryEntry entry;
  final bool isMe;
  final String myUid;
  final String coupleId;
  final VoidCallback onDelete;
  final bool isLast;

  const _StoryCard({
    required this.entry,
    required this.isMe,
    required this.myUid,
    required this.coupleId,
    required this.onDelete,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.authorName.isNotEmpty ? entry.authorName[0].toUpperCase() : '?';
    final gradColors = isMe
        ? const [Color(0xFFD0216E), Color(0xFFFF6BAA)]
        : const [Color(0xFF7C3AED), Color(0xFFAB6CF0)];
    final avatarBg = isMe ? AppColors.primarySoft : AppColors.accentLight;
    final avatarFg = isMe ? AppColors.primary : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline dot + line ──
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradColors),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradColors[0].withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gradColors[0].withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── Card ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: gradColors[0].withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top color strip ──
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: gradColors[0],
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Author row ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: gradColors),
                                shape: BoxShape.circle,
                              ),
                              child: UserAvatar(
                                name: entry.authorName,
                                avatarUrl: entry.authorAvatarUrl,
                                avatarData: entry.authorAvatarData,
                                radius: 16,
                                backgroundColor: avatarBg,
                                textColor: avatarFg,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(entry.authorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.textDark)),
                            ),
                            // Date pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primarySoft
                                    : AppColors.accentLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatDate(entry.createdAt),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isMe
                                        ? AppColors.primary
                                        : AppColors.accent),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onDelete,
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: AppColors.textLight),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ── Story text ──
                        Text(entry.text,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textDark,
                                height: 1.55)),
                        const SizedBox(height: 12),
                        Container(height: 1, color: const Color(0xFFF0EAF5)),
                        const SizedBox(height: 10),
                        // ── Reactions + comment button ──
                        Row(
                          children: [
                            ..._kReactionEmojis.map((emoji) {
                              final uids = entry.reactions[emoji] ?? [];
                              final reacted = uids.contains(myUid);
                              return Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: GestureDetector(
                                  onTap: () => CoupleService.toggleReaction(
                                      coupleId, entry.id, emoji),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: reacted
                                          ? (isMe
                                              ? AppColors.primarySoft
                                              : AppColors.accentLight)
                                          : const Color(0xFFF4EFF8),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                        color: reacted
                                            ? (isMe
                                                ? AppColors.primary
                                                : AppColors.accent)
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(emoji,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                        if (uids.isNotEmpty) ...[
                                          const SizedBox(width: 3),
                                          Text('${uids.length}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: reacted
                                                      ? (isMe
                                                          ? AppColors.primary
                                                          : AppColors.accent)
                                                      : AppColors.textMedium)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const Spacer(),
                            StreamBuilder<List<StoryComment>>(
                              stream: CoupleService.commentsStream(
                                  coupleId, entry.id),
                              builder: (ctx, snap) {
                                final count = snap.data?.length ?? 0;
                                return GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: ctx,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => _CommentsSheet(
                                      coupleId: coupleId,
                                      storyId: entry.id,
                                      myUid: myUid,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4EFF8),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          count > 0
                                              ? Icons.chat_bubble_rounded
                                              : Icons
                                                  .chat_bubble_outline_rounded,
                                          size: 13,
                                          color: count > 0
                                              ? AppColors.primary
                                              : AppColors.textMedium,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          count > 0
                                              ? '$count'
                                              : 'Commenter',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: count > 0
                                                  ? AppColors.primary
                                                  : AppColors.textMedium),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
// ─── Comments sheet ──────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String coupleId;
  final String storyId;
  final String myUid;

  const _CommentsSheet({
    required this.coupleId,
    required this.storyId,
    required this.myUid,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await CoupleService.addComment(widget.coupleId, widget.storyId, text);
    _ctrl.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Color(0xFFE0D6F0),
                  borderRadius: BorderRadius.circular(2)),
            ),
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ).createShader(b),
                    child: const Text('Commentaires',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF4EFF8), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0EAF5)),
            // ── Comments list ──
            Flexible(
              child: StreamBuilder<List<StoryComment>>(
                stream: CoupleService.commentsStream(
                    widget.coupleId, widget.storyId),
                builder: (ctx, snap) {
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: Color(0xFFDDD5ED)),
                          SizedBox(height: 12),
                          Text('Aucun commentaire pour l’instant.',
                              style: TextStyle(
                                  color: AppColors.textMedium, fontSize: 14)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    shrinkWrap: true,
                    itemCount: comments.length,
                    itemBuilder: (_, i) => _CommentTile(
                      comment: comments[i],
                      isMe: comments[i].authorUid == widget.myUid,
                    ),
                  );
                },
              ),
            ),
            // ── Input bar ──
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: Color(0xFFF0EAF5))),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EFF8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Ajouter un commentaire…',
                          hintStyle: TextStyle(
                              color: AppColors.textLight, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _sending ? AppColors.textLight : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final StoryComment comment;
  final bool isMe;
  const _CommentTile({required this.comment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            UserAvatar(
              name: comment.authorName,
              avatarUrl: comment.authorAvatarUrl,
              avatarData: comment.authorAvatarData,
              radius: 14,
              backgroundColor: AppColors.accentLight,
              textColor: AppColors.accent,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFFD0216E), Color(0xFFFF6BAA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : const Color(0xFFF4EFF8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: AppColors.accent)),
                    ),
                  Text(comment.text,
                      style: TextStyle(
                          fontSize: 13,
                          color: isMe ? Colors.white : AppColors.textDark,
                          height: 1.4)),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            UserAvatar(
              name: comment.authorName,
              avatarUrl: comment.authorAvatarUrl,
              avatarData: comment.authorAvatarData,
              radius: 14,
              backgroundColor: AppColors.primarySoft,
              textColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
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
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4EFF8),
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Écrivez un souvenir, une anecdote…',
                  hintStyle:
                      TextStyle(color: AppColors.textLight, fontSize: 13),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: sending ? AppColors.textLight : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
