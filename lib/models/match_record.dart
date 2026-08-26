import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';

/// Como a partida terminou.
enum MatchOutcome {
  team1('team1'),
  team2('team2'),
  draw('draw');

  const MatchOutcome(this.id);

  final String id;

  static MatchOutcome fromId(String? value) => MatchOutcome.values.firstWhere(
        (MatchOutcome outcome) => outcome.id == value,
        orElse: () => MatchOutcome.draw,
      );

  static MatchOutcome fromSide(TeamSide? side) => switch (side) {
        TeamSide.team1 => MatchOutcome.team1,
        TeamSide.team2 => MatchOutcome.team2,
        null => MatchOutcome.draw,
      };
}

/// Uma partida encerrada e guardada no histórico.
@immutable
class MatchRecord {
  const MatchRecord({
    this.id,
    required this.name,
    required this.sport,
    required this.scoringMode,
    required this.team1Name,
    required this.team2Name,
    required this.team1Players,
    required this.team2Players,
    required this.team1Score,
    required this.team2Score,
    required this.sets,
    required this.durationSeconds,
    required this.outcome,
    required this.playedAt,
  });

  /// Monta o registro a partir do placar final de uma partida.
  factory MatchRecord.fromScore({
    required String name,
    required Sport sport,
    required ScoringMode scoringMode,
    required String team1Name,
    required String team2Name,
    required List<String> team1Players,
    required List<String> team2Players,
    required ScoreState score,
    required int durationSeconds,
    required DateTime playedAt,
  }) {
    final bool countsSets = scoringMode == ScoringMode.official;
    return MatchRecord(
      name: name,
      sport: sport,
      scoringMode: scoringMode,
      team1Name: team1Name,
      team2Name: team2Name,
      team1Players: team1Players,
      team2Players: team2Players,
      team1Score: countsSets ? score.setsWon1 : score.totalPoints1,
      team2Score: countsSets ? score.setsWon2 : score.totalPoints2,
      sets: score.completedSets,
      durationSeconds: durationSeconds,
      outcome: MatchOutcome.fromSide(score.winner),
      playedAt: playedAt,
    );
  }

  factory MatchRecord.fromMap(Map<String, dynamic> map) {
    return MatchRecord(
      id: (map['id'] as num?)?.toInt(),
      name: (map['name'] as String?) ?? '',
      sport: Sport.fromId(map['sport'] as String?),
      scoringMode: ScoringMode.fromId(map['scoringMode'] as String?),
      team1Name: (map['team1Name'] as String?) ?? 'Time 1',
      team2Name: (map['team2Name'] as String?) ?? 'Time 2',
      team1Players: _decodeStringList(map['team1Players']),
      team2Players: _decodeStringList(map['team2Players']),
      team1Score: (map['team1Score'] as num?)?.toInt() ?? 0,
      team2Score: (map['team2Score'] as num?)?.toInt() ?? 0,
      sets: _decodeSets(map['sets']),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      outcome: MatchOutcome.fromId(map['winner'] as String?),
      playedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['playedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final int? id;
  final String name;
  final Sport sport;
  final ScoringMode scoringMode;
  final String team1Name;
  final String team2Name;
  final List<String> team1Players;
  final List<String> team2Players;

  /// Sets vencidos (regras oficiais) ou pontos totais (contagem livre).
  final int team1Score;
  final int team2Score;

  /// Placar detalhado set a set.
  final List<SetScore> sets;

  final int durationSeconds;
  final MatchOutcome outcome;
  final DateTime playedAt;

  String get winnerName => switch (outcome) {
        MatchOutcome.team1 => team1Name,
        MatchOutcome.team2 => team2Name,
        MatchOutcome.draw => 'Empate',
      };

  bool get isDraw => outcome == MatchOutcome.draw;

  String get title => name.trim().isEmpty ? '$team1Name vs $team2Name' : name;

  String get scoreLine => '$team1Score x $team2Score';

  String get formattedDuration => formatDuration(durationSeconds);

  /// "25-20 · 20-25 · 25-18", vazio quando não há sets registrados.
  String get setsSummary =>
      sets.map((SetScore s) => '${s.team1}-${s.team2}').join(' · ');

  List<String> get allPlayers => <String>[...team1Players, ...team2Players];

  /// Nome do time [side].
  String teamName(TeamSide side) =>
      side == TeamSide.team1 ? team1Name : team2Name;

  /// Texto pronto para compartilhar ou copiar.
  String toShareText() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('🏆 $title')
      ..writeln('${sport.label} · ${formatDateTime(playedAt)}')
      ..writeln('$team1Name $team1Score x $team2Score $team2Name');
    if (setsSummary.isNotEmpty) {
      buffer.writeln('${sport.rules.setNoun}s: $setsSummary');
    }
    buffer
      ..writeln('Duração: $formattedDuration')
      ..writeln(isDraw ? 'Resultado: empate' : 'Vencedor: $winnerName');
    return buffer.toString().trimRight();
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
        'sport': sport.id,
        'scoringMode': scoringMode.name,
        'team1Name': team1Name,
        'team2Name': team2Name,
        'team1Players': jsonEncode(team1Players),
        'team2Players': jsonEncode(team2Players),
        'team1Score': team1Score,
        'team2Score': team2Score,
        'sets': jsonEncode(sets.map((SetScore s) => s.toMap()).toList()),
        'durationSeconds': durationSeconds,
        'winner': outcome.id,
        'playedAt': playedAt.millisecondsSinceEpoch,
      };

  MatchRecord copyWith({int? id}) => MatchRecord(
        id: id ?? this.id,
        name: name,
        sport: sport,
        scoringMode: scoringMode,
        team1Name: team1Name,
        team2Name: team2Name,
        team1Players: team1Players,
        team2Players: team2Players,
        team1Score: team1Score,
        team2Score: team2Score,
        sets: sets,
        durationSeconds: durationSeconds,
        outcome: outcome,
        playedAt: playedAt,
      );

  /// `true` se [query] aparece no nome da partida, dos times ou dos jogadores.
  bool matchesQuery(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final Iterable<String> haystack = <String>[
      name,
      team1Name,
      team2Name,
      sport.label,
      ...allPlayers,
    ];
    return haystack.any((String s) => s.toLowerCase().contains(needle));
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is List) return raw.map((Object? e) => e.toString()).toList();
    final String text = raw.toString();
    if (text.isEmpty) return const <String>[];
    if (text.startsWith('[')) {
      try {
        final Object? decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded
              .map((Object? e) => e.toString().trim())
              .where((String e) => e.isNotEmpty)
              .toList();
        }
      } on FormatException {
        // Cai para o formato separado por vírgula, usado pelo banco antigo.
      }
    }
    return text
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  static List<SetScore> _decodeSets(Object? raw) {
    if (raw == null) return const <SetScore>[];
    final String text = raw.toString();
    if (text.isEmpty) return const <SetScore>[];
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(SetScore.fromMap)
            .toList();
      }
    } on FormatException {
      return const <SetScore>[];
    }
    return const <SetScore>[];
  }
}
