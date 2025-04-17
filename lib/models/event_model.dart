class EventModel {
  final String title;
  final String description;

  EventModel({
    required this.title,
    this.description = '',
  });

  // Convertir EventModel en Map pour le stockage JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
    };
  }

  // Créer un EventModel à partir d'un Map JSON
  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }
}