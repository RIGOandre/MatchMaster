import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/score_state.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:matchmaster/widgets/app_widgets.dart';

/// Placar ao vivo.
class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({
    super.key,
    required this.name,
    required this.sport,
    required this.scoringMode,
    required this.team1Name,
    required this.team2Name,
    required this.team1Players,
    required this.team2Players,
  });

  final String name;
  final Sport sport;
  final ScoringMode scoringMode;
  final String team1Name;
  final String team2Name;
  final List<String> team1Players;
  final List<String> team2Players;

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final ScoringEngine _engine =
      ScoringEngine.of(widget.sport, widget.scoringMode);

  ScoreState _score = const ScoreState();

  /// Estados anteriores, para o "desfazer".
  final List<ScoreState> _history = <ScoreState>[];

  Timer? _timer;

  /// O cronômetro atualiza só este notifier, e não a tela inteira: antes um
  /// `setState` por segundo reconstruía todo o placar.
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);

  bool _running = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed.value++;
    });
  }

  void _toggleTimer() {
    setState(() {
      _running = !_running;
      if (_running) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _addPoint(TeamSide side) {
    if (_score.isFinished) return;
    final ScoreState next = _engine.addPoint(_score, side);
    if (next == _score) return;

    setState(() {
      _history.add(_score);
      _score = next;
    });
    HapticFeedback.selectionClick();

    if (next.isFinished) {
      _timer?.cancel();
      _running = false;
      HapticFeedback.mediumImpact();
    }
  }

  void _removePoint(TeamSide side) {
    final ScoringEngine engine = _engine;
    if (engine is! FreeScoringEngine) return;
    final ScoreState next = engine.removePoint(_score, side);
    if (next == _score) return;
    setState(() {
      _history.add(_score);
      _score = next;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() => _score = _history.removeLast());
  }

  Future<bool> _confirmDiscard() async {
    if (_history.isEmpty && !_score.isFinished) return true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'A partida em andamento será descartada e não entrará no histórico.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar jogando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _finishAndSave() async {
    if (_saving) return;

    ScoreState finalScore = _score;
    if (!finalScore.isFinished) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Encerrar a partida?'),
          content: Text(
            widget.scoringMode == ScoringMode.official
                ? 'A partida ainda não chegou ao fim regulamentar. '
                    'Vence quem estiver na frente.'
                : 'A partida será salva com o placar atual.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Encerrar e salvar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      finalScore = _engine.finishEarly(_score);
    }

    setState(() => _saving = true);
    _timer?.cancel();

    final MatchRepository repository = AppScope.of(context).repository;

    final MatchRecord record = MatchRecord.fromScore(
      name: widget.name,
      sport: widget.sport,
      scoringMode: widget.scoringMode,
      team1Name: widget.team1Name,
      team2Name: widget.team2Name,
      team1Players: widget.team1Players,
      team2Players: widget.team2Players,
      score: finalScore,
      durationSeconds: _elapsed.value,
      playedAt: DateTime.now(),
    );

    try {
      await repository.insert(record);
      // Sem esta checagem, um erro no banco levaria a mexer num contexto já
      // desmontado — a versão anterior usava o context depois do await.
      if (!mounted) return;
      showSnack(context, 'Partida salva no histórico.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _running = false;
      });
      showSnack(context, 'Não foi possível salvar a partida: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isFree = widget.scoringMode == ScoringMode.free;
    final String? status = _engine.statusMessage(_score);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          navigator.pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.name.trim().isEmpty ? widget.sport.label : widget.name,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Desfazer último ponto',
              onPressed: _history.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _TimerBar(
                elapsed: _elapsed,
                running: _running,
                onToggle: _score.isFinished ? null : _toggleTimer,
              ),
              if (status != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    status.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 8),
                      if (!isFree) _SetsBadge(score: _score, engine: _engine),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _ScoreColumn(
                              teamName: widget.team1Name,
                              players: widget.team1Players,
                              label: _engine.pointLabel(_score, TeamSide.team1),
                              setsWon: _score.setsWon1,
                              showSets: !isFree,
                              highlight: _score.winner == TeamSide.team1,
                              enabled: !_score.isFinished,
                              allowDecrement: isFree,
                              onAdd: () => _addPoint(TeamSide.team1),
                              onRemove: () => _removePoint(TeamSide.team1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ScoreColumn(
                              teamName: widget.team2Name,
                              players: widget.team2Players,
                              label: _engine.pointLabel(_score, TeamSide.team2),
                              setsWon: _score.setsWon2,
                              showSets: !isFree,
                              highlight: _score.winner == TeamSide.team2,
                              enabled: !_score.isFinished,
                              allowDecrement: isFree,
                              onAdd: () => _addPoint(TeamSide.team2),
                              onRemove: () => _removePoint(TeamSide.team2),
                            ),
                          ),
                        ],
                      ),
                      if (_score.completedSets.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 24),
                        _SetHistory(score: _score, engine: _engine),
                      ],
                      if (_score.isFinished) ...<Widget>[
                        const SizedBox(height: 24),
                        _WinnerBanner(
                          winnerName: _score.winner == TeamSide.team1
                              ? widget.team1Name
                              : widget.team2Name,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _finishAndSave,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _score.isFinished
                        ? 'Salvar resultado'
                        : 'Encerrar e salvar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({
    required this.elapsed,
    required this.running,
    required this.onToggle,
  });

  final ValueNotifier<int> elapsed;
  final bool running;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          ValueListenableBuilder<int>(
            valueListenable: elapsed,
            builder: (BuildContext context, int seconds, _) => Text(
              formatDuration(seconds),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: running ? 'Pausar cronômetro' : 'Retomar cronômetro',
            onPressed: onToggle,
            icon: Icon(running ? Icons.pause_circle : Icons.play_circle),
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SetsBadge extends StatelessWidget {
  const _SetsBadge({required this.score, required this.engine});

  final ScoreState score;
  final ScoringEngine engine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      '${engine.rules.setNoun}s  ${score.setsWon1} - ${score.setsWon2}'
      '${score.tieBreak ? '  ·  tie-break' : ''}',
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.7),
        letterSpacing: 1,
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.teamName,
    required this.players,
    required this.label,
    required this.setsWon,
    required this.showSets,
    required this.highlight,
    required this.enabled,
    required this.allowDecrement,
    required this.onAdd,
    required this.onRemove,
  });

  final String teamName;
  final List<String> players;
  final String label;
  final int setsWon;
  final bool showSets;
  final bool highlight;
  final bool enabled;
  final bool allowDecrement;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          teamName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: highlight ? theme.colorScheme.primary : null,
          ),
        ),
        if (players.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            players.join(', '),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // O placar inteiro é o alvo do toque: mirar num ícone pequeno no meio
        // de um jogo é a parte mais frustrante de marcar ponto pelo celular.
        Semantics(
          button: true,
          label: 'Marcar ponto para $teamName',
          child: InkWell(
            onTap: enabled ? onAdd : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: highlight
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: highlight ? 2 : 1,
                ),
              ),
              child: Column(
                children: <Widget>[
                  FittedBox(
                    child: Text(
                      label,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (showSets) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '$setsWon',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton.filled(
              tooltip: 'Ponto para $teamName',
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add),
            ),
            if (allowDecrement) ...<Widget>[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Remover ponto de $teamName',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.remove),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SetHistory extends StatelessWidget {
  const _SetHistory({required this.score, required this.engine});

  final ScoreState score;
  final ScoringEngine engine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${engine.rules.setNoun}s encerrados',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (int i = 0; i < score.completedSets.length; i++)
                  Chip(
                    label: Text(
                      '${i + 1}º: ${score.completedSets[i].team1}'
                      '-${score.completedSets[i].team2}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.winnerName});

  final String winnerName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.emoji_events, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            '$winnerName venceu!',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
