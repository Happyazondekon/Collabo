import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message_model.dart';
import '../services/conversation_service.dart';
import '../services/couple_service.dart';
import '../utils/app_theme.dart';

class LoveChatScreen extends StatefulWidget {
  final String conversationId;
  final String? partnerUid;
  final String? partnerName;
  final String? partnerAvatarUrl;

  const LoveChatScreen({
    super.key,
    required this.conversationId,
    this.partnerUid,
    this.partnerName,
    this.partnerAvatarUrl,
  });

  @override
  State<LoveChatScreen> createState() => _LoveChatScreenState();
}

class _LoveChatScreenState extends State<LoveChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _viewOnceMode = false;
  int _viewOnceDuration = 15; // seconds, chosen by sender
  bool _sending = false;

  UserProfile? _myProfile;
  String _resolvedPartnerName = 'Mon amour';
  String? _resolvedPartnerAvatarUrl;

  @override
  void initState() {
    super.initState();
    CoupleService.myProfileStream().first.then((p) {
      if (mounted) setState(() => _myProfile = p);
    });
    // Resolve partner name + avatar from Firestore if not provided
    if (widget.partnerUid != null) {
      CoupleService.getPartnerProfile(widget.partnerUid!).then((p) {
        if (mounted && p != null) {
          setState(() {
            _resolvedPartnerName =
                p.pseudo ?? p.displayName ?? widget.partnerName ?? 'Mon amour';
            _resolvedPartnerAvatarUrl =
                widget.partnerAvatarUrl ?? p.avatarUrl;
          });
        }
      });
    } else {
      _resolvedPartnerName = widget.partnerName ?? 'Mon amour';
      _resolvedPartnerAvatarUrl = widget.partnerAvatarUrl;
    }
    // Scroll to bottom when keyboard opens
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _scrollToBottom(delay: 300);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({int delay = 0}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    await ConversationService.sendText(widget.conversationId, text);
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (picked == null) return;
    setState(() => _sending = true);
    await ConversationService.sendImage(
        widget.conversationId, File(picked.path), _viewOnceMode,
        viewOnceDuration: _viewOnceDuration);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            // View-once toggle inside sheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _viewOnceMode
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _viewOnceMode
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: _viewOnceMode
                          ? AppColors.primary
                          : AppColors.textLight,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vue unique',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _viewOnceMode
                                  ? AppColors.primary
                                  : AppColors.textDark,
                            ),
                          ),
                          const Text(
                            'Disparaît après avoir été vue',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _viewOnceMode,
                      onChanged: (v) {
                        setState(() => _viewOnceMode = v);
                        Navigator.pop(context);
                        _showImageOptions();
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            // Duration selector (shown only when view-once is active)
            if (_viewOnceMode) ...
              [
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Durée de visualisation',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMedium)),
                      const SizedBox(height: 8),
                      Row(
                        children: [5, 10, 15, 30].map((s) {
                          final selected = _viewOnceDuration == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _viewOnceDuration = s);
                                Navigator.pop(context);
                                _showImageOptions();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('${s}s',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: selected
                                            ? Colors.white
                                            : AppColors.textDark)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: 16),
            _SheetOption(
              icon: Icons.photo_library_rounded,
              label: 'Galerie',
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            _SheetOption(
              icon: Icons.camera_alt_rounded,
              label: 'Appareil photo',
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0F5),
      body: Column(
        children: [
          _ChatAppBar(
            partnerName: _resolvedPartnerName,
            partnerAvatarUrl: _resolvedPartnerAvatarUrl,
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ConversationService.messagesStream(widget.conversationId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) return const _EmptyChat();

                // Reset my unread count for this conversation
                ConversationService.resetUnread(widget.conversationId);

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderUid == _myProfile?.uid;
                    final showDate = i == 0 ||
                        messages[i].createdAt
                                .difference(messages[i - 1].createdAt)
                                .inMinutes >
                            30;

                    return Column(
                      children: [
                        if (showDate)
                          _DateChip(date: msg.createdAt),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          myAvatarUrl: _myProfile?.avatarUrl,
                          partnerAvatarUrl: _resolvedPartnerAvatarUrl,
                          onReact: (emoji) => ConversationService.react(
                              widget.conversationId, msg.id, emoji),
                          onDelete: isMe
                              ? () => ConversationService.deleteMessage(
                                  widget.conversationId, msg.id)
                              : null,
                          onViewOnce: () =>
                              ConversationService.markViewOnceViewed(
                                  widget.conversationId, msg.id),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _ChatInputBar(
            controller: _textCtrl,
            focusNode: _focusNode,
            viewOnceMode: _viewOnceMode,
            sending: _sending,
            onSend: _sendText,
            onImageTap: _showImageOptions,
            onViewOnceToggle: () =>
                setState(() => _viewOnceMode = !_viewOnceMode),
          ),
        ],
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final String partnerName;
  final String? partnerAvatarUrl;

  const _ChatAppBar(
      {required this.partnerName, required this.partnerAvatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFFE8547A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              _AvatarWithRing(
                  url: partnerAvatarUrl, name: partnerName, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'En ligne',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 22),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar with ring ─────────────────────────────────────────────────

class _AvatarWithRing extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _AvatarWithRing(
      {required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size + 4,
      height: size + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withValues(alpha: 0.3),
        backgroundImage: url != null ? NetworkImage(url!) : null,
        child: url == null
            ? Text(initial,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.4))
            : null,
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                color: AppColors.primary, size: 44),
          ),
          const SizedBox(height: 20),
          const Text('Commencez à écrire…',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text('Envoyez votre premier message ❤️',
              style: TextStyle(fontSize: 14, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

// ─── Date chip ────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return "Aujourd'hui";
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    const months = [
      'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6)
            ],
          ),
          child: Text(_label(),
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final String? myAvatarUrl;
  final String? partnerAvatarUrl;
  final Future<void> Function(String?) onReact;
  final VoidCallback? onDelete;
  final VoidCallback onViewOnce;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.myAvatarUrl,
    required this.partnerAvatarUrl,
    required this.onReact,
    required this.onDelete,
    required this.onViewOnce,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popCtrl;
  late final Animation<double> _popAnim;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _popAnim = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);
    _popCtrl.forward();
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  void _showOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // Reactions row
              _ReactionPicker(
                current: widget.message.reaction,
                onSelect: (emoji) {
                  Navigator.pop(ctx);
                  widget.onReact(emoji);
                },
                showCard: false,
              ),
              if (widget.onDelete != null) ...
                [
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                    title: const Text('Supprimer le message',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete!();
                    },
                  ),
                ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final msg = widget.message;

    if (msg.type == MessageType.viewOnce) {
      // Already viewed
      if (msg.viewedByPartner && !widget.isMe) {
        return _ViewedOnceIndicator();
      }
      // Sender side: show thumbnail with flame overlay
      if (widget.isMe) {
        return _ViewOnceSentBubble(imageData: msg.imageData ?? '');
      }
      // Recipient: tap to open fullscreen
      return GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _ViewOnceFullscreenPage(
                imageData: msg.imageData ?? '',
                duration: msg.viewOnceDuration,
                onDone: widget.onViewOnce,
              ),
            ),
          );
        },
        child: _ViewOnceTapPrompt(),
      );
    }

    if (msg.type == MessageType.image) {
      return _ImageBubble(
        imageData: msg.imageData ?? '',
        isMe: widget.isMe,
      );
    }

    // Text
    return Text(
      msg.text ?? '',
      style: TextStyle(
        color: widget.isMe ? Colors.white : AppColors.textDark,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final hasReaction = widget.message.reaction?.isNotEmpty == true;
    final avatarUrl =
        isMe ? widget.myAvatarUrl : widget.partnerAvatarUrl;
    final initial = isMe ? 'M' : (widget.partnerAvatarUrl != null ? '' : 'P');

    return ScaleTransition(
      scale: _popAnim,
      child: GestureDetector(
        onLongPress: _showOptions,
        child: Padding(
          padding: EdgeInsets.only(
            top: 3,
            bottom: hasReaction ? 18 : 4,
            left: isMe ? 60 : 0,
            right: isMe ? 0 : 60,
          ),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.accentLight,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(initial,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent))
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: widget.message.type == MessageType.text
                        ? const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [
                                AppColors.primary,
                                Color(0xFFE8547A)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isMe
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildContent(),
                  ),
                  // Reaction badge
                  if (hasReaction)
                    Positioned(
                      bottom: -14,
                      right: isMe ? 6 : null,
                      left: isMe ? null : 6,
                      child: GestureDetector(
                        onTap: () => widget.onReact(null), // remove
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Text(widget.message.reaction!,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                ],
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? const Text('M',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary))
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Image Bubble ─────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final String imageData;
  final bool isMe;

  const _ImageBubble({required this.imageData, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(imageData);
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        child: Image.memory(
          bytes,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 220,
            height: 220,
            color: AppColors.primarySoft,
            child: const Icon(Icons.broken_image_rounded,
                color: AppColors.textLight, size: 40),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _FullScreenImage(imageData: imageData),
      ),
    );
  }
}

// ─── Full Screen Image ────────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final String imageData;
  const _FullScreenImage({required this.imageData});

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(imageData);
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Hero(
            tag: imageData.hashCode.toString(),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─── View-Once widgets ───────────────────────────────────────────────

class _ViewOnceTapPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: Colors.white, size: 28),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vue unique',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text('Appuyer pour voir',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewOnceSentBubble extends StatelessWidget {
  final String imageData;
  const _ViewOnceSentBubble({required this.imageData});

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(imageData);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            bytes,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            color: Colors.black45,
            colorBlendMode: BlendMode.darken,
          ),
        ),
        const Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 32),
              SizedBox(height: 4),
              Text('Envoyée',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ViewOnceFullscreenPage extends StatefulWidget {
  final String imageData;
  final int duration;
  final VoidCallback onDone;

  const _ViewOnceFullscreenPage({
    required this.imageData,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_ViewOnceFullscreenPage> createState() =>
      _ViewOnceFullscreenPageState();
}

class _ViewOnceFullscreenPageState extends State<_ViewOnceFullscreenPage>
    with SingleTickerProviderStateMixin {
  late int _remaining;
  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _progressCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..forward();
    _progressCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        widget.onDone();
        Navigator.pop(context);
      }
    });
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, widget.duration));
      if (_remaining > 0) _tick();
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(widget.imageData);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen image
          Center(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          // Top overlay: title + timer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Text('Vue unique',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text('${_remaining}s',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, __) => LinearProgressIndicator(
                value: 1.0 - _progressCtrl.value,
                minHeight: 5,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewedOnceIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_rounded,
              color: AppColors.textLight, size: 16),
          SizedBox(width: 6),
          Text('Photo vue',
              style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Reaction Picker ─────────────────────────────────────────────────

class _ReactionPicker extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onSelect;
  final bool showCard;

  static const _emojis = ['❤️', '😍', '😂', '😮', '😢', '🔥', '💯', '🥰'];

  const _ReactionPicker(
      {required this.current, required this.onSelect, this.showCard = true});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _emojis.map((e) {
          final isSelected = e == current;
          return GestureDetector(
            onTap: () => onSelect(isSelected ? null : e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isSelected ? 44 : 36,
              height: isSelected ? 44 : 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySoft
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(e,
                    style: TextStyle(fontSize: isSelected ? 24 : 20)),
              ),
            ),
          );
        }).toList(),
      ),
    );
    if (!showCard) return row;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: row,
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool viewOnceMode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onImageTap;
  final VoidCallback onViewOnceToggle;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.viewOnceMode,
    required this.sending,
    required this.onSend,
    required this.onImageTap,
    required this.onViewOnceToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image button
          GestureDetector(
            onTap: onImageTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: viewOnceMode
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                viewOnceMode
                    ? Icons.local_fire_department_rounded
                    : Icons.photo_rounded,
                color: viewOnceMode ? AppColors.primary : AppColors.textMedium,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textDark),
                decoration: const InputDecoration(
                  hintText: 'Écrire un message…',
                  hintStyle:
                      TextStyle(color: AppColors.textLight, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: sending
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.primary, Color(0xFFE8547A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: sending ? AppColors.textLight : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: sending
                    ? null
                    : [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet option ─────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}
