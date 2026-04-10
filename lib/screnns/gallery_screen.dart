import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/gallery_service.dart';
import '../utils/app_theme.dart';

class GalleryScreen extends StatefulWidget {
  final String? coupleId;
  const GalleryScreen({super.key, this.coupleId});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _service = GalleryService();
  bool _uploading = false;

  String? get _coupleId => widget.coupleId;

  Future<void> _addPhoto() async {
    String title = '';
    DateTime photoDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter une photo',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Titre (ex: Notre premier voyage)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => title = v,
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: photoDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    helpText: 'Date de la photo',
                    builder: (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                        dialogTheme: const DialogThemeData(
                            backgroundColor: Colors.white),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setDialog(() => photoDate = picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Date : ${photoDate.day}/${photoDate.month}/${photoDate.year}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const Spacer(),
                      const Text('Modifier',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Choisir la photo',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || _coupleId == null) return;

    setState(() => _uploading = true);
    await _service.pickAndAddPhoto(_coupleId!,
        title: title, photoDate: photoDate);
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _confirmDelete(GalleryPhoto photo) async {
    if (_coupleId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer cette photo ?'),
        content: Text('"${photo.title}" sera supprimée définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deletePhoto(_coupleId!, photo.id);
    }
  }

  void _openPhoto(GalleryPhoto photo) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _FullScreenPhoto(photo: photo)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notre Galerie',
          style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        centerTitle: true,
      ),
      floatingActionButton: _coupleId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _uploading ? null : _addPhoto,
              backgroundColor: AppColors.primary,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_rounded,
                      color: Colors.white),
              label: Text(_uploading ? 'Envoi…' : 'Ajouter',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      body: _coupleId == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_rounded,
                        size: 64, color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Galerie partagée',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    SizedBox(height: 8),
                    Text(
                      'Connectez-vous à votre partenaire pour partager vos photos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<GalleryPhoto>>(
              stream: _service.photosStream(_coupleId!),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                final photos = snap.data ?? [];
                if (photos.isEmpty) return _buildEmptyState();
                return _buildGrid(photos);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/couple_gallery.webp',
            width: 170,
            height: 170,
          ),
          const SizedBox(height: 12),
          const Text(
            'Vos souvenirs en photos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez vos photos clés pour\ngarder vos moments précieux ici',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textMedium),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addPhoto,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Ajouter une photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<GalleryPhoto> photos) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: photos.length,
        itemBuilder: (ctx, i) => _PhotoCard(
          photo: photos[i],
          onTap: () => _openPhoto(photos[i]),
          onLongPress: () => _confirmDelete(photos[i]),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final GalleryPhoto photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoCard(
      {required this.photo, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: photo.imageData.isNotEmpty
                    ? Image.memory(
                        base64Decode(photo.imageData),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primarySoft,
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.primary, size: 40),
                        ),
                      )
                    : Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.image_rounded,
                            color: AppColors.primary, size: 40),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(photo.photoDate ?? photo.savedAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _FullScreenPhoto extends StatelessWidget {
  final GalleryPhoto photo;
  const _FullScreenPhoto({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(photo.title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: photo.imageData.isNotEmpty
              ? Image.memory(
                  base64Decode(photo.imageData),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white,
                      size: 60),
                )
              : const Icon(Icons.image_rounded,
                  color: Colors.white, size: 60),
        ),
      ),
    );
  }
}
