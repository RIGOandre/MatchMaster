import 'package:flutter/material.dart';
import 'package:matchmaster/core/theme/app_theme.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:matchmaster/screens/home_shell.dart';
import 'package:matchmaster/screens/live_match_screen.dart';
import 'package:matchmaster/widgets/app_widgets.dart';
import 'package:matchmaster/widgets/sport_glyph.dart';

/// Configuração de uma nova partida.
class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _team1Controller = TextEditingController();
  final TextEditingController _team2Controller = TextEditingController();

  late final List<TextEditingController> _team1Players =
      List.generate(Sport.maxTeamSize, (_) => TextEditingController());
  late final List<TextEditingController> _team2Players =
      List.generate(Sport.maxTeamSize, (_) => TextEditingController());

  Sport _sport = Sport.tennis;
  ScoringMode _mode = ScoringMode.official;
  late int _teamSize = _sport.defaultTeamSize;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final AppScope scope = AppScope.of(context);
    _sport = scope.settings.defaultSport;
    _mode = scope.settings.scoringMode;
    _teamSize = _sport.defaultTeamSize;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _team1Controller.dispose();
    _team2Controller.dispose();
    for (final TextEditingController c in <TextEditingController>[
      ..._team1Players,
      ..._team2Players,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectSport(Sport sport) {
    setState(() {
      _sport = sport;
      // O app anterior deixava "2 jogadores" selecionado ao trocar para o vôlei,
      // que só oferece 4 ou 6 — o número exibido não correspondia ao esporte.
      if (!sport.teamSizeOptions.contains(_teamSize)) {
        _teamSize = sport.defaultTeamSize;
      }
    });
  }

  List<String> _playersOf(List<TextEditingController> controllers) {
    return controllers
        .take(_teamSize)
        .map((TextEditingController c) => c.text.trim())
        .where((String name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      showSnack(context, 'Confira os campos destacados para começar.');
      return;
    }

    final AppScope scope = AppScope.of(context);
    await scope.settings.setDefaultSport(_sport);
    await scope.settings.setScoringMode(_mode);

    if (!mounted) return;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LiveMatchScreen(
          name: _nameController.text.trim(),
          sport: _sport,
          scoringMode: _mode,
          team1Name: _team1Controller.text.trim(),
          team2Name: _team2Controller.text.trim(),
          team1Players: _playersOf(_team1Players),
          team2Players: _playersOf(_team2Players),
        ),
      ),
    );

    if (!mounted || saved != true) return;
    _resetForm();
    // Leva o usuário ao histórico, onde a partida recém-salva aparece no topo.
    context.findAncestorStateOfType<HomeShellState>()?.goTo(1);
  }

  void _resetForm() {
    _nameController.clear();
    _team1Controller.clear();
    _team2Controller.clear();
    for (final TextEditingController c in <TextEditingController>[
      ..._team1Players,
      ..._team2Players,
    ]) {
      c.clear();
    }
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nova partida')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              const SectionTitle('ESPORTE'),
              _SportPicker(selected: _sport, onSelected: _selectSport),
              const SizedBox(height: 24),
              const SectionTitle('COMO CONTAR OS PONTOS'),
              SegmentedButton<ScoringMode>(
                segments: <ButtonSegment<ScoringMode>>[
                  for (final ScoringMode mode in ScoringMode.values)
                    ButtonSegment<ScoringMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                ],
                selected: <ScoringMode>{_mode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<ScoringMode> value) =>
                    setState(() => _mode = value.first),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == ScoringMode.official
                    ? _officialRulesDescription(_sport)
                    : 'Contador simples: os pontos sobem e a partida termina '
                        'quando você quiser.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle('PARTIDA'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome da partida (opcional)',
                  hintText: 'Ex.: Quarta à noite',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle('TIMES'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _team1Controller,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Time 1'),
                      validator: _validateTeamName,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _team2Controller,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Time 2'),
                      validator: _validateTeamName,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle('JOGADORES POR TIME'),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final int size in _sport.teamSizeOptions)
                    ChoiceChip(
                      label: Text(size == 1 ? '1 jogador' : '$size jogadores'),
                      showCheckmark: false,
                      selected: _teamSize == size,
                      onSelected: (_) => setState(() => _teamSize = size),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _PlayerFields(
                teamLabel: _team1Controller.text.trim().isEmpty
                    ? 'Time 1'
                    : _team1Controller.text.trim(),
                controllers: _team1Players.take(_teamSize).toList(),
              ),
              const SizedBox(height: 16),
              _PlayerFields(
                teamLabel: _team2Controller.text.trim().isEmpty
                    ? 'Time 2'
                    : _team2Controller.text.trim(),
                controllers: _team2Players.take(_teamSize).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Começar partida'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateTeamName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Informe o nome do time.';
    return null;
  }

  static String _officialRulesDescription(Sport sport) => switch (sport) {
        Sport.tennis =>
          'Pontos 15/30/40 com vantagem, 6 games por set (tie-break em 6-6) '
              'e melhor de 3 sets.',
        Sport.tableTennis =>
          'Games até 11 pontos com 2 de vantagem, melhor de 5 games.',
        Sport.volleyball =>
          'Sets até 25 pontos com 2 de vantagem, quinto set em 15, '
              'melhor de 5 sets.',
      };
}

class _SportPicker extends StatelessWidget {
  const _SportPicker({required this.selected, required this.onSelected});

  final Sport selected;
  final ValueChanged<Sport> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        for (final Sport sport in Sport.values) ...<Widget>[
          Expanded(
            child: _SportCard(
              sport: sport,
              selected: sport == selected,
              onTap: () => onSelected(sport),
              theme: theme,
            ),
          ),
          if (sport != Sport.values.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.sport,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final Sport sport;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color accent = sportAccent(sport).of(theme.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: sport.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: selected ? accent : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
            color: selected ? accent.withOpacity(0.12) : Colors.transparent,
          ),
          child: Column(
            children: <Widget>[
              SportGlyph(sport: sport, size: 52, color: accent),
              const SizedBox(height: 12),
              Text(
                sport.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? accent : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerFields extends StatelessWidget {
  const _PlayerFields({required this.teamLabel, required this.controllers});

  final String teamLabel;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          teamLabel,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: controllers[i],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Jogador ${i + 1} (opcional)',
                isDense: true,
                prefixIcon: const Icon(Icons.person_outline, size: 20),
              ),
            ),
          ),
      ],
    );
  }
}
