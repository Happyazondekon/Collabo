import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../services/conversation_service.dart';
import '../services/couple_service.dart';
import '../utils/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'love_chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;
  bool _partnerEnsured = false;
  StreamSubscription<UserProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    // Ensure the couple partner always appears in the list
    _profileSub = CoupleService.myProfileStream().listen((profile) {
      if (!_partnerEnsured && profile?.partnerUid != null) {
        _partnerEnsured = true;
        _ensurePartnerConversation(profile!);
      }
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _ensurePartnerConversation(UserProfile profile) async {
    if (profile.partnerUid == null) return;
    try {
      final partner = await CoupleService.getPartnerProfile(profile.partnerUid!);
      if (partner == null) return;
      final name = partner.pseudo?.isNotEmpty == true
          ? partner.pseudo!
          : partner.displayName ?? 'Partenaire';
      await ConversationService.ensureConversationWith(
          profile.partnerUid!, name, partner.avatarUrl);
    } catch (_) {}
  }

  // ── Start new conversation dialog ─────────────────────────────

  Future<void> _showNewConversationDialog() async {
    String email = '';
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouvelle conversation',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email de la personne',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: errorMsg,
                ),
                onChanged: (v) {
                  email = v;
                  if (errorMsg != null) setDialogState(() => errorMsg = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                try {
                  final result =
                      await ConversationService.startConversationByEmail(email);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _openConversation(result.conversationId, result.partnerUid,
                      result.partnerName, result.partnerAvatarUrl);
                } catch (e) {
                  setDialogState(() => errorMsg = e.toString());
                }
              },
              child: const Text('Rechercher'),
            ),
          ],
        ),
      ),
    );
  }

  void _openConversation(
      String convId, String partnerUid, String partnerName, String? partnerAvatar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoveChatScreen(
          conversationId: convId,
          partnerUid: partnerUid,
          partnerName: partnerName,
          partnerAvatarUrl: partnerAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chat_bubble_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Messages',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  const Spacer(),
                  IconButton(
                    onPressed: _showNewConversationDialog,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
                    ),
                    tooltip: 'Nouvelle conversation',
                  ),
                ],
              ),
            ),

            // ── Conversations list ───────────────────────────────
            Expanded(
              child: StreamBuilder<List<ConversationModel>>(
                stream: ConversationService.myConversationsStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  final convs = snap.data ?? [];
                  if (convs.isEmpty) return _buildEmptyState();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                    itemCount: convs.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 76, endIndent: 20,
                        color: Color(0xFFF0E0E8)),
                    itemBuilder: (_, i) {
                      final conv = convs[i];
                      final uid = _myUid ?? '';
                      final unread = conv.myUnread(uid);
                      return _ConversationTile(
                        conv: conv,
                        myUid: uid,
                        unreadCount: unread,
                        onTap: () => _openConversation(
                          conv.id,
                          conv.partnerUid(uid),
                          conv.partnerName(uid),
                          conv.partnerAvatar(uid),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/couple_chat.webp',
            width: 170,
            height: 170,
          ),
          const SizedBox(height: 12),
          const Text('Aucun message',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Démarrez une conversation\nen appuyant sur ✏️',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

// ─── Conversation tile ────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  final String myUid;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conv,
    required this.myUid,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conv.partnerName(myUid);
    final avatar = conv.partnerAvatar(myUid);
    final avatarData = conv.partnerAvatarData(myUid);
    final lastMsg = conv.lastMessage;
    final time = conv.lastMessageAt;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                UserAvatar(
                  name: name,
                  avatarUrl: avatar,
                  avatarData: avatarData,
                  radius: 26,
                  backgroundColor: AppColors.primarySoft,
                  textColor: AppColors.primary,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textDark)),
                  const SizedBox(height: 3),
                  Text(
                    lastMsg ?? 'Aucun message encore',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: hasUnread
                            ? AppColors.textDark
                            : AppColors.textMedium,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal),
                  ),
                ],
              ),
            ),
            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(_formatTime(time),
                      style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textLight)),
                const SizedBox(height: 4),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
