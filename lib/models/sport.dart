import 'package:flutter/material.dart';

/// Esportes suportados pelo MatchMaster.
///
/// O [id] é o valor persistido no banco e nunca deve mudar. Os rótulos antigos
/// (gravados em versões anteriores do app, quando o esporte era salvo pelo nome
/// em português) continuam sendo aceitos por [Sport.fromId].
enum Sport {
  tennis(
    id: 'tennis',
    label: 'Tênis',
    asset: 'assets/tenis.png',
    icon: Icons.sports_tennis,
    teamSizeOptions: <int>[1, 2],
    legacyLabels: <String>['Tênis', 'Tenis'],
    rules: ScoringRules.tennis,
  ),
  tableTennis(
    id: 'table_tennis',
    label: 'Tênis de Mesa',
    asset: 'assets/tenis_mesa.png',
    icon: Icons.sports_tennis_outlined,
    teamSizeOptions: <int>[1, 2],
    legacyLabels: <String>['Tênis de Mesa', 'Tenis de Mesa'],
    rules: ScoringRules.tableTennis,
  ),
  volleyball(
    id: 'volleyball',
    label: 'Vôlei',
    asset: 'assets/volei.jpg',
    icon: Icons.sports_volleyball,
    teamSizeOptions: <int>[2, 4, 6],
    legacyLabels: <String>['Vôlei', 'Volei'],
    rules: ScoringRules.volleyball,
  );

  const Sport({
    required this.id,
    required this.label,
    required this.asset,
    required this.icon,
    required this.teamSizeOptions,
    required this.legacyLabels,
    required this.rules,
  });

  final String id;
  final String label;
  final String asset;
  final IconData icon;

  /// Quantidades de jogadores por time aceitas para o esporte.
  final List<int> teamSizeOptions;

  /// Rótulos gravados por versões antigas do banco.
  final List<String> legacyLabels;

  final ScoringRules rules;

  int get defaultTeamSize => teamSizeOptions.first;

  /// Maior time possível — usado para dimensionar os campos de jogadores.
  static int get maxTeamSize => Sport.values
      .expand((Sport sport) => sport.teamSizeOptions)
      .reduce((int a, int b) => a > b ? a : b);

  /// Converte um valor persistido de volta para o enum.
  ///
  /// Aceita o [id] atual e os rótulos legados. Retorna [Sport.tennis] quando o
  /// valor é desconhecido, para que um registro antigo nunca quebre a listagem.
  static Sport fromId(String? value) {
    if (value == null) return Sport.tennis;
    final String normalized = value.trim();
    for (final Sport sport in Sport.values) {
      if (sport.id == normalized) return sport;
      if (sport.label == normalized) return sport;
      if (sport.legacyLabels.contains(normalized)) return sport;
    }
    return Sport.tennis;
  }
}

/// Regras de pontuação de um esporte.
class ScoringRules {
  const ScoringRules({
    required this.setsToWin,
    required this.pointsPerSet,
    required this.minLead,
    this.decidingSetPoints,
    this.usesGames = false,
    this.gamesPerSet = 0,
    this.tieBreakPoints = 0,
    required this.setNoun,
  });

  /// Tênis: melhor de 3 sets, cada set com 6 games e tie-break em 6-6.
  static const ScoringRules tennis = ScoringRules(
    setsToWin: 2,
    pointsPerSet: 4,
    minLead: 2,
    usesGames: true,
    gamesPerSet: 6,
    tieBreakPoints: 7,
    setNoun: 'Set',
  );

  /// Tênis de mesa: melhor de 5 games de 11 pontos.
  static const ScoringRules tableTennis = ScoringRules(
    setsToWin: 3,
    pointsPerSet: 11,
    minLead: 2,
    setNoun: 'Game',
  );

  /// Vôlei: melhor de 5 sets de 25 pontos, com o tie-break decisivo em 15.
  static const ScoringRules volleyball = ScoringRules(
    setsToWin: 3,
    pointsPerSet: 25,
    minLead: 2,
    decidingSetPoints: 15,
    setNoun: 'Set',
  );

  /// Sets necessários para vencer a partida.
  final int setsToWin;

  /// Pontos para fechar um set (no tênis, pontos para fechar um game).
  final int pointsPerSet;

  /// Vantagem mínima para fechar um set.
  final int minLead;

  /// Pontuação alvo do set decisivo, quando diferente (vôlei: 15).
  final int? decidingSetPoints;

  /// Se o esporte conta games dentro do set (tênis).
  final bool usesGames;

  /// Games necessários para fechar um set.
  final int gamesPerSet;

  /// Pontos do tie-break.
  final int tieBreakPoints;

  /// Como o app chama um set neste esporte ("Set" ou "Game").
  final String setNoun;

  /// Número máximo de sets da partida (melhor de).
  int get maxSets => setsToWin * 2 - 1;

  /// Pontuação alvo do set de índice [setIndex] (base zero).
  int targetPointsForSet(int setIndex) {
    if (decidingSetPoints != null && setIndex == maxSets - 1) {
      return decidingSetPoints!;
    }
    return pointsPerSet;
  }
}
