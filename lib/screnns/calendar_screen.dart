import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/event_model.dart';

class CalendarScreen extends StatefulWidget {
  final String player1Color;
  final String player2Color;

  const CalendarScreen({
    super.key,
    required this.player1Color,
    required this.player2Color,
  });

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<EventModel>> _events = {};
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  String _dateTimeToKey(DateTime date) {
    return "${date.year}-${date.month}-${date.day}";
  }

  DateTime _keyToDateTime(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getString('calendar_events');

    if (eventsJson != null) {
      final Map<String, dynamic> eventsMap = json.decode(eventsJson);
      final loadedEvents = <DateTime, List<EventModel>>{};

      eventsMap.forEach((key, value) {
        final date = _keyToDateTime(key);
        final eventsList = (value as List)
            .map((item) => EventModel.fromJson(item))
            .toList();
        loadedEvents[date] = eventsList;
      });

      setState(() {
        _events = loadedEvents;
      });
    }
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, List<Map<String, dynamic>>> eventsMap = {};

    _events.forEach((date, events) {
      final key = _dateTimeToKey(date);
      eventsMap[key] = events.map((e) => e.toJson()).toList();
    });

    await prefs.setString('calendar_events', json.encode(eventsMap));
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  Color _getTeamColor() {
    final color1 = _getPlayerColor(1);
    final color2 = _getPlayerColor(2);
    return Color.lerp(color1, color2, 0.5)!;
  }

  Color _getPlayerColor(int playerNumber) {
    final color = playerNumber == 1 ? widget.player1Color : widget.player2Color;
    switch (color) {
      case 'Rouge': return Colors.red[400]!;
      case 'Bleu': return Colors.blue[400]!;
      case 'Rose': return Colors.pink[300]!;
      case 'Vert': return Colors.green[400]!;
      case 'Violet': return Colors.purple[400]!;
      case 'Orange': return Colors.orange[400]!;
      case 'Jaune': return Colors.yellow[600]!;
      default: return Colors.grey;
    }
  }

  void _addEvent() {
    if (_selectedDay == null) return;

    if (_eventTitleController.text.isNotEmpty) {
      final newEvent = EventModel(
        title: _eventTitleController.text,
        description: _eventDescriptionController.text,
      );

      final normalizedDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

      setState(() {
        if (_events[normalizedDay] == null) {
          _events[normalizedDay] = [newEvent];
        } else {
          _events[normalizedDay]!.add(newEvent);
        }
        _saveEvents();
      });

      _eventTitleController.clear();
      _eventDescriptionController.clear();
      Navigator.pop(context);
    }
  }

  void _showAddEventDialog() {
    final teamColor = _getTeamColor();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.pink[50]!, Colors.purple[50]!],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ajouter un souvenir',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _eventTitleController,
                decoration: InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Ex: Notre anniversaire',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _eventDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  hintText: 'Ex: Nous avons fêté nos 1 an ensemble',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.purple[800],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: _addEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teamColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Ajouter',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = _getTeamColor();
    final player1Color = _getPlayerColor(1);
    final player2Color = _getPlayerColor(2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notre Calendrier'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [player1Color, player2Color],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink[50]!,
              Colors.purple[50]!,
            ],
          ),
        ),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: teamColor.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  markersAutoAligned: true,
                  markerSize: 6,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: Colors.purple[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left, color: teamColor),
                  rightChevronIcon: Icon(Icons.chevron_right, color: teamColor),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.purple[800],
                    fontWeight: FontWeight.bold,
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.pink[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _selectedDay != null
                    ? 'Souvenirs du ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                    : 'Sélectionnez une date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildEventList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: teamColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventList() {
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
    final teamColor = _getTeamColor();

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 50,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 15),
            Text(
              'Pas de souvenirs ce jour',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ajoutez un souvenir spécial !',
              style: TextStyle(
                color: teamColor,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white,
                  Colors.white,
                  teamColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                event.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.purple[800],
                ),
              ),
              subtitle: event.description.isNotEmpty
                  ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  event.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              )
                  : null,
              trailing: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.pink[300],
                ),
                onPressed: () {
                  setState(() {
                    final normalizedDay = DateTime(
                      _selectedDay!.year,
                      _selectedDay!.month,
                      _selectedDay!.day,
                    );
                    _events[normalizedDay]!.removeAt(index);

                    if (_events[normalizedDay]!.isEmpty) {
                      _events.remove(normalizedDay);
                    }
                    _saveEvents();
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _eventTitleController.dispose();
    _eventDescriptionController.dispose();
    super.dispose();
  }
}