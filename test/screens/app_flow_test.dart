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

/// Define as preferências do teste.
///
/// `setMockInitialValues` sozinho não basta: o `SharedPreferences` guarda a
/// instância já carregada num campo estático, então sem o reset um teste
/// herdaria as preferências do teste anterior.
void setPrefs([Map<String, Object> values = const <String, Object>{}]) {
  SharedPreferences.setMockInitialValues(values);
  SharedPreferences.resetStatic();
}

/// Preferências de quem já entrou no app.
void signedIn({String userName = 'Camila'}) => setPrefs(<String, Object>{
      'remember_me': true,
      'user_name': userName,
    });

/// Avança alguns quadros sem esperar a árvore ficar estável.
///
/// A tela de partida mantém um cronômetro com `Timer.periodic`, então
/// `pumpAndSettle` nunca retornaria enquanto ela estiver visível.
Future<void> pumpFrames(WidgetTester tester, {int frames = 6}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> pumpApp(WidgetTester tester, MatchRepository repository) async {
  // Uma janela alta evita que os testes dependam de rolagem: as telas do app
  // são listas longas e o padrão de 800x600 esconde metade dos controles.
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final SettingsStore settings = await SettingsStore.load();
  await tester.pumpWidget(
    MatchMasterApp(settings: settings, repository: repository),
  );
  await tester.pumpAndSettle();
}

MatchRecord sampleMatch({
  String team1 = 'Alfa',
  String team2 = 'Beta',
  Sport sport = Sport.volleyball,
  int score1 = 3,
  int score2 = 1,
}) {
  return MatchRecord(
    name: '',
    sport: sport,
    scoringMode: ScoringMode.official,
    team1Name: team1,
    team2Name: team2,
    team1Players: const <String>['Ana'],
    team2Players: const <String>['Bruno'],
    team1Score: score1,
    team2Score: score2,
    sets: const <SetScore>[SetScore(25, 20)],
    durationSeconds: 900,
    outcome: score1 >= score2 ? MatchOutcome.team1 : MatchOutcome.team2,
    playedAt: DateTime(2024, 4, 1, 20),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late MatchRepository repository;

  setUp(() async {
    setPrefs();
    // `databaseFactoryFfiNoIsolate` roda o SQLite no mesmo isolate: dentro de
    // um `testWidgets` o tempo é falso e um future que depende de outro isolate
    // nunca completaria entre os `pump`.
    DatabaseHelper.overrideFactory = databaseFactoryFfiNoIsolate;
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

  group('login', () {
    testWidgets('não avança com os campos em branco', (WidgetTester tester) async {
      await pumpApp(tester, repository);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe uma senha.'), findsOneWidget);
      expect(find.text('Nova partida'), findsNothing);
    });

    testWidgets('entra e guarda o nome quando os campos são válidos',
        (WidgetTester tester) async {
      await pumpApp(tester, repository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Camila Souza',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'segredo',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Nova partida'), findsOneWidget);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'Camila Souza');
      expect(prefs.getBool('remember_me'), isFalse);
    });

    testWidgets('"Lembrar de mim" pula o login na próxima abertura',
        (WidgetTester tester) async {
      signedIn(userName: 'Camila');
      await pumpApp(tester, repository);

      expect(find.text('Nova partida'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsNothing);
    });
  });

  group('nova partida', () {
    Future<void> signIn(WidgetTester tester) async {
      signedIn(userName: 'Camila');
      await pumpApp(tester, repository);
    }

    testWidgets('exige o nome dos dois times', (WidgetTester tester) async {
      await signIn(tester);

      await tester.tap(find.text('Começar partida'));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome do time.'), findsNWidgets(2));
      expect(find.text('Confira os campos destacados para começar.'),
          findsOneWidget);
    });

    testWidgets('as opções de jogadores acompanham o esporte escolhido',
        (WidgetTester tester) async {
      await signIn(tester);

      // Tênis: 1 ou 2 jogadores.
      expect(find.widgetWithText(ChoiceChip, '1 jogador'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '2 jogadores'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '6 jogadores'), findsNothing);

      await tester.tap(find.text('Vôlei'));
      await tester.pumpAndSettle();

      // Vôlei: 2, 4 ou 6 — e nunca "1 jogador".
      expect(find.widgetWithText(ChoiceChip, '1 jogador'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '4 jogadores'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '6 jogadores'), findsOneWidget);
    });

    testWidgets('joga uma partida inteira e salva no histórico',
        (WidgetTester tester) async {
      await signIn(tester);

      await tester.tap(find.text('Tênis de Mesa'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Time 1'),
        'Alfa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Time 2'),
        'Beta',
      );
      await tester.tap(find.text('Começar partida'));
      await pumpFrames(tester);

      expect(find.text('Tênis de Mesa'), findsOneWidget);

      // 3 games de 11 pontos fecham a melhor de 5.
      final Finder addAlfa = find.widgetWithIcon(IconButton, Icons.add).first;
      for (int i = 0; i < 33; i++) {
        await tester.tap(addAlfa);
        await tester.pump();
      }

      expect(find.text('Alfa venceu!'), findsOneWidget);

      await tester.tap(find.text('Salvar resultado'));
      await tester.pumpAndSettle();

      final List<MatchRecord> saved = await repository.findAll();
      expect(saved, hasLength(1));
      expect(saved.single.team1Score, 3);
      expect(saved.single.team2Score, 0);
      expect(saved.single.outcome, MatchOutcome.team1);
      expect(saved.single.sport, Sport.tableTennis);

      // Ao salvar, o app leva o usuário direto para o histórico.
      expect(find.text('Histórico'), findsWidgets);
    });

    testWidgets('desfazer devolve o ponto anterior', (WidgetTester tester) async {
      await signIn(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Time 1'),
        'Ana',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Time 2'),
        'Bruno',
      );
      await tester.tap(find.text('Começar partida'));
      await pumpFrames(tester);

      final Finder addAna = find.widgetWithIcon(IconButton, Icons.add).first;
      await tester.tap(addAna);
      await tester.pump();
      expect(find.text('15'), findsOneWidget);
      await tester.tap(addAna);
      await tester.pump();
      expect(find.text('30'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      expect(find.text('30'), findsNothing);
      expect(find.text('15'), findsOneWidget);

      // Sair pede confirmação e descarta a partida, encerrando o cronômetro.
      await tester.pageBack();
      await pumpFrames(tester);
      expect(find.text('Sair sem salvar?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('Nova partida'), findsOneWidget);
      expect(await repository.findAll(), isEmpty);
    });
  });

  group('histórico', () {
    Future<void> openHistory(WidgetTester tester) async {
      signedIn();
      await pumpApp(tester, repository);
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra estado vazio sem partidas', (WidgetTester tester) async {
      await openHistory(tester);
      expect(find.text('Seu histórico está vazio'), findsOneWidget);
    });

    testWidgets('lista as partidas salvas', (WidgetTester tester) async {
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Beta'));
      await repository.insert(
        sampleMatch(team1: 'Gama', team2: 'Delta', sport: Sport.tennis),
      );
      await openHistory(tester);

      expect(find.text('Alfa vs Beta'), findsOneWidget);
      expect(find.text('Gama vs Delta'), findsOneWidget);
    });

    testWidgets('filtra por esporte', (WidgetTester tester) async {
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Beta'));
      await repository.insert(
        sampleMatch(team1: 'Gama', team2: 'Delta', sport: Sport.tennis),
      );
      await openHistory(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Tênis'));
      await tester.pumpAndSettle();

      expect(find.text('Gama vs Delta'), findsOneWidget);
      expect(find.text('Alfa vs Beta'), findsNothing);
    });

    testWidgets('busca por nome de jogador', (WidgetTester tester) async {
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Beta'));
      await openHistory(tester);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma partida encontrada'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Ana');
      await tester.pumpAndSettle();
      expect(find.text('Alfa vs Beta'), findsOneWidget);
    });

    testWidgets('excluir pede confirmação e permite desfazer',
        (WidgetTester tester) async {
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Beta'));
      await openHistory(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Excluir partida?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(await repository.findAll(), hasLength(1));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(await repository.findAll(), isEmpty);

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(await repository.findAll(), hasLength(1));
    });

    testWidgets('abre os detalhes com o placar set a set',
        (WidgetTester tester) async {
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Beta'));
      await openHistory(tester);

      await tester.tap(find.text('Alfa vs Beta'));
      await tester.pumpAndSettle();

      expect(find.text('Detalhes da partida'), findsOneWidget);
      expect(find.text('1º Set'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });
  });

  group('estatísticas', () {
    testWidgets('agrega as partidas salvas', (WidgetTester tester) async {
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Beta'));
      await repository.insert(sampleMatch(team1: 'Alfa', team2: 'Gama'));
      signedIn();
      await pumpApp(tester, repository);

      await tester.tap(find.text('Estatísticas'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);
      expect(find.text('Alfa'), findsWidgets);
      expect(find.text('100%'), findsOneWidget);
    });
  });

  group('navegação', () {
    testWidgets('trocar de aba não empilha telas', (WidgetTester tester) async {
      // Regressão: cada botão da barra inferior chamava Navigator.push, então
      // ir e voltar entre abas empilhava telas indefinidamente.
      signedIn();
      await pumpApp(tester, repository);

      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Histórico'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nova'));
        await tester.pumpAndSettle();
      }

      expect(find.byType(Navigator), findsOneWidget);
      expect(find.text('Nova partida'), findsOneWidget);
    });
  });

  group('perfil', () {
    testWidgets('permite editar o nome', (WidgetTester tester) async {
      signedIn(userName: 'Camila');
      await pumpApp(tester, repository);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Camila'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      // As outras abas do IndexedStack também têm campos de texto, então o
      // campo precisa ser buscado dentro do diálogo.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Camila Souza',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Camila Souza'), findsOneWidget);
    });

    testWidgets('sair volta para a tela de login', (WidgetTester tester) async {
      signedIn();
      await pumpApp(tester, repository);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
    });
  });
}
