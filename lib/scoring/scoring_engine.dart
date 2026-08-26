import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';

/// Como a partida é pontuada.
enum ScoringMode {
  /// Regras oficiais do esporte (games, sets, tie-break, vitória por 2).
  official('Regras oficiais'),

  /// Contador simples de pontos, sem sets — o placar cru do app original.
  free('Contagem livre');

  const ScoringMode(this.label);

  final String label;

  static ScoringMode fromId(String? value) => ScoringMode.values.firstWhere(
        (ScoringMode mode) => mode.name == value,
        orElse: () => ScoringMode.official,
      );
}

/// Regras de pontuação aplicadas a um [ScoreState].
///
/// Toda transição é pura: [addPoint] devolve um novo estado em vez de mutar o
/// atual, o que dá desfazer confiável e testes diretos.
abstract class ScoringEngine {
  const ScoringEngine();

  factory ScoringEngine.of(Sport sport, ScoringMode mode) {
    if (mode == ScoringMode.free) return const FreeScoringEngine();
    return switch (sport) {
      Sport.tennis => const TennisScoringEngine(),
      Sport.tableTennis => const SetScoringEngine(ScoringRules.tableTennis),
      Sport.volleyball => const SetScoringEngine(ScoringRules.volleyball),
    };
  }

  ScoringRules get rules;

  /// Marca um ponto para [side] e devolve o novo estado.
  ///
  /// Se a partida já acabou o estado é devolvido intacto.
  ScoreState addPoint(ScoreState state, TeamSide side);

  /// Rótulo do placar corrente de [side] (no tênis, "15"/"30"/"40"/"AD").
  String pointLabel(ScoreState state, TeamSide side) =>
      (side == TeamSide.team1 ? state.points1 : state.points2).toString();

  /// Encerra a partida manualmente, atribuindo a vitória a quem estiver na
  /// frente. Usado quando o usuário finaliza antes do fim regulamentar.
  ScoreState finishEarly(ScoreState state) {
    if (state.isFinished) return state;
    final ScoreState closed = _closeOpenSet(state);
    final int sets1 = closed.setsWon1;
    final int sets2 = closed.setsWon2;
    if (sets1 > sets2) return closed.copyWith(winner: TeamSide.team1);
    if (sets2 > sets1) return closed.copyWith(winner: TeamSide.team2);
    return closed;
  }

  /// Fecha o set em aberto para que ele apareça no histórico.
  ScoreState _closeOpenSet(ScoreState state) {
    if (state.points1 == 0 && state.points2 == 0) return state;
    return state.copyWith(
      completedSets: <SetScore>[
        ...state.completedSets,
        SetScore(state.points1, state.points2),
      ],
      points1: 0,
      points2: 0,
    );
  }

  /// `true` se um ponto de [side] fecharia o set atual.
  bool isSetPoint(ScoreState state, TeamSide side) {
    if (state.isFinished) return false;
    final ScoreState next = addPoint(state, side);
    return next.completedSets.length > state.completedSets.length;
  }

  /// `true` se um ponto de [side] encerraria a partida.
  bool isMatchPoint(ScoreState state, TeamSide side) {
    if (state.isFinished) return false;
    return addPoint(state, side).isFinished;
  }

  /// Texto curto de contexto ("Deuce", "Match point", "Tie-break").
  String? statusMessage(ScoreState state) {
    if (state.isFinished) return null;
    if (isMatchPoint(state, TeamSide.team1) ||
        isMatchPoint(state, TeamSide.team2)) {
      return 'Match point';
    }
    if (isSetPoint(state, TeamSide.team1) ||
        isSetPoint(state, TeamSide.team2)) {
      return '${rules.setNoun} point';
    }
    return null;
  }

  /// Aplica o resultado de um set encerrado e decide se a partida acabou.
  ScoreState _registerSet(ScoreState state, SetScore set) {
    final List<SetScore> sets = <SetScore>[...state.completedSets, set];
    final int won1 =
        sets.where((SetScore s) => s.winner == TeamSide.team1).length;
    final int won2 =
        sets.where((SetScore s) => s.winner == TeamSide.team2).length;
    TeamSide? winner;
    if (won1 >= rules.setsToWin) winner = TeamSide.team1;
    if (won2 >= rules.setsToWin) winner = TeamSide.team2;
    return ScoreState(completedSets: sets, winner: winner);
  }
}

/// Esportes decididos por pontos corridos dentro do set: vôlei e tênis de mesa.
class SetScoringEngine extends ScoringEngine {
  const SetScoringEngine(this.rules);

  @override
  final ScoringRules rules;

