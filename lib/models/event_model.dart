import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;

  EventModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
      };

  factory EventModel.fromMap(String id, Map<String, dynamic> map) => EventModel(
        id: id,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}