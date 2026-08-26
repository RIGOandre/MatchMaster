import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matchmaster/core/theme/app_theme.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:matchmaster/widgets/app_widgets.dart';
import 'package:matchmaster/widgets/sport_glyph.dart';

/// Detalhes de uma partida salva, com o placar set a set.
class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({super.key, required this.match});

  final MatchRecord match;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: match.toShareText()));
    if (!context.mounted) return;
    showSnack(context, 'Resumo copiado.');
  }

  Future<void> _delete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Excluir partida?'),
        content: Text('"${match.title}" sairá do histórico.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppScope.of(context).repository.delete(match.id!);
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String setNoun = match.scoringMode == ScoringMode.official
        ? match.sport.rules.setNoun
        : 'Parcial';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da partida'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copiar resumo',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copy(context),
          ),
          IconButton(
            tooltip: 'Excluir partida',
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error,
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  SportGlyph(sport: match.sport, size: 52),
                  const SizedBox(height: 10),
                  Text(
                    match.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.sport.label} · ${formatDateTime(match.playedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _TeamBlock(
                        name: match.team1Name,
                        players: match.team1Players,
                        won: match.outcome == MatchOutcome.team1,
                        accent: AppColors.team1(theme.brightness),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        match.scoreLine,
                        style: theme.textTheme.displaySmall,
                      ),
                    ),
                    Expanded(
                      child: _TeamBlock(
                        name: match.team2Name,
                        players: match.team2Players,
                        won: match.outcome == MatchOutcome.team2,
                        accent: AppColors.team2(theme.brightness),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    icon: Icons.timer_outlined,
                    label: 'Duração',
                    value: match.formattedDuration,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: match.isDraw
                        ? Icons.handshake_outlined
                        : Icons.emoji_events_outlined,
                    label: match.isDraw ? 'Resultado' : 'Vencedor',
                    value: match.winnerName,
                    accent: match.isDraw
                        ? null
                        : AppColors.highlight(theme.brightness),
                  ),
                ),
              ],
            ),
            if (match.sets.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              SectionTitle('${setNoun.toUpperCase()}S'),
              Card(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < match.sets.length; i++)
                      _SetRow(
                        index: i,
                        set: match.sets[i],
                        setNoun: setNoun,
                        isLast: i == match.sets.length - 1,
                        team1Color: AppColors.team1(theme.brightness),
                        team2Color: AppColors.team2(theme.brightness),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionTitle('COMO FOI CONTADO'),
            Card(
              child: ListTile(
                leading: Icon(
                  match.scoringMode == ScoringMode.official
                      ? Icons.rule
                      : Icons.plus_one,
                  color: theme.colorScheme.primary,
                ),
                title: Text(match.scoringMode.label),
                subtitle: Text(
                  match.scoringMode == ScoringMode.official
                      ? 'Placar segue as regras oficiais do esporte.'
                      : 'Contagem livre de pontos.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.name,
    required this.players,
    required this.won,
    required this.accent,
  });

  final String name;
  final List<String> players;
  final bool won;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          name,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: won ? FontWeight.w900 : FontWeight.w500,
            color: accent,
          ),
        ),
        if (players.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            players.join('\n'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.setNoun,
    required this.isLast,
    required this.team1Color,
    required this.team2Color,
  });

  final int index;
  final SetScore set;
  final String setNoun;
  final bool isLast;
  final Color team1Color;
  final Color team2Color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${index + 1}º $setNoun',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              Text(
                '${set.team1}',
                style: TextStyle(
                  fontWeight: set.winner == TeamSide.team1
                      ? FontWeight.w900
                      : FontWeight.w400,
                  color: set.winner == TeamSide.team1 ? team1Color : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('-'),
              ),
              Text(
                '${set.team2}',
                style: TextStyle(
                  fontWeight: set.winner == TeamSide.team2
                      ? FontWeight.w900
                      : FontWeight.w400,
                  color: set.winner == TeamSide.team2 ? team2Color : null,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
