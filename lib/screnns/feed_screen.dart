import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../services/social_service.dart';
import '../widgets/user_avatar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        onPosted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post publié !'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                const Text('Communauté',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: const Icon(Icons.add_box_rounded,
                      color: AppColors.primary, size: 28),
                  onPressed: _openCreatePost,
                ),
              ),
            ],
          ),
          StreamBuilder<List<FeedPost>>(
            stream: SocialService.feedStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final posts = snapshot.data ?? [];

              if (posts.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyFeed(onPost: _openCreatePost),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PostCard(
                        post: posts[i],
                        myUid: _myUid ?? '',
                      ),
                    ),
                    childCount: posts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePost,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text('Publier',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final FeedPost post;
  final String myUid;

  const _PostCard({required this.post, required this.myUid});

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: post, myUid: myUid),
    );
  }

  void _showRepostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RepostSheet(post: post),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostOptionsSheet(post: post, myUid: myUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liked = post.likedBy.contains(myUid);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                _Avatar(
                  name: post.authorName,
                  url: post.authorAvatar,
                  data: post.authorAvatarData,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textDark)),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                if (post.isRepost)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat_rounded,
                            size: 12, color: AppColors.accent),
                        SizedBox(width: 3),
                        Text('Repost',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showOptions(context),
                  child: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.textLight, size: 20),
                ),
              ],
            ),
          ),

          // ── Repost origin card ───────────────────────────────
          if (post.isRepost && post.repostOfContent != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.repostOfAuthorName != null)
                      Text(post.repostOfAuthorName!,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent)),
                    const SizedBox(height: 2),
                    Text(
                      post.repostOfContent!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Content ──────────────────────────────────────────
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                post.content,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textDark,
                    height: 1.45),
              ),
            ),

          // ── Image ────────────────────────────────────────────
          if (post.imageData != null || post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: post.imageData != null
                  ? Image.memory(
                      base64Decode(post.imageData!),
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      post.imageUrl!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            ),
          ],

          // ── Actions ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Row(
              children: [
                _ActionButton(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  count: post.likedBy.length,
                  color: liked ? Colors.red.shade400 : AppColors.textMedium,
                  onTap: () => SocialService.toggleLike(post.id),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: post.commentCount,
                  color: AppColors.textMedium,
                  onTap: () => _showComments(context),
                ),
                const SizedBox(width: 4),
                _ActionButton(
                  icon: Icons.repeat_rounded,
                  count: post.repostCount,
                  color: AppColors.textMedium,
                  onTap: () => _showRepostSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Comments sheet ───────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final FeedPost post;
  final String myUid;
  const _CommentsSheet({required this.post, required this.myUid});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final err = await SocialService.addComment(
        postId: widget.post.id, content: text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Commentaires',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const Divider(height: 20),
            Expanded(
              child: StreamBuilder<List<FeedComment>>(
                stream: SocialService.commentsStream(widget.post.id),
                builder: (_, snap) {
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text('Aucun commentaire pour l\'instant.',
                          style: TextStyle(
                              color: AppColors.textMedium, fontSize: 13)),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (_, i) =>
                        _CommentTile(comment: comments[i], myUid: widget.myUid),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Écrire un commentaire…',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
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
  final FeedComment comment;
  final String myUid;
  const _CommentTile({required this.comment, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isMe = comment.authorUid == myUid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _Avatar(name: comment.authorName, url: comment.authorAvatar, data: comment.authorAvatarData, size: 32),
            const SizedBox(width: 8),
          ],
          if (isMe) const Spacer(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(comment.authorName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  Text(comment.content,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark)),
                ],
              ),
            ),
          ),
          if (!isMe) const Spacer(),
          if (isMe) ...[
            const SizedBox(width: 8),
            _Avatar(name: comment.authorName, url: comment.authorAvatar, data: comment.authorAvatarData, size: 32),
          ],
        ],
      ),
    );
  }
}

