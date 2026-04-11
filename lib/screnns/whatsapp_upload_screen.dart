import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/whatsapp_parser_service.dart';
import '../services/local_storage_service.dart';
import '../services/couple_service.dart';
import '../utils/app_theme.dart';

class WhatsAppUploadScreen extends StatefulWidget {
  const WhatsAppUploadScreen({super.key});

  @override
  State<WhatsAppUploadScreen> createState() => _WhatsAppUploadScreenState();
}

class _WhatsAppUploadScreenState extends State<WhatsAppUploadScreen> {
  _State _state = _State.idle;
  List<String> _words = [];
  Map<String, dynamic> _stats = {};
  String? _error;

  Future<void> _pickFile() async {
    setState(() {
      _state = _State.picking;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _state = _State.idle);
        return;
      }

      setState(() => _state = _State.parsing);

      final fileBytes = result.files.first.bytes;
      List<String> words;
      Map<String, dynamic> stats;

      if (fileBytes != null) {
        final content = String.fromCharCodes(fileBytes);
        words = WhatsAppParserService.parseFromText(content);
        stats = WhatsAppParserService.getStats(content);
      } else {
        final path = result.files.first.path;
        if (path == null) throw Exception('Impossible de lire le fichier.');
        words = await WhatsAppParserService.parseFromFile(File(path));
        final content = await File(path).readAsString();
        stats = WhatsAppParserService.getStats(content);
      }

      if (words.isEmpty) {
        setState(() {
          _state = _State.idle;
          _error = 'Aucun mot trouvé. Vérifiez que le fichier est bien une exportation WhatsApp en .txt.';
        });
        return;
      }

      setState(() {
        _words = words;
        _stats = stats;
        _state = _State.preview;
      });
    } catch (e) {
      setState(() {
        _state = _State.idle;
        _error = 'Erreur lors de la lecture : ${e.toString()}';
      });
    }
  }

  Future<void> _confirm() async {
    await LocalStorageService().saveCustomWords(_words);
    await LocalStorageService().incrementStat('whatsapp_imported');
    await LocalStorageService().checkAndUpdateAchievements();
    // Sync to Firestore so the partner can play without importing
    final profile = await CoupleService.getMyProfile();
    if (profile?.coupleId != null) {
      await CoupleService.saveSharedWords(profile!.coupleId!, _words);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
        content: Text('${_words.length} mots importés avec succès !'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Importer WhatsApp',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _state == _State.preview
              ? _PreviewState(
                  words: _words,
                  stats: _stats,
                  onConfirm: _confirm,
                  onReset: () => setState(() {
                    _state = _State.idle;
                    _words = [];
                  }),
                )
              : _PickerState(
                  loading: _state != _State.idle,
                  error: _error,
                  onPick: _pickFile,
                ),
        ),
      ),
    );
  }
}

enum _State { idle, picking, parsing, preview }

// ─────────────────────────────────────────────

class _PickerState extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onPick;

  const _PickerState(
      {required this.loading,
      required this.error,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero illustration
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF25D366).withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Colors.white, size: 56),
                ),
                const SizedBox(height: 28),
                const Text('Importez votre conversation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Exportez une conversation WhatsApp en .txt et importez-la ici pour créer des mots de jeu personnalisés.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                        height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                _HowToCard(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onPick,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file_rounded),
            label: Text(loading ? 'Analyse en cours…' : 'Choisir un fichier .txt',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _HowToCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Comment exporter ?',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textDark)),
          SizedBox(height: 8),
          _Step(n: 1, text: 'Ouvrez une conversation WhatsApp'),
          _Step(n: 2, text: 'Menu ⋮ → Plus → Exporter la discussion'),
          _Step(n: 3, text: 'Choisissez "Sans médias"'),
          _Step(n: 4, text: 'Partagez le fichier .txt avec cette app'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;

  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
            child: Text('$n',
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF25D366),
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _PreviewState extends StatelessWidget {
  final List<String> words;
  final Map<String, dynamic> stats;
  final VoidCallback onConfirm;
  final VoidCallback onReset;

  const _PreviewState(
      {required this.words,
      required this.stats,
      required this.onConfirm,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    final topWords = words.take(30).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                  value: '${stats['totalLines'] ?? 0}',
                  label: 'Messages'),
              _StatItem(
                  value: '${words.length}',
                  label: 'Mots extraits'),
              _StatItem(
                  value: '${stats['uniqueWords'] ?? 0}',
                  label: 'Mots uniques'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Aperçu des mots',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topWords
                  .map((w) => Chip(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        label: Text(w,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Changer',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Importer ${''} mots',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}
