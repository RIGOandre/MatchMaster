import 'package:flutter/material.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/data/settings_store.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/screens/home_shell.dart';
import 'package:matchmaster/screens/login_screen.dart';
import 'package:matchmaster/widgets/app_widgets.dart';

/// Perfil e preferências.
///
/// O nome deixa de ser o texto fixo "André Rigo" do código e passa a ser
/// editável, guardado junto das demais preferências.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  MatchStats _stats = MatchStats.empty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    final MatchStats stats = await AppScope.of(context).repository.stats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _editName() async {
    final SettingsStore settings = AppScope.of(context).settings;
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _NameDialog(initialName: settings.userName),
    );

    if (name == null || !mounted) return;
    await settings.setUserName(name);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Apagar todo o histórico?'),
        content: const Text(
          'Todas as partidas salvas serão removidas deste aparelho. '
          'Não dá para desfazer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await AppScope.of(context).repository.deleteAll();
    if (!mounted) return;
    await _loadStats();
    if (!mounted) return;
    context.findAncestorStateOfType<HomeShellState>()?.refreshData();
    showSnack(context, 'Histórico apagado.');
  }

  Future<void> _signOut() async {
    await AppScope.of(context).settings.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = AppScope.of(context).settings;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                InitialsAvatar(
                  initials: initialsOf(settings.userName),
                  radius: 34,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        settings.userName,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _stats.totalMatches == 1
                            ? '1 partida registrada'
                            : '${_stats.totalMatches} partidas registradas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar nome',
                  onPressed: _editName,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            const SectionTitle('APARÊNCIA'),
            Card(
              child: Column(
                children: <Widget>[
                  for (final ThemeMode mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      groupValue: settings.themeMode,
                      onChanged: (ThemeMode? value) async {
                        if (value == null) return;
                        await settings.setThemeMode(value);
                        if (mounted) setState(() {});
                      },
                      title: Text(_themeLabel(mode)),
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('DADOS'),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: const Text('Apagar histórico'),
                    subtitle: const Text('Remove todas as partidas salvas'),
                    onTap: _clearHistory,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sair'),
                    subtitle: const Text('Volta para a tela de entrada'),
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'MatchMaster · seus dados ficam só neste aparelho',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Escuro',
        ThemeMode.light => 'Claro',
        ThemeMode.system => 'Seguir o sistema',
      };
}

/// Diálogo de edição do nome.
///
/// O controller pertence ao diálogo e é liberado no `dispose` dele. Criá-lo
/// fora e descartá-lo assim que `showDialog` retorna quebra o app: o diálogo
/// ainda está animando a saída e o campo continua lendo o controller.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initialName});

  final String initialName;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seu nome'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nome'),
        onSubmitted: (_) => _save(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