// ─── Repost sheet ─────────────────────────────────────────────────

class _RepostSheet extends StatefulWidget {
  final FeedPost post;
  const _RepostSheet({required this.post});

  @override
  State<_RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends State<_RepostSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _repost() async {
    setState(() => _sending = true);
    final err = await SocialService.repost(
        original: widget.post, comment: _ctrl.text);
    if (!mounted) return;
    Navigator.pop(context);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reposté !'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Reposter',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),
          // Original post preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.post.authorName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(
                  widget.post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Optional comment
          TextField(
            controller: _ctrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Ajouter un commentaire (optionnel)…',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _repost,
              icon: const Icon(Icons.repeat_rounded),
              label: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Reposter',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Post options sheet ───────────────────────────────────────────

class _PostOptionsSheet extends StatelessWidget {
  final FeedPost post;
  final String myUid;
  const _PostOptionsSheet({required this.post, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isOwner = post.authorUid == myUid;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          if (isOwner) ...[
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer ce post',
              color: Colors.red.shade400,
              onTap: () async {
                Navigator.pop(context);
                await SocialService.deletePost(post.id);
              },
            ),
          ] else ...[
            _OptionTile(
              icon: Icons.flag_outlined,
              label: 'Signaler ce post',
              color: Colors.orange.shade700,
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context);
              },
            ),
          ],
          _OptionTile(
            icon: Icons.close_rounded,
            label: 'Annuler',
            color: AppColors.textMedium,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasons = [
      'Contenu inapproprié',
      'Propos haineux',
      'Spam',
      'Autre',
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Signaler ce post',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r,
                      style: const TextStyle(fontSize: 14)),
                  onTap: () async {
                    Navigator.pop(context);
                    await SocialService.reportPost(post.id, r);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post signalé. Merci.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title:
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

// ─── Create post sheet ────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  final VoidCallback onPosted;
  const _CreatePostSheet({required this.onPosted});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _sending = false;
  int _charCount = 0;
  String? _imageData;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() => _charCount = _ctrl.text.length);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, imageQuality: 75, maxWidth: 1080);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    setState(() => _imageData = base64Encode(bytes));
  }

  Future<void> _publish() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final err = await SocialService.createPost(
        content: text, imageData: _imageData);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
    widget.onPosted();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Nouveau post',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const Spacer(),
              Text(
                '$_charCount / 500',
                style: TextStyle(
                    fontSize: 12,
                    color: _charCount > 450
                        ? Colors.red.shade400
                        : AppColors.textLight),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            maxLength: 500,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'Partagez un moment, une pensée, un souvenir… 💕',
              hintStyle:
                  const TextStyle(color: AppColors.textLight, fontSize: 14),
              filled: true,
              fillColor: AppColors.background,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 14),
          // ── Image picker buttons ──────────────────────────────
          Row(
            children: [
              _ImageSourceButton(
                icon: Icons.photo_library_rounded,
                label: 'Galerie',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(width: 10),
              _ImageSourceButton(
                icon: Icons.camera_alt_rounded,
                label: 'Caméra',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
          // ── Image preview ─────────────────────────────────────
          if (_imageData != null) ...[
            const SizedBox(height: 12),
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    base64Decode(_imageData!),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageData = null),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Publier',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image source button ──────────────────────────────────────────

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImageSourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ─── Empty feed ───────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  final VoidCallback onPost;
  const _EmptyFeed({required this.onPost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/couple_feed.webp',
              width: 170,
              height: 170,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun post pour l\'instant',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à partager un moment avec la communauté Collabo !',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textMedium, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onPost,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Créer le premier post',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final String? data;
  final double size;
  const _Avatar({required this.name, this.url, this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      name: name,
      avatarUrl: url,
      avatarData: data,
      radius: size / 2,
      backgroundColor: AppColors.primarySoft,
      textColor: AppColors.primary,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.count,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
