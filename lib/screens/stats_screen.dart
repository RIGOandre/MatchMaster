import 'package:flutter/material.dart';
import 'package:matchmaster/core/theme/app_theme.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/widgets/app_widgets.dart';
import 'package:matchmaster/widgets/sport_glyph.dart';

/// Números do histórico: quanto se jogou e quem está ganhando.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  MatchStats _stats = MatchStats.empty;
  Sport? _sportFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final MatchStats stats =
        await AppScope.of(context).repository.stats(sport: _sportFilter);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: reload, child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (_stats.isEmpty && _sportFilter == null) {
      return ListView(
        children: const <Widget>[
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.insights_outlined,
            title: 'Ainda não há o que somar',
            message: 'As estatísticas aparecem assim que a primeira partida '
                'for salva.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Todos'),
                  showCheckmark: false,
                  selected: _sportFilter == null,
                  onSelected: (_) {
                    setState(() => _sportFilter = null);
                    reload();
                  },
                ),
              ),
              for (final Sport sport in Sport.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(sport.label),
                    avatar: SportGlyph(
                      sport: sport,
                      size: 18,
                      color: _sportFilter == sport
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                    showCheckmark: false,
                    selected: _sportFilter == sport,
                    onSelected: (_) {
                      setState(() => _sportFilter = sport);
                      reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                icon: Icons.sports_score,
                label: 'Partidas',
                value: '${_stats.totalMatches}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.timer_outlined,
                label: 'Tempo em quadra',
                value: formatDuration(_stats.totalSeconds),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                icon: Icons.speed_outlined,
                label: 'Duração média',
                value: formatDuration(_stats.averageSeconds),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.emoji_events_outlined,
                label: 'Líder',
                value: _stats.leader?.name ?? '—',
                accent: AppColors.highlight(Theme.of(context).brightness),
              ),
            ),
          ],
        ),
        if (_sportFilter == null) ...<Widget>[
          const SizedBox(height: 24),
          const SectionTitle('PARTIDAS POR ESPORTE'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: <Widget>[
                  for (final Sport sport in Sport.values)
                    _SportBar(
                      sport: sport,
                      count: _stats.matchesOf(sport),
                      total: _stats.totalMatches,
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionTitle('CLASSIFICAÇÃO DOS TIMES'),
        if (_stats.standings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhuma partida neste filtro.')),
            ),
          )
        else
          Card(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _stats.standings.length; i++)
                  _StandingRow(
                    position: i + 1,
                    standing: _stats.standings[i],
                    isLast: i == _stats.standings.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SportBar extends StatelessWidget {
  const _SportBar({
    required this.sport,
    required this.count,
    required this.total,
  });

  final Sport sport;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double fraction = total == 0 ? 0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          SportGlyph(sport: sport, size: 22),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(sport.label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                color: sportAccent(sport).of(theme.brightness),
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.position,
    required this.standing,
    required this.isLast,
  });

  final int position;
  final TeamStanding standing;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: position == 1
                ? AppColors.highlight(theme.brightness)
                : theme.colorScheme.onSurface.withOpacity(0.08),
            child: Text(
              '$position',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color:
                    position == 1 ? AppColors.ink : theme.colorScheme.onSurface,
              ),
            ),
          ),
          title: Text(
            standing.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${standing.played} ${standing.played == 1 ? 'partida' : 'partidas'}'
            ' · ${standing.wins}V ${standing.draws}E ${standing.losses}D',
          ),
          trailing: Text(
            standing.winRateLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: position == 1
                  ? AppColors.highlight(theme.brightness)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
