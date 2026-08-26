import 'package:flutter_test/flutter_test.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';

/// Marca [times] pontos seguidos para [side].
ScoreState score(
  ScoringEngine engine,
  ScoreState state,
  TeamSide side,
  int times,
) {
  ScoreState current = state;
  for (int i = 0; i < times; i++) {
    current = engine.addPoint(current, side);
  }
  return current;
}

void main() {
  group('SetScoringEngine (vôlei)', () {
    final ScoringEngine engine =
        ScoringEngine.of(Sport.volleyball, ScoringMode.official);

    test('set fecha em 25 com dois pontos de vantagem', () {
      ScoreState state = score(engine, const ScoreState(), TeamSide.team1, 24);
      state = score(engine, state, TeamSide.team2, 20);
      expect(state.completedSets, isEmpty);

      state = engine.addPoint(state, TeamSide.team1);
      expect(state.completedSets, <SetScore>[const SetScore(25, 20)]);
      expect(state.points1, 0);
      expect(state.setsWon1, 1);
    });

    test('24-24 exige vantagem de dois pontos', () {
      ScoreState state = score(engine, const ScoreState(), TeamSide.team1, 24);
      state = score(engine, state, TeamSide.team2, 24);

      state = engine.addPoint(state, TeamSide.team1); // 25-24: ainda não fecha
      expect(state.completedSets, isEmpty);
      expect(state.points1, 25);

      state = engine.addPoint(state, TeamSide.team2); // 25-25
      expect(state.completedSets, isEmpty);

      state = score(engine, state, TeamSide.team1, 2); // 27-25
      expect(state.completedSets, <SetScore>[const SetScore(27, 25)]);
    });

    test('quinto set (tie-break) é disputado em 15 pontos', () {
      ScoreState state = const ScoreState(
        completedSets: <SetScore>[
          SetScore(25, 20),
          SetScore(20, 25),
          SetScore(25, 20),
          SetScore(20, 25),
        ],
      );
      expect(state.setsWon1, 2);
      expect(state.setsWon2, 2);

      state = score(engine, state, TeamSide.team1, 15);
      expect(state.isFinished, isTrue);
      expect(state.winner, TeamSide.team1);
      expect(state.completedSets.last, const SetScore(15, 0));
    });

    test('partida termina ao vencer três sets e ignora pontos posteriores', () {
      ScoreState state = const ScoreState(
        completedSets: <SetScore>[
          SetScore(25, 10),
          SetScore(25, 10),
        ],
      );
      state = score(engine, state, TeamSide.team1, 25);

      expect(state.winner, TeamSide.team1);
      final ScoreState afterEnd = engine.addPoint(state, TeamSide.team2);
      expect(afterEnd, state, reason: 'partida encerrada não aceita pontos');
    });
  });

  group('SetScoringEngine (tênis de mesa)', () {
    final ScoringEngine engine =
        ScoringEngine.of(Sport.tableTennis, ScoringMode.official);

    test('game fecha em 11 pontos', () {
      final ScoreState state =
          score(engine, const ScoreState(), TeamSide.team2, 11);
      expect(state.completedSets, <SetScore>[const SetScore(0, 11)]);
    });

    test('10-10 vira disputa por dois pontos de vantagem', () {
      ScoreState state = score(engine, const ScoreState(), TeamSide.team1, 10);
      state = score(engine, state, TeamSide.team2, 10);
      state = engine.addPoint(state, TeamSide.team1);
      expect(state.completedSets, isEmpty);
      state = engine.addPoint(state, TeamSide.team1);
      expect(state.completedSets, <SetScore>[const SetScore(12, 10)]);
    });

    test('melhor de cinco: vence quem fizer três games', () {
      ScoreState state = const ScoreState();
      for (int i = 0; i < 3; i++) {
        state = score(engine, state, TeamSide.team1, 11);
      }
      expect(state.isFinished, isTrue);
      expect(state.winner, TeamSide.team1);
      expect(state.completedSets, hasLength(3));
    });

    test('o quinto game não muda de pontuação (só o vôlei tem 15)', () {
      const ScoringRules rules = ScoringRules.tableTennis;
      expect(rules.targetPointsForSet(4), 11);
      expect(ScoringRules.volleyball.targetPointsForSet(4), 15);
    });
  });

  group('TennisScoringEngine', () {
    final ScoringEngine engine =
        ScoringEngine.of(Sport.tennis, ScoringMode.official);

    test('pontos são exibidos como 0/15/30/40', () {
      ScoreState state = const ScoreState();
      expect(engine.pointLabel(state, TeamSide.team1), '0');
      state = engine.addPoint(state, TeamSide.team1);
      expect(engine.pointLabel(state, TeamSide.team1), '15');
      state = engine.addPoint(state, TeamSide.team1);
      expect(engine.pointLabel(state, TeamSide.team1), '30');
      state = engine.addPoint(state, TeamSide.team1);
      expect(engine.pointLabel(state, TeamSide.team1), '40');
    });

    test('deuce e vantagem', () {
      ScoreState state = score(engine, const ScoreState(), TeamSide.team1, 3);
      state = score(engine, state, TeamSide.team2, 3);
      expect(engine.statusMessage(state), 'Deuce');
      expect(engine.pointLabel(state, TeamSide.team1), '40');

      state = engine.addPoint(state, TeamSide.team1);
      expect(engine.pointLabel(state, TeamSide.team1), 'AD');
      expect(engine.pointLabel(state, TeamSide.team2), '40');
      expect(state.games1, 0, reason: 'vantagem ainda não fecha o game');

      state = engine.addPoint(state, TeamSide.team2);
      expect(engine.statusMessage(state), 'Deuce');

      state = score(engine, state, TeamSide.team2, 2);
      expect(state.games2, 1);
      expect(state.points1, 0);
    });

    test('seis games com dois de vantagem fecham o set', () {
      ScoreState state = const ScoreState();
      for (int i = 0; i < 6; i++) {
        state = score(engine, state, TeamSide.team1, 4);
      }
      expect(state.completedSets, <SetScore>[const SetScore(6, 0)]);
      expect(state.games1, 0, reason: 'games zeram no set seguinte');
    });

    test('5-5 não fecha o set: é preciso chegar a 7-5', () {
      ScoreState state = const ScoreState();
      for (int i = 0; i < 5; i++) {
        state = score(engine, state, TeamSide.team1, 4);
        state = score(engine, state, TeamSide.team2, 4);
      }
      expect(state.games1, 5);
      expect(state.games2, 5);

      state = score(engine, state, TeamSide.team1, 4); // 6-5
      expect(state.completedSets, isEmpty);
      state = score(engine, state, TeamSide.team1, 4); // 7-5
      expect(state.completedSets, <SetScore>[const SetScore(7, 5)]);
    });

    test('6-6 aciona o tie-break e o set termina em 7-6', () {
      ScoreState state = const ScoreState();
      for (int i = 0; i < 6; i++) {
        state = score(engine, state, TeamSide.team1, 4);
        state = score(engine, state, TeamSide.team2, 4);
      }
      expect(state.tieBreak, isTrue);
      expect(engine.statusMessage(state), 'Tie-break');
      expect(engine.pointLabel(state, TeamSide.team1), '0');

      state = score(engine, state, TeamSide.team1, 6);
      state = score(engine, state, TeamSide.team2, 6);
      expect(state.completedSets, isEmpty, reason: '6-6 no tie-break continua');

      state = score(engine, state, TeamSide.team1, 2);
      expect(state.completedSets, <SetScore>[const SetScore(7, 6)]);
      expect(state.tieBreak, isFalse, reason: 'novo set começa sem tie-break');
    });

    test('melhor de três sets encerra a partida', () {
      ScoreState state = const ScoreState(
        completedSets: <SetScore>[SetScore(6, 0)],
      );
      for (int i = 0; i < 6; i++) {
        state = score(engine, state, TeamSide.team1, 4);
      }
      expect(state.isFinished, isTrue);
      expect(state.winner, TeamSide.team1);
    });

    test('match point é anunciado antes do ponto decisivo', () {
      ScoreState state = const ScoreState(
        completedSets: <SetScore>[SetScore(6, 0)],
      );
      for (int i = 0; i < 5; i++) {
        state = score(engine, state, TeamSide.team1, 4);
      }
      state =
          score(engine, state, TeamSide.team1, 3); // 40-0, sacando para o jogo
      expect(engine.isMatchPoint(state, TeamSide.team1), isTrue);
      expect(engine.isMatchPoint(state, TeamSide.team2), isFalse);
      expect(engine.statusMessage(state), 'Match point');
    });
  });

  group('FreeScoringEngine', () {
    final ScoringEngine engine =
        ScoringEngine.of(Sport.volleyball, ScoringMode.free);

    test('conta pontos sem nunca fechar sozinho', () {
      final ScoreState state =
          score(engine, const ScoreState(), TeamSide.team1, 40);
      expect(state.points1, 40);
      expect(state.isFinished, isFalse);
      expect(state.completedSets, isEmpty);
    });

    test('remover ponto não passa de zero', () {
      final FreeScoringEngine free = engine as FreeScoringEngine;
      ScoreState state = const ScoreState();
      state = free.removePoint(state, TeamSide.team1);
      expect(state.points1, 0);
      state = free.addPoint(state, TeamSide.team1);
      state = free.removePoint(state, TeamSide.team1);
      expect(state.points1, 0);
    });

    test('encerrar manualmente premia quem estiver na frente', () {
      ScoreState state = score(engine, const ScoreState(), TeamSide.team1, 21);
      state = score(engine, state, TeamSide.team2, 18);
      final ScoreState finished = engine.finishEarly(state);
      expect(finished.winner, TeamSide.team1);
      expect(finished.completedSets, <SetScore>[const SetScore(21, 18)]);
    });

    test('empate não gera vencedor', () {
      ScoreState state = score(engine, const ScoreState(), TeamSide.team1, 10);
      state = score(engine, state, TeamSide.team2, 10);
      expect(engine.finishEarly(state).winner, isNull);
    });
  });

  group('Sport', () {
    test('rótulos legados do banco antigo continuam sendo reconhecidos', () {
      expect(Sport.fromId('tennis'), Sport.tennis);
      expect(Sport.fromId('Tênis'), Sport.tennis);
      expect(Sport.fromId('Tênis de Mesa'), Sport.tableTennis);
      expect(Sport.fromId('Vôlei'), Sport.volleyball);
      expect(Sport.fromId('Volei'), Sport.volleyball);
      expect(Sport.fromId(null), Sport.tennis);
      expect(Sport.fromId('desconhecido'), Sport.tennis);
    });

    test('vôlei aceita times maiores que os de tênis', () {
      expect(Sport.volleyball.teamSizeOptions, <int>[2, 4, 6]);
      expect(Sport.tennis.teamSizeOptions, <int>[1, 2]);
      expect(Sport.maxTeamSize, 6);
    });
  });
}