  @override
  ScoreState addPoint(ScoreState state, TeamSide side) {
    if (state.isFinished) return state;

    final int p1 = side == TeamSide.team1 ? state.points1 + 1 : state.points1;
    final int p2 = side == TeamSide.team2 ? state.points2 + 1 : state.points2;

    final int target = rules.targetPointsForSet(state.currentSetIndex);
    final int scored = side == TeamSide.team1 ? p1 : p2;
    final int conceded = side == TeamSide.team1 ? p2 : p1;

    if (scored >= target && scored - conceded >= rules.minLead) {
      return _registerSet(state, SetScore(p1, p2));
    }
    return state.copyWith(points1: p1, points2: p2);
  }
}

/// Tênis: pontos formam games, games formam sets, 6-6 vai para o tie-break.
class TennisScoringEngine extends ScoringEngine {
  const TennisScoringEngine();

  static const List<String> _pointLabels = <String>['0', '15', '30', '40'];

  @override
  ScoringRules get rules => ScoringRules.tennis;

  @override
  String pointLabel(ScoreState state, TeamSide side) {
    final int own = side == TeamSide.team1 ? state.points1 : state.points2;
    final int other = side == TeamSide.team1 ? state.points2 : state.points1;

    if (state.tieBreak) return own.toString();
    if (own >= 3 && other >= 3) {
      if (own == other) return '40';
      return own > other ? 'AD' : '40';
    }
    return _pointLabels[own.clamp(0, _pointLabels.length - 1)];
  }

  @override
  String? statusMessage(ScoreState state) {
    if (state.isFinished) return null;
    // Set/match point vêm primeiro: são a informação mais urgente do placar.
    final String? urgent = super.statusMessage(state);
    if (urgent != null) return urgent;
    if (state.tieBreak) return 'Tie-break';
    if (state.points1 >= 3 && state.points1 == state.points2) return 'Deuce';
    return null;
  }

  @override
  ScoreState addPoint(ScoreState state, TeamSide side) {
    if (state.isFinished) return state;

    final int p1 = side == TeamSide.team1 ? state.points1 + 1 : state.points1;
    final int p2 = side == TeamSide.team2 ? state.points2 + 1 : state.points2;
    final int scored = side == TeamSide.team1 ? p1 : p2;
    final int conceded = side == TeamSide.team1 ? p2 : p1;

    if (state.tieBreak) {
      if (scored >= rules.tieBreakPoints &&
          scored - conceded >= rules.minLead) {
        // Quem vence o tie-break fecha o set em 7-6.
        return _registerSet(
          state,
          side == TeamSide.team1
              ? SetScore(state.games1 + 1, state.games2)
              : SetScore(state.games1, state.games2 + 1),
        );
      }
      return state.copyWith(points1: p1, points2: p2);
    }

    final bool gameWon =
        scored >= rules.pointsPerSet && scored - conceded >= rules.minLead;
    if (!gameWon) {
      return state.copyWith(points1: p1, points2: p2);
    }

    final int g1 = side == TeamSide.team1 ? state.games1 + 1 : state.games1;
    final int g2 = side == TeamSide.team2 ? state.games2 + 1 : state.games2;
    final int gamesScored = side == TeamSide.team1 ? g1 : g2;
    final int gamesConceded = side == TeamSide.team1 ? g2 : g1;

    if (gamesScored >= rules.gamesPerSet &&
        gamesScored - gamesConceded >= rules.minLead) {
      return _registerSet(state, SetScore(g1, g2));
    }

    return state.copyWith(
      points1: 0,
      points2: 0,
      games1: g1,
      games2: g2,
      tieBreak: g1 >= rules.gamesPerSet && g2 >= rules.gamesPerSet,
    );
  }

  @override
  ScoreState _closeOpenSet(ScoreState state) {
    if (state.games1 == 0 && state.games2 == 0) return state;
    return state.copyWith(
      completedSets: <SetScore>[
        ...state.completedSets,
        SetScore(state.games1, state.games2),
      ],
      points1: 0,
      points2: 0,
      games1: 0,
      games2: 0,
      tieBreak: false,
    );
  }
}

/// Contador simples: pontos sobem, nada fecha sozinho.
class FreeScoringEngine extends ScoringEngine {
  const FreeScoringEngine();

  @override
  ScoringRules get rules => const ScoringRules(
        setsToWin: 1,
        pointsPerSet: 0,
        minLead: 0,
        setNoun: 'Set',
      );

  @override
  ScoreState addPoint(ScoreState state, TeamSide side) {
    if (state.isFinished) return state;
    return side == TeamSide.team1
        ? state.copyWith(points1: state.points1 + 1)
        : state.copyWith(points2: state.points2 + 1);
  }

  /// Um ponto a menos, sem nunca ficar negativo.
  ScoreState removePoint(ScoreState state, TeamSide side) {
    if (side == TeamSide.team1 && state.points1 > 0) {
      return state.copyWith(points1: state.points1 - 1);
    }
    if (side == TeamSide.team2 && state.points2 > 0) {
      return state.copyWith(points2: state.points2 - 1);
    }
    return state;
  }

  @override
  String? statusMessage(ScoreState state) => null;
}
