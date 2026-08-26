import 'package:matchmaster/data/database_helper.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:sqflite/sqflite.dart';

/// Como o histórico é ordenado.
enum MatchSort {
  newest('Mais recentes', 'playedAt DESC, id DESC'),
  oldest('Mais antigas', 'playedAt ASC, id ASC'),
  longest('Mais longas', 'durationSeconds DESC, id DESC');

  const MatchSort(this.label, this.orderBy);

  final String label;
  final String orderBy;
}

/// Acesso às partidas guardadas.
class MatchRepository {
  MatchRepository({DatabaseHelper? helper})
      : _helper = helper ?? DatabaseHelper();

  final DatabaseHelper _helper;

  Future<Database> get _db => _helper.database;

  /// Guarda uma partida e devolve o registro com o `id` atribuído.
  ///
  /// Cada chamada cria uma linha nova. A versão anterior gravava sempre o mesmo
  /// `nomePartida` numa coluna `UNIQUE` com `ConflictAlgorithm.replace`, o que
  /// fazia cada partida apagar a anterior.
  Future<MatchRecord> insert(MatchRecord record) async {
    final Database db = await _db;
    final int id = await db.insert(
      DatabaseHelper.matchesTable,
      record.toMap()..remove('id'),
    );
    return record.copyWith(id: id);
  }

  Future<List<MatchRecord>> findAll({
    Sport? sport,
    String query = '',
    MatchSort sort = MatchSort.newest,
  }) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseHelper.matchesTable,
      where: sport == null ? null : 'sport = ?',
      whereArgs: sport == null ? null : <Object?>[sport.id],
      orderBy: sort.orderBy,
    );
    final List<MatchRecord> records = rows.map(MatchRecord.fromMap).toList();
    if (query.trim().isEmpty) return records;
    return records
        .where((MatchRecord record) => record.matchesQuery(query))
        .toList();
  }

  Future<MatchRecord?> findById(int id) async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseHelper.matchesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MatchRecord.fromMap(rows.first);
  }

  Future<int> delete(int id) async {
    final Database db = await _db;
    return db.delete(
      DatabaseHelper.matchesTable,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Regrava uma partida excluída, preservando o `id` — usado pelo "Desfazer".
  Future<void> restore(MatchRecord record) async {
    final Database db = await _db;
    await db.insert(
      DatabaseHelper.matchesTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAll() => _helper.wipe();

  /// Estatísticas agregadas de todo o histórico (ou de um único esporte).
  Future<MatchStats> stats({Sport? sport}) async {
    final List<MatchRecord> matches = await findAll(sport: sport);
    return MatchStats.from(matches);
  }
}

/// Desempenho acumulado de um time.
class TeamStanding {
  const TeamStanding({
    required this.name,
    required this.played,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  final String name;
  final int played;
  final int wins;
  final int losses;
  final int draws;
  final int pointsFor;
  final int pointsAgainst;

  /// Aproveitamento entre 0 e 1. Empates valem meia vitória.
  double get winRate => played == 0 ? 0 : (wins + draws * 0.5) / played;

  int get pointDifference => pointsFor - pointsAgainst;

  String get winRateLabel => '${(winRate * 100).round()}%';
}

/// Números do histórico, prontos para a tela de estatísticas.
class MatchStats {
  const MatchStats({
    required this.totalMatches,
    required this.totalSeconds,
    required this.matchesBySport,
    required this.standings,
  });

  factory MatchStats.from(List<MatchRecord> matches) {
    final Map<Sport, int> bySport = <Sport, int>{};
    final Map<String, _StandingBuilder> builders = <String, _StandingBuilder>{};
    int totalSeconds = 0;

    for (final MatchRecord match in matches) {
      totalSeconds += match.durationSeconds;
      bySport.update(match.sport, (int v) => v + 1, ifAbsent: () => 1);

      _record(builders, match.team1Name, match, isTeam1: true);
      _record(builders, match.team2Name, match, isTeam1: false);
    }

    final List<TeamStanding> standings =
        builders.values.map((_StandingBuilder b) => b.build()).toList()
          ..sort((TeamStanding a, TeamStanding b) {
            final int byWins = b.wins.compareTo(a.wins);
            if (byWins != 0) return byWins;
            final int byRate = b.winRate.compareTo(a.winRate);
            if (byRate != 0) return byRate;
            return b.pointDifference.compareTo(a.pointDifference);
          });

    return MatchStats(
      totalMatches: matches.length,
      totalSeconds: totalSeconds,
      matchesBySport: bySport,
      standings: standings,
    );
  }

  static const MatchStats empty = MatchStats(
    totalMatches: 0,
    totalSeconds: 0,
    matchesBySport: <Sport, int>{},
    standings: <TeamStanding>[],
  );

  final int totalMatches;
  final int totalSeconds;
  final Map<Sport, int> matchesBySport;

  /// Times ordenados por vitórias, depois aproveitamento e saldo de pontos.
  final List<TeamStanding> standings;

  bool get isEmpty => totalMatches == 0;

  /// Duração média de uma partida, em segundos.
  int get averageSeconds =>
      totalMatches == 0 ? 0 : (totalSeconds / totalMatches).round();

  TeamStanding? get leader => standings.isEmpty ? null : standings.first;

  int matchesOf(Sport sport) => matchesBySport[sport] ?? 0;

  static void _record(
    Map<String, _StandingBuilder> builders,
    String rawName,
    MatchRecord match, {
    required bool isTeam1,
  }) {
    final String name = rawName.trim();
    if (name.isEmpty) return;
    final _StandingBuilder builder =
        builders.putIfAbsent(name, () => _StandingBuilder(name));

    builder.played++;
    builder.pointsFor += isTeam1 ? match.team1Score : match.team2Score;
    builder.pointsAgainst += isTeam1 ? match.team2Score : match.team1Score;

    if (match.isDraw) {
      builder.draws++;
    } else {
      final bool won = (match.outcome == MatchOutcome.team1) == isTeam1;
      if (won) {
        builder.wins++;
      } else {
        builder.losses++;
      }
    }
  }
}

class _StandingBuilder {
  _StandingBuilder(this.name);

  final String name;
  int played = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;

  TeamStanding build() => TeamStanding(
        name: name,
        played: played,
        wins: wins,
        losses: losses,
        draws: draws,
        pointsFor: pointsFor,
        pointsAgainst: pointsAgainst,
      );
}
