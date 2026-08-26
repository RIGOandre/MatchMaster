import 'package:flutter/foundation.dart';

/// Identifica um dos dois lados da partida.
enum TeamSide { team1, team2 }

/// Resultado de um set (ou game, no tênis de mesa) já encerrado.
@immutable
class SetScore {
  const SetScore(this.team1, this.team2);

  factory SetScore.fromMap(Map<String, dynamic> map) => SetScore(
        (map['team1'] as num?)?.toInt() ?? 0,
        (map['team2'] as num?)?.toInt() ?? 0,
      );

  final int team1;
  final int team2;

  TeamSide? get winner {
    if (team1 > team2) return TeamSide.team1;
    if (team2 > team1) return TeamSide.team2;
    return null;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{'team1': team1, 'team2': team2};

  @override
  String toString() => '$team1-$team2';

  @override
  bool operator ==(Object other) =>
      other is SetScore && other.team1 == team1 && other.team2 == team2;

  @override
  int get hashCode => Object.hash(team1, team2);
}

/// Estado imutável de uma partida em andamento.
///
/// Ser imutável é o que torna o "desfazer" trivial e confiável: a tela guarda a
/// pilha de estados anteriores em vez de tentar reverter a pontuação na mão.
@immutable
class ScoreState {
  const ScoreState({
    this.completedSets = const <SetScore>[],
    this.points1 = 0,
    this.points2 = 0,
    this.games1 = 0,
    this.games2 = 0,
    this.tieBreak = false,
    this.winner,
  });

  /// Sets/games já encerrados, na ordem em que foram disputados.
  final List<SetScore> completedSets;

  /// Pontos do set atual. No tênis, são os pontos do game atual.
  final int points1;
  final int points2;

  /// Games do set atual (apenas tênis).
  final int games1;
  final int games2;

  /// Se o set atual está sendo decidido no tie-break (apenas tênis).
  final bool tieBreak;

  /// Vencedor da partida, ou `null` enquanto ela estiver em andamento.
  final TeamSide? winner;

  bool get isFinished => winner != null;

  /// Sets vencidos por cada lado.
  int get setsWon1 =>
      completedSets.where((SetScore s) => s.winner == TeamSide.team1).length;
  int get setsWon2 =>
      completedSets.where((SetScore s) => s.winner == TeamSide.team2).length;

  /// Total de pontos marcados na partida inteira, incluindo o set atual.
  int get totalPoints1 =>
      completedSets.fold<int>(points1, (int sum, SetScore s) => sum + s.team1);
  int get totalPoints2 =>
      completedSets.fold<int>(points2, (int sum, SetScore s) => sum + s.team2);

  /// Índice (base zero) do set em disputa.
  int get currentSetIndex => completedSets.length;

  ScoreState copyWith({
    List<SetScore>? completedSets,
    int? points1,
    int? points2,
    int? games1,
    int? games2,
    bool? tieBreak,
    TeamSide? winner,
  }) {
    return ScoreState(
      completedSets: completedSets ?? this.completedSets,
      points1: points1 ?? this.points1,
      points2: points2 ?? this.points2,
      games1: games1 ?? this.games1,
      games2: games2 ?? this.games2,
      tieBreak: tieBreak ?? this.tieBreak,
      winner: winner ?? this.winner,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScoreState &&
      listEquals(other.completedSets, completedSets) &&
      other.points1 == points1 &&
      other.points2 == points2 &&
      other.games1 == games1 &&
      other.games2 == games2 &&
      other.tieBreak == tieBreak &&
      other.winner == winner;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(completedSets),
        points1,
        points2,
        games1,
        games2,
        tieBreak,
        winner,
      );
}
