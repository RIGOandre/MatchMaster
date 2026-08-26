import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaster/data/database_helper.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Recria o schema da versão 2 do app, como ele existia no banco do usuário.
Future<void> createLegacySchema(Database db) async {
  await db.execute(
    'CREATE TABLE teams(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
  );
  await db.execute(
    'CREATE TABLE players(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, '
    'teamId INTEGER, FOREIGN KEY(teamId) REFERENCES teams(id))',
  );
  await db.execute('''
    CREATE TABLE matches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        team1Name TEXT NOT NULL,
        team2Name TEXT NOT NULL,
        team1Score INTEGER NOT NULL,
        team2Score INTEGER NOT NULL,
        matchDuration TEXT NOT NULL,
        nomePartida TEXT UNIQUE NOT NULL,
        team1Players TEXT NOT NULL,
        team2Players TEXT NOT NULL,
        winner TEXT NOT NULL,
        sport TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');
}

void main() {
  sqfliteFfiInit();

  group('migrateLegacyRow', () {
    test('converte uma linha do schema antigo', () {
      final MatchRecord record = DatabaseHelper.migrateLegacyRow(
        <String, dynamic>{
          'team1Name': 'Alfa',
          'team2Name': 'Beta',
          'team1Score': 21,
          'team2Score': 18,
          'matchDuration': '12:30',
          'nomePartida': 'Nome da Partida',
          'team1Players': 'Ana, Bruno, ',
          'team2Players': 'Carla',
          'winner': 'Alfa',
          'sport': 'Vôlei',
          'created_at': '2024-05-01 15:04:05',
        },
      );

      expect(record.sport, Sport.volleyball);
      expect(record.scoringMode, ScoringMode.free);
      expect(record.team1Players, <String>['Ana', 'Bruno']);
      expect(record.team2Players, <String>['Carla']);
      expect(record.durationSeconds, 750);
      expect(record.outcome, MatchOutcome.team1);
      expect(record.name, '', reason: 'o nome fixo antigo não é aproveitado');
      expect(record.title, 'Alfa vs Beta');
      expect(
        record.playedAt.toUtc(),
        DateTime.utc(2024, 5, 1, 15, 4, 5),
      );
    });

    test('nome real da partida é preservado', () {
      final MatchRecord record = DatabaseHelper.migrateLegacyRow(
        <String, dynamic>{
          'team1Name': 'A',
          'team2Name': 'B',
          'team1Score': 1,
          'team2Score': 0,
          'matchDuration': '00:30',
          'nomePartida': 'Final do campeonato',
          'team1Players': '',
          'team2Players': '',
          'winner': 'A',
          'sport': 'Tênis',
        },
      );
      expect(record.name, 'Final do campeonato');
      expect(record.sport, Sport.tennis);
    });

    test('"Empate" e vencedor desconhecido caem no placar', () {
      MatchRecord record = DatabaseHelper.migrateLegacyRow(<String, dynamic>{
        'team1Name': 'A',
        'team2Name': 'B',
        'team1Score': 2,
        'team2Score': 2,
        'matchDuration': '01:00',
        'nomePartida': 'x',
        'team1Players': '',
        'team2Players': '',
        'winner': 'Empate',
        'sport': 'Tênis de Mesa',
      });
      expect(record.outcome, MatchOutcome.draw);
      expect(record.sport, Sport.tableTennis);

      record = DatabaseHelper.migrateLegacyRow(<String, dynamic>{
        'team1Name': 'A',
        'team2Name': 'B',
        'team1Score': 0,
        'team2Score': 5,
        'matchDuration': '01:00',
        'nomePartida': 'y',
        'team1Players': '',
        'team2Players': '',
        'winner': 'time apagado',
        'sport': 'Tênis',
      });
      expect(record.outcome, MatchOutcome.team2);
    });

    test('campos ausentes não derrubam a migração', () {
      final MatchRecord record =
          DatabaseHelper.migrateLegacyRow(<String, dynamic>{});
      expect(record.team1Name, 'Time 1');
      expect(record.team2Name, 'Time 2');
      expect(record.durationSeconds, 0);
      expect(record.outcome, MatchOutcome.draw);
      expect(record.sport, Sport.tennis);
    });
  });

  group('upgrade do banco', () {
    // Um arquivo de verdade, e não `:memory:`: o sqflite guarda em cache as
    // conexões abertas por caminho, então reabrir um banco em memória devolve a
    // mesma instância e o onUpgrade nunca roda.
    late Directory tempDir;
    late String path;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('matchmaster_migration');
      path = '${tempDir.path}/matchmaster.db';
      DatabaseHelper.overrideFactory = databaseFactoryFfi;
      DatabaseHelper.overridePath = path;
    });

    tearDown(() async {
      await DatabaseHelper().close();
      DatabaseHelper.overrideFactory = null;
      DatabaseHelper.overridePath = null;
      await tempDir.delete(recursive: true);
    });

    /// Cria o banco como a versão 2 do app o deixava e fecha a conexão.
    Future<void> seedLegacyDatabase(
      List<Map<String, Object?>> rows,
    ) async {
      final Database legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (Database db, int version) => createLegacySchema(db),
        ),
      );
      for (final Map<String, Object?> row in rows) {
        await legacy.insert('matches', row);
      }
      await legacy.close();
    }

    test('histórico da versão 2 sobrevive ao upgrade', () async {
      await seedLegacyDatabase(<Map<String, Object?>>[
        <String, Object?>{
          'team1Name': 'Alfa',
          'team2Name': 'Beta',
          'team1Score': 21,
          'team2Score': 15,
          'matchDuration': '10:00',
          'nomePartida': 'Nome da Partida',
          'team1Players': 'Ana, Bruno',
          'team2Players': 'Carla, Diego',
          'winner': 'Alfa',
          'sport': 'Vôlei',
          'created_at': '2024-05-01 15:04:05',
        },
        <String, Object?>{
          'team1Name': 'Gama',
          'team2Name': 'Delta',
          'team1Score': 2,
          'team2Score': 3,
          'matchDuration': '05:20',
          'nomePartida': 'Semifinal',
          'team1Players': 'Eva',
          'team2Players': 'Fábio',
          'winner': 'Delta',
          'sport': 'Tênis',
          'created_at': '2024-05-02 10:00:00',
        },
      ]);

      final List<MatchRecord> migrated = await MatchRepository().findAll();

      expect(migrated, hasLength(2));
      final MatchRecord tennis =
          migrated.firstWhere((MatchRecord m) => m.sport == Sport.tennis);
      expect(tennis.name, 'Semifinal');
      expect(tennis.outcome, MatchOutcome.team2);
      expect(tennis.durationSeconds, 320);
      expect(tennis.team1Players, <String>['Eva']);

      final MatchRecord volley =
          migrated.firstWhere((MatchRecord m) => m.sport == Sport.volleyball);
      expect(volley.team1Players, <String>['Ana', 'Bruno']);
      expect(volley.team1Score, 21);
      expect(volley.scoringMode, ScoringMode.free);
    });

    test('tabelas mortas teams/players são removidas', () async {
      await seedLegacyDatabase(const <Map<String, Object?>>[]);

      final Database upgraded = await DatabaseHelper().database;
      final List<Map<String, Object?>> tables = await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final Set<String> names =
          tables.map((Map<String, Object?> r) => r['name'] as String).toSet();
      expect(names, contains('matches'));
      expect(names, isNot(contains('teams')));
      expect(names, isNot(contains('players')));
    });

    test('instalação nova cria o schema atual e grava normalmente', () async {
      final MatchRepository repository = MatchRepository();
      expect(await repository.findAll(), isEmpty);
      await repository.insert(
        MatchRecord(
          name: 'Primeira',
          sport: Sport.tennis,
          scoringMode: ScoringMode.official,
          team1Name: 'A',
          team2Name: 'B',
          team1Players: const <String>['Ana'],
          team2Players: const <String>['Bruno'],
          team1Score: 2,
          team2Score: 0,
          sets: const <SetScore>[],
          durationSeconds: 60,
          outcome: MatchOutcome.team1,
          playedAt: DateTime(2024, 6, 1),
        ),
      );
      expect(await repository.findAll(), hasLength(1));
    });
  });
}
