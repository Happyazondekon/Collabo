import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../utils/app_theme.dart';

// ── Admin guard ────────────────────────────────────────────────────
// Only the account heyhappyproject@gmail.com can reach this screen.
// The guard is enforced both here and in auth_wrapper.dart.
const _adminEmail = 'heyhappyproject@gmail.com';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Stats are refreshed each time the Overview tab is shown
  AdminStats? _stats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 0 && mounted) _refreshStats();
    });
    _refreshStats();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    final s = await SocialService.getStats();
    if (!mounted) return;
    setState(() {
      _stats = s;
      _loadingStats = false;
    });
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  // ─── Confirm + delete any post ──────────────────────────────────
  Future<void> _confirmDeletePost(String postId,
      {String? reportId}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce post ?'),
        content:
            const Text('Cette action est irréversible pour tous les utilisateurs.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SocialService.adminDeletePost(postId);
    if (reportId != null) {
      await SocialService.resolveReport(reportId, deleted: true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post supprimé.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _resolveReportOnly(String reportId) async {
    await SocialService.resolveReport(reportId, deleted: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Signalement résolu.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Admin — Collabo',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Rafraîchir les stats',
            onPressed: _refreshStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Tableau'),
            Tab(icon: Icon(Icons.flag_rounded), text: 'Signalements'),
            Tab(icon: Icon(Icons.article_rounded), text: 'Posts'),
            Tab(icon: Icon(Icons.group_rounded), text: 'Utilisateurs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(stats: _stats, loading: _loadingStats),
          _ReportsTab(onDeletePost: _confirmDeletePost,
              onResolveOnly: _resolveReportOnly),
          _PostsTab(onDeletePost: _confirmDeletePost),
          const _UsersTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 1 — Tableau de bord (stats)
// ═══════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final AdminStats? stats;
  final bool loading;
  const _OverviewTab({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final s = stats;
    if (s == null) {
      return const Center(child: Text('Impossible de charger les stats.'));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader('Vue d\'ensemble', Icons.bar_chart_rounded),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.3,
            children: [
              _StatCard(
                icon: Icons.people_alt_rounded,
                label: 'Utilisateurs',
                value: '${s.totalUsers}',
                color: AppColors.primary,
              ),
              _StatCard(
                icon: Icons.favorite_rounded,
                label: 'Couples',
                value: '${s.totalCouples}',
                color: AppColors.accent,
              ),
              _StatCard(
                icon: Icons.article_rounded,
                label: 'Posts',
                value: '${s.totalPosts}',
                color: const Color(0xFF10B981),
              ),
              _StatCard(
                icon: Icons.flag_rounded,
                label: 'Signalements ouverts',
                value: '${s.openReports}',
                color: s.openReports > 0
                    ? Colors.red.shade600
                    : AppColors.textLight,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader('Détails', Icons.info_outline_rounded),
          const SizedBox(height: 12),
          _InfoRow('Total signalements',
              '${s.totalReports}', Icons.report_rounded),
          _InfoRow('Taux de couplage',
              s.totalUsers == 0
                  ? '—'
                  : '${((s.totalCouples * 2 / s.totalUsers) * 100).toStringAsFixed(0)} %',
              Icons.link_rounded),
          const SizedBox(height: 24),
          _SectionHeader('Compte admin', Icons.shield_rounded),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? _adminEmail,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 2 — Signalements
// ═══════════════════════════════════════════════════════════════════

class _ReportsTab extends StatefulWidget {
  final Future<void> Function(String postId, {String? reportId}) onDeletePost;
  final Future<void> Function(String reportId) onResolveOnly;
  const _ReportsTab(
      {required this.onDeletePost, required this.onResolveOnly});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    setState(() => _showResolved = !_showResolved),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showResolved
                        ? AppColors.accent
                        : AppColors.accentLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _showResolved ? 'Voir ouverts' : 'Voir résolus',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showResolved
                            ? Colors.white
                            : AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminReport>>(
            stream: SocialService.reportsStream(
                onlyOpen: !_showResolved),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary));
              }
              final reports = snap.data ?? [];
              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 56,
                          color: Colors.green.shade300),
                      const SizedBox(height: 12),
                      Text(
                        _showResolved
                            ? 'Aucun signalement résolu'
                            : 'Aucun signalement ouvert 🎉',
                        style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 15),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 14),
                itemCount: reports.length,
                itemBuilder: (ctx, i) => _ReportCard(
                  report: reports[i],
                  onDelete: () => widget.onDeletePost(
                    reports[i].postId,
                    reportId: reports[i].id,
                  ),
                  onResolve: () =>
                      widget.onResolveOnly(reports[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final AdminReport report;
  final VoidCallback onDelete;
  final VoidCallback onResolve;
  const _ReportCard(
      {required this.report,
      required this.onDelete,
      required this.onResolve});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: report.resolved
                ? Colors.grey.shade200
                : Colors.red.shade100,
            width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: report.resolved
                  ? Colors.grey.shade50
                  : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_rounded,
                    size: 16,
                    color: report.resolved
                        ? AppColors.textLight
                        : Colors.red.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.reason.isNotEmpty
                        ? report.reason
                        : 'Raison non précisée',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: report.resolved
                            ? AppColors.textMedium
                            : Colors.red.shade700),
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yy HH:mm')
                      .format(report.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          // Post preview
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('feed_posts')
                .doc(report.postId)
                .get(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Chargement du post...',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                );
              }
              if (!snap.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('⚠️ Post déjà supprimé',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                );
              }
              final d =
                  snap.data!.data() as Map<String, dynamic>;
              final content = d['content'] as String? ?? '';
              final author =
                  d['authorName'] as String? ?? 'Inconnu';
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Par $author',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium)),
                    const SizedBox(height: 4),
                    Text(
                      content.length > 200
                          ? '${content.substring(0, 200)}…'
                          : content,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark),
                    ),
                  ],
                ),
              );
            },
          ),
          // Actions
          if (!report.resolved)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.check_rounded,
                          size: 16),
                      label: const Text('Résoudre',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(
                            color: Colors.green.shade300),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_rounded,
                          size: 16),
                      label: const Text('Supprimer',
                          style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 3 — Tous les posts
// ═══════════════════════════════════════════════════════════════════

class _PostsTab extends StatefulWidget {
  final Future<void> Function(String postId, {String? reportId}) onDeletePost;
  const _PostsTab({required this.onDeletePost});

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher par auteur ou contenu…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textLight, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textLight),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FeedPost>>(
            stream: SocialService.allPostsStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary));
              }
              var posts = snap.data ?? [];
              if (_query.isNotEmpty) {
                posts = posts
                    .where((p) =>
                        p.content.toLowerCase().contains(_query) ||
                        p.authorName.toLowerCase().contains(_query))
                    .toList();
              }
              if (posts.isEmpty) {
                return const Center(
                    child: Text('Aucun post trouvé.',
                        style: TextStyle(color: AppColors.textMedium)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 14),
                itemCount: posts.length,
                itemBuilder: (ctx, i) => _AdminPostCard(
                  post: posts[i],
                  onDelete: () =>
                      widget.onDeletePost(posts[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onDelete;
  const _AdminPostCard({required this.post, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: post.authorAvatar != null
                    ? _avatarProvider(post.authorAvatar!)
                    : null,
                child: post.authorAvatar == null
                    ? Text(
                        post.authorName.isNotEmpty
                            ? post.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textDark)),
                    Text(
                      DateFormat('dd/MM/yy HH:mm')
                          .format(post.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 20),
                tooltip: 'Supprimer ce post',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.content.length > 250
                  ? '${post.content.substring(0, 250)}…'
                  : post.content,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textDark, height: 1.4),
            ),
          ],
          if (post.imageData != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(post.imageData!),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _MiniStat(Icons.favorite_rounded, '${post.likedBy.length}'),
              const SizedBox(width: 12),
              _MiniStat(
                  Icons.chat_bubble_outline_rounded, '${post.commentCount}'),
              const SizedBox(width: 12),
              _MiniStat(
                  Icons.repeat_rounded, '${post.repostCount}'),
            ],
          ),
        ],
      ),
    );
  }

  ImageProvider _avatarProvider(String raw) {
    try {
      final bytes = base64Decode(raw);
      return MemoryImage(bytes);
    } catch (_) {
      return NetworkImage(raw) as ImageProvider;
    }
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MiniStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TAB 4 — Utilisateurs
// ═══════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Rechercher un utilisateur…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textLight, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.textLight),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminUser>>(
            stream: SocialService.allUsersStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary));
              }
              var users = snap.data ?? [];
              if (_query.isNotEmpty) {
                users = users
                    .where((u) =>
                        u.displayName
                            .toLowerCase()
                            .contains(_query) ||
                        (u.pseudo?.toLowerCase().contains(_query) ??
                            false) ||
                        (u.email?.toLowerCase().contains(_query) ??
                            false))
                    .toList();
              }
              if (users.isEmpty) {
                return const Center(
                    child: Text('Aucun utilisateur trouvé.',
                        style: TextStyle(color: AppColors.textMedium)));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 14),
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _UserTile(users[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUser user;
  const _UserTile(this.user);

  @override
  Widget build(BuildContext context) {
    final name =
        user.pseudo?.isNotEmpty == true ? user.pseudo! : user.displayName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primarySoft,
            backgroundImage: user.avatarUrl != null
                ? _avatarProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 14))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textDark)),
                    ),
                    if (user.email?.toLowerCase() == _adminEmail) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                if (user.email != null)
                  Text(user.email!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          if (user.coupleId != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.favorite_rounded,
                      size: 11, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text('En couple',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider _avatarProvider(String raw) {
    try {
      final bytes = base64Decode(raw);
      return MemoryImage(bytes);
    } catch (_) {
      return NetworkImage(raw) as ImageProvider;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared small widgets
// ═══════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textLight),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }
}
