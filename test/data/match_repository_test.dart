import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaster/data/database_helper.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

MatchRecord buildMatch({
  String name = '',
  Sport sport = Sport.volleyball,
  String team1 = 'Alfa',
  String team2 = 'Beta',
  List<String> team1Players = const <String>['Ana'],
  List<String> team2Players = const <String>['Bruno'],
  int score1 = 3,
  int score2 = 1,
  MatchOutcome outcome = MatchOutcome.team1,
  int durationSeconds = 600,
  DateTime? playedAt,
  List<SetScore> sets = const <SetScore>[],
}) {
  return MatchRecord(
    name: name,
    sport: sport,
    scoringMode: ScoringMode.official,
    team1Name: team1,
    team2Name: team2,
    team1Players: team1Players,
    team2Players: team2Players,
    team1Score: score1,
    team2Score: score2,
    sets: sets,
    durationSeconds: durationSeconds,
    outcome: outcome,
    playedAt: playedAt ?? DateTime(2024, 5, 1, 12),
  );
}

void main() {
  sqfliteFfiInit();

  late MatchRepository repository;

  setUp(() async {
    DatabaseHelper.overrideFactory = databaseFactoryFfi;
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    await DatabaseHelper().close();
    repository = MatchRepository();
    await repository.deleteAll();
  });

  tearDown(() async {
    await DatabaseHelper().close();
    DatabaseHelper.overrideFactory = null;
    DatabaseHelper.overridePath = null;
  });

  group('insert', () {
    test('partidas sucessivas são todas preservadas', () async {
      // Regressão: a versão anterior gravava sempre o mesmo `nomePartida` numa
      // coluna UNIQUE com ConflictAlgorithm.replace, então cada partida nova
      // apagava a anterior e o histórico nunca passava de uma linha.
      for (int i = 0; i < 5; i++) {
        await repository.insert(buildMatch(team1: 'Time $i'));
      }
      final List<MatchRecord> all = await repository.findAll();
      expect(all, hasLength(5));
    });

    test('partidas com o mesmo nome coexistem', () async {
      await repository.insert(buildMatch(name: 'Quarta à noite'));
      await repository.insert(buildMatch(name: 'Quarta à noite'));
      expect(await repository.findAll(), hasLength(2));
    });

    test('devolve o registro com id e preserva todos os campos', () async {
      final MatchRecord saved = await repository.insert(buildMatch(
        name: 'Final',
        sets: const <SetScore>[SetScore(25, 20), SetScore(23, 25), SetScore(15, 9)],
      ));
      expect(saved.id, isNotNull);

      final MatchRecord? loaded = await repository.findById(saved.id!);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Final');
      expect(loaded.sport, Sport.volleyball);
      expect(loaded.scoringMode, ScoringMode.official);
      expect(loaded.team1Players, <String>['Ana']);
      expect(loaded.sets, hasLength(3));
      expect(loaded.sets.first, const SetScore(25, 20));
      expect(loaded.durationSeconds, 600);
      expect(loaded.outcome, MatchOutcome.team1);
      expect(loaded.playedAt, DateTime(2024, 5, 1, 12));
    });
  });

  group('findAll', () {
    setUp(() async {
      await repository.insert(buildMatch(
        sport: Sport.tennis,
        team1: 'Ana',
        team2: 'Bruno',
        team1Players: const <String>['Ana'],
        playedAt: DateTime(2024, 1, 1),
        durationSeconds: 100,
      ));
      await repository.insert(buildMatch(
        sport: Sport.volleyball,
        team1: 'Praia',
        team2: 'Quadra',
        team1Players: const <String>['Carla'],
        playedAt: DateTime(2024, 3, 1),
        durationSeconds: 5000,
      ));
      await repository.insert(buildMatch(
        sport: Sport.tableTennis,
        team1: 'Mesa 1',
        team2: 'Mesa 2',
        playedAt: DateTime(2024, 2, 1),
        durationSeconds: 900,
      ));
    });

    test('filtra por esporte', () async {
      final List<MatchRecord> tennis =
          await repository.findAll(sport: Sport.tennis);
      expect(tennis, hasLength(1));
      expect(tennis.single.team1Name, 'Ana');
    });

    test('ordena da mais recente para a mais antiga por padrão', () async {
      final List<MatchRecord> all = await repository.findAll();
      expect(
        all.map((MatchRecord m) => m.team1Name),
        <String>['Praia', 'Mesa 1', 'Ana'],
      );
    });

    test('ordena por duração', () async {
      final List<MatchRecord> all =
          await repository.findAll(sort: MatchSort.longest);
      expect(all.first.team1Name, 'Praia');
      expect(all.last.team1Name, 'Ana');
    });

    test('busca por nome de time, jogador e esporte', () async {
      expect(await repository.findAll(query: 'praia'), hasLength(1));
      expect(await repository.findAll(query: 'Carla'), hasLength(1));
      expect(await repository.findAll(query: 'Vôlei'), hasLength(1));
      expect(await repository.findAll(query: 'inexistente'), isEmpty);
      expect(await repository.findAll(query: '   '), hasLength(3));
    });
  });

  group('delete e restore', () {
    test('excluir remove só a partida indicada', () async {
      final MatchRecord a = await repository.insert(buildMatch(team1: 'A'));
      await repository.insert(buildMatch(team1: 'B'));

      expect(await repository.delete(a.id!), 1);
      final List<MatchRecord> left = await repository.findAll();
      expect(left, hasLength(1));
      expect(left.single.team1Name, 'B');
    });

    test('restore devolve a partida com o mesmo id (desfazer)', () async {
      final MatchRecord saved = await repository.insert(buildMatch(name: 'X'));
      await repository.delete(saved.id!);
      expect(await repository.findAll(), isEmpty);

      await repository.restore(saved);
      final List<MatchRecord> all = await repository.findAll();
      expect(all, hasLength(1));
      expect(all.single.id, saved.id);
      expect(all.single.name, 'X');
    });
  });

  group('stats', () {
    test('agrega partidas, tempo e classificação dos times', () async {
      await repository.insert(buildMatch(
        team1: 'Alfa',
        team2: 'Beta',
        score1: 3,
        score2: 1,
        outcome: MatchOutcome.team1,
        durationSeconds: 600,
      ));
      await repository.insert(buildMatch(
        team1: 'Alfa',
        team2: 'Gama',
        score1: 3,
        score2: 0,
        outcome: MatchOutcome.team1,
        durationSeconds: 400,
      ));
      await repository.insert(buildMatch(
        team1: 'Beta',
        team2: 'Gama',
        score1: 1,
        score2: 1,
        outcome: MatchOutcome.draw,
        durationSeconds: 200,
        sport: Sport.tennis,
      ));

      final MatchStats stats = await repository.stats();
      expect(stats.totalMatches, 3);
      expect(stats.totalSeconds, 1200);
      expect(stats.averageSeconds, 400);
      expect(stats.matchesOf(Sport.volleyball), 2);
      expect(stats.matchesOf(Sport.tennis), 1);

      final TeamStanding alfa =
          stats.standings.firstWhere((TeamStanding s) => s.name == 'Alfa');
      expect(alfa.played, 2);
      expect(alfa.wins, 2);
      expect(alfa.losses, 0);
      expect(alfa.winRate, 1.0);
      expect(alfa.pointsFor, 6);
      expect(alfa.pointsAgainst, 1);
      expect(stats.leader?.name, 'Alfa');

      final TeamStanding beta =
          stats.standings.firstWhere((TeamStanding s) => s.name == 'Beta');
      expect(beta.played, 2);
      expect(beta.wins, 0);
      expect(beta.losses, 1);
      expect(beta.draws, 1);
      expect(beta.winRate, 0.25, reason: 'empate vale meia vitória');
      expect(beta.winRateLabel, '25%');
    });

    test('histórico vazio devolve estatísticas zeradas', () async {
      final MatchStats stats = await repository.stats();
      expect(stats.isEmpty, isTrue);
      expect(stats.averageSeconds, 0);
      expect(stats.leader, isNull);
    });

    test('estatísticas podem ser restritas a um esporte', () async {
      await repository.insert(buildMatch(sport: Sport.tennis, team1: 'Ana'));
      await repository.insert(buildMatch(sport: Sport.volleyball, team1: 'Praia'));
      final MatchStats stats = await repository.stats(sport: Sport.tennis);
      expect(stats.totalMatches, 1);
      expect(stats.standings.any((TeamStanding s) => s.name == 'Praia'), isFalse);
    });
  });
}
