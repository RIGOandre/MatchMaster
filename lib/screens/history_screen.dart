import 'package:flutter/material.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/screens/match_detail_screen.dart';
import 'package:matchmaster/widgets/app_widgets.dart';

/// Histórico de partidas salvas, com busca, filtro e ordenação.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<MatchRecord> _matches = <MatchRecord>[];
  Sport? _sportFilter;
  MatchSort _sort = MatchSort.newest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Recarrega a lista. Chamado pelo shell quando uma partida é salva.
  Future<void> reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<MatchRecord> matches =
          await AppScope.of(context).repository.findAll(
                sport: _sportFilter,
                query: _searchController.text,
                sort: _sort,
              );
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _delete(MatchRecord match) async {
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
    if (confirmed != true || !mounted) return;

    final MatchRepository repository = AppScope.of(context).repository;
    await repository.delete(match.id!);
    if (!mounted) return;
    await reload();
    if (!mounted) return;

    showSnack(
      context,
      'Partida excluída.',
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () async {
          await repository.restore(match);
          await reload();
        },
      ),
    );
  }

  Future<void> _openDetail(MatchRecord match) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MatchDetailScreen(match: match),
      ),
    );
    if (changed == true) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: <Widget>[
          PopupMenuButton<MatchSort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (MatchSort value) {
              setState(() => _sort = value);
              reload();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MatchSort>>[
              for (final MatchSort sort in MatchSort.values)
                PopupMenuItem<MatchSort>(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => reload(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por time, jogador ou esporte',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            reload();
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: <Widget>[
                  _FilterChip(
                    label: 'Todos',
                    selected: _sportFilter == null,
                    onSelected: () {
                      setState(() => _sportFilter = null);
                      reload();
                    },
                  ),
                  for (final Sport sport in Sport.values)
                    _FilterChip(
                      label: sport.label,
                      icon: sport.icon,
                      selected: _sportFilter == sport,
                      onSelected: () {
                        setState(() => _sportFilter = sport);
                        reload();
                      },
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Não foi possível carregar o histórico',
        message: _error,
        action: OutlinedButton(
          onPressed: reload,
          child: const Text('Tentar de novo'),
        ),
      );
    }
    if (_matches.isEmpty) {
      final bool filtering =
          _sportFilter != null || _searchController.text.trim().isNotEmpty;
      return EmptyState(
        icon: filtering ? Icons.search_off : Icons.sports_score,
        title: filtering
            ? 'Nenhuma partida encontrada'
            : 'Seu histórico está vazio',
        message: filtering
            ? 'Tente outro termo ou remova o filtro de esporte.'
            : 'Crie uma partida na aba "Nova" para começar a registrar '
                'os resultados.',
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final MatchRecord match = _matches[index];
          return _MatchCard(
            match: match,
            onTap: () => _openDetail(match),
            onDelete: () => _delete(match),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 18),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onTap,
    required this.onDelete,
  });

  final MatchRecord match;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    match.sport.icon,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      match.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Excluir partida',
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      match.team1Name,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: match.outcome == MatchOutcome.team1
                            ? FontWeight.w800
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      match.scoreLine,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.team2Name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: match.outcome == MatchOutcome.team2
                            ? FontWeight.w800
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              if (match.setsSummary.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    match.setsSummary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  _MetaChip(
                    icon: Icons.timer_outlined,
                    text: match.formattedDuration,
                  ),
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    text: formatDate(match.playedAt),
                  ),
                  _MetaChip(
                    icon: match.isDraw
                        ? Icons.handshake_outlined
                        : Icons.emoji_events_outlined,
                    text: match.isDraw ? 'Empate' : match.winnerName,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
