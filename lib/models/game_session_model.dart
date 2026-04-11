class GameSessionModel {
  final String id;
  final String mode; // 'competitif', 'cooperatif', 'chrono', 'personnalise'
  final int player1Score;
  final int player2Score;
  final int? teamScore; // for coop/chrono
  final int? winner; // 1 or 2, null for coop
  final String? player1Name;
  final String? player2Name;
  final DateTime playedAt;
  final int wordsGuessed;
  final int totalWords;
  final Duration? duration;

  GameSessionModel({
    required this.id,
    required this.mode,
    this.player1Score = 0,
    this.player2Score = 0,
    this.teamScore,
    this.winner,
    this.player1Name,
    this.player2Name,
    required this.playedAt,
    this.wordsGuessed = 0,
    this.totalWords = 0,
    this.duration,
  });

  String get modeLabel {
    switch (mode) {
      case 'competitif': return 'Compétitif';
      case 'cooperatif': return 'Coopératif';
      case 'chrono': return 'Contre-la-Montre';
      case 'personnalise': return 'Personnalisé';
      default: return mode;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'player1Score': player1Score,
    'player2Score': player2Score,
    'teamScore': teamScore,
    'winner': winner,
    'player1Name': player1Name,
    'player2Name': player2Name,
    'playedAt': playedAt.toIso8601String(),
    'wordsGuessed': wordsGuessed,
    'totalWords': totalWords,
    'duration': duration?.inSeconds,
  };

  factory GameSessionModel.fromJson(Map<String, dynamic> json) => GameSessionModel(
    id: json['id'] as String? ?? '',
    mode: json['mode'] as String? ?? 'competitif',
    player1Score: json['player1Score'] as int? ?? 0,
    player2Score: json['player2Score'] as int? ?? 0,
    teamScore: json['teamScore'] as int?,
    winner: json['winner'] as int?,
    player1Name: json['player1Name'] as String?,
    player2Name: json['player2Name'] as String?,
    playedAt: DateTime.parse(json['playedAt'] as String),
    wordsGuessed: json['wordsGuessed'] as int? ?? 0,
    totalWords: json['totalWords'] as int? ?? 0,
    duration: json['duration'] != null
        ? Duration(seconds: json['duration'] as int)
        : null,
  );
}
