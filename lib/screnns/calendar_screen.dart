import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/event_model.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  final String? coupleId;
  const CalendarScreen({super.key, this.coupleId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<EventModel>> _events = {};

  StreamSubscription<QuerySnapshot>? _sub;
  final _db = FirebaseFirestore.instance;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String? get _coupleId => widget.coupleId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    if (_coupleId != null) _subscribeEvents();
  }

  @override
  void didUpdateWidget(CalendarScreen old) {
    super.didUpdateWidget(old);
    if (old.coupleId != widget.coupleId && widget.coupleId != null) {
      _sub?.cancel();
      _subscribeEvents();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _subscribeEvents() {
    _sub = _db
        .collection('couples')
        .doc(_coupleId)
        .collection('calendar_events')
        .orderBy('date')
        .snapshots()
        .listen((snap) {
      final Map<DateTime, List<EventModel>> map = {};
      final List<EventModel> allEvents = [];
      for (final doc in snap.docs) {
        final event = EventModel.fromMap(doc.id, doc.data());
        final key = DateTime(event.date.year, event.date.month, event.date.day);
        map[key] = [...(map[key] ?? []), event];
        allEvents.add(event);
      }
      // Reprogrammer les rappels de notifications à chaque changement
      CollaboNotificationService()
          .scheduleCalendarEventReminders(allEvents);
      if (mounted) setState(() => _events = map);
    });
  }

  List<EventModel> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  List<EventModel> get _allEventsSorted {
    final all = _events.values.expand((e) => e).toList();
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  Future<void> _addEvent() async {
    if (_selectedDay == null || _titleCtrl.text.trim().isEmpty || _coupleId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await _db
        .collection('couples')
        .doc(_coupleId)
        .collection('calendar_events')
        .add({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'date': Timestamp.fromDate(
          DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)),
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _titleCtrl.clear();
    _descCtrl.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteEvent(String eventId) async {
    if (_coupleId == null) return;
    await _db
        .collection('couples')
        .doc(_coupleId)
        .collection('calendar_events')
        .doc(eventId)
        .delete();
  }

  Future<void> _editEvent(EventModel event) async {
    if (_coupleId == null) return;
    final titleCtrl = TextEditingController(text: event.title);
    final descCtrl = TextEditingController(text: event.description);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Modifier le souvenir',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    await _db
                        .collection('couples')
                        .doc(_coupleId)
                        .collection('calendar_events')
                        .doc(event.id)
                        .update({
                      'title': title,
                      'description': descCtrl.text.trim(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Enregistrer',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Ajouter un souvenir',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Ex: Notre anniversaire',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  hintText: 'Décrivez ce souvenir…',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _addEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Enregistrer',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_coupleId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Notre Calendrier',
              style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 18)),
          centerTitle: true,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, size: 64, color: AppColors.primary),
                SizedBox(height: 16),
                Text('Calendrier partagé',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                SizedBox(height: 8),
                Text(
                  'Connectez-vous à votre partenaire pour partager les événements du calendrier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dayEvents =
        _selectedDay != null ? _eventsForDay(_selectedDay!) : <EventModel>[];
    final allEvents = _allEventsSorted;

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
        title: const Text('Notre Calendrier',
            style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                  eventLoader: _eventsForDay,
                  onDaySelected: (sel, foc) =>
                      setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                  onFormatChanged: (f) =>
                      setState(() => _calendarFormat = f),
                  onPageChanged: (foc) => _focusedDay = foc,
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: true,
                    formatButtonShowsNext: false,
                    titleTextStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textDark),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded,
                        color: AppColors.primary),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary),
                    formatButtonDecoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                    ),
                    formatButtonTextStyle:
                        TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                  calendarStyle: CalendarStyle(
                    markerDecoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        shape: BoxShape.circle),
                    todayTextStyle: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700),
                    weekendTextStyle:
                        const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // All souvenirs list header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Tous les souvenirs',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        fontSize: 15),
                  ),
                  const Spacer(),
                  if (allEvents.isNotEmpty)
                    Text('${allEvents.length} souvenir(s)',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: allEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_album_rounded,
                              size: 48,
                              color: AppColors.primary
                                  .withValues(alpha: 0.2)),
                          const SizedBox(height: 8),
                          const Text('Aucun souvenir pour l\'instant',
                              style: TextStyle(
                                  color: AppColors.textMedium,
                                  fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Sélectionnez un jour et appuyez sur +',
                              style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: allEvents.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final e = allEvents[i];
                        final isHighlighted = _selectedDay != null &&
                            isSameDay(e.date, _selectedDay!);
                        return _EventCard(
                          event: e,
                          isHighlighted: isHighlighted,
                          onDelete: () => _deleteEvent(e.id),
                          onEdit: () => _editEvent(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final bool isHighlighted;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _EventCard(
      {required this.event,
      this.isHighlighted = false,
      required this.onDelete,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final d = event.date;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isHighlighted
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(event.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textDark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dateLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                if (event.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(event.description,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium)),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded,
                color: AppColors.primary, size: 20),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }
}
