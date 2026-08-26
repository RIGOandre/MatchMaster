import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaster/data/database_helper.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/data/settings_store.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'preview_fonts.dart';

MatchRecord match({
  required String team1,
  required String team2,
  required Sport sport,
  required int s1,
  required int s2,
  List<SetScore> sets = const <SetScore>[],
  int seconds = 1520,
  int day = 12,
}) {
  return MatchRecord(
    name: '',
    sport: sport,
    scoringMode: ScoringMode.official,
    team1Name: team1,
    team2Name: team2,
    team1Players: const <String>['Ana', 'Bruno'],
    team2Players: const <String>['Carla', 'Diego'],
    team1Score: s1,
    team2Score: s2,
    sets: sets,
    durationSeconds: seconds,
    outcome: s1 > s2 ? MatchOutcome.team1 : MatchOutcome.team2,
    playedAt: DateTime(2024, 5, day, 20, 30),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  Future<void> shoot(
    WidgetTester tester,
    String name,
    ThemeMode mode,
    Future<void> Function(WidgetTester tester) drive,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'remember_me': true,
      'user_name': 'André Rigo',
      'theme_mode': mode.name,
    });
    SharedPreferences.resetStatic();
    DatabaseHelper.overrideFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    await DatabaseHelper().close();

    final MatchRepository repo = MatchRepository();
    await repo.deleteAll();
    await repo.insert(
      match(
        team1: 'Fominhas',
        team2: 'Saibro FC',
        sport: Sport.volleyball,
        s1: 3,
        s2: 1,
        sets: const <SetScore>[
          SetScore(25, 20),
          SetScore(23, 25),
          SetScore(25, 18),
          SetScore(25, 22),
        ],
        day: 12,
      ),
    );
    await repo.insert(
      match(
        team1: 'Ana',
        team2: 'Bruno',
        sport: Sport.tennis,
        s1: 2,
        s2: 0,
        sets: const <SetScore>[SetScore(6, 4), SetScore(7, 6)],
        seconds: 4260,
        day: 10,
      ),
    );
    await repo.insert(
      match(
        team1: 'Mesa 1',
        team2: 'Mesa 2',
        sport: Sport.tableTennis,
        s1: 1,
        s2: 3,
        sets: const <SetScore>[
          SetScore(11, 7),
          SetScore(9, 11),
          SetScore(8, 11),
          SetScore(10, 12),
        ],
        seconds: 900,
        day: 8,
      ),
    );

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final SettingsStore settings = await SettingsStore.load();
    await tester.pumpWidget(
      MatchMasterApp(settings: settings, repository: repo),
    );
    await tester.pumpAndSettle();
    await drive(tester);
    await expectLater(
      find.byType(MatchMasterApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
    await DatabaseHelper().close();
  }

  setUpAll(loadRealFonts);

  testWidgets('nova partida (escuro)', (WidgetTester tester) async {
    await shoot(tester, 'new_dark', ThemeMode.dark, (_) async {});
  });

  testWidgets('nova partida (claro)', (WidgetTester tester) async {
    await shoot(tester, 'new_light', ThemeMode.light, (_) async {});
  });

  testWidgets('histórico', (WidgetTester tester) async {
    await shoot(tester, 'history', ThemeMode.dark, (WidgetTester t) async {
      await t.tap(find.text('Histórico'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('estatísticas', (WidgetTester tester) async {
    await shoot(tester, 'stats', ThemeMode.dark, (WidgetTester t) async {
      await t.tap(find.text('Estatísticas'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('placar ao vivo', (WidgetTester tester) async {
    await shoot(tester, 'live', ThemeMode.dark, (WidgetTester t) async {
      await t.tap(find.text('Vôlei'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Time 1'),
        'Fominhas',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Time 2'),
        'Saibro FC',
      );
      // O botão fica abaixo da dobra numa tela de celular; a ListView constrói
      // os filhos sob demanda, então é preciso rolar até ele existir.
      // Cada aba do IndexedStack tem a sua lista, então o scrollable precisa
      // ser indicado: o da aba "Nova" é o primeiro da árvore.
      await t.scrollUntilVisible(
        find.text('Começar partida'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Começar partida'));
      for (int i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 120));
      }
      final Finder add = find.widgetWithIcon(IconButton, Icons.add);
      for (int i = 0; i < 24; i++) {
        await t.tap(add.first);
        await t.pump();
      }
      for (int i = 0; i < 22; i++) {
        await t.tap(add.last);
        await t.pump();
      }
    });
  });

  testWidgets('login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferences.resetStatic();
    DatabaseHelper.overrideFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.overridePath = inMemoryDatabasePath;
    await DatabaseHelper().close();

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final SettingsStore settings = await SettingsStore.load();
    await tester.pumpWidget(
      MatchMasterApp(settings: settings, repository: MatchRepository()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MatchMasterApp),
      matchesGoldenFile('../../docs/screenshots/login.png'),
    );
    await DatabaseHelper().close();
  });
}
