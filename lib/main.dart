import 'package:flutter/material.dart';
import 'package:matchmaster/core/theme/app_theme.dart';
import 'package:matchmaster/data/match_repository.dart';
import 'package:matchmaster/data/settings_store.dart';
import 'package:matchmaster/screens/home_shell.dart';
import 'package:matchmaster/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SettingsStore settings = await SettingsStore.load();
  runApp(MatchMasterApp(settings: settings));
}

class MatchMasterApp extends StatelessWidget {
  MatchMasterApp({
    super.key,
    required this.settings,
    MatchRepository? repository,
  }) : repository = repository ?? MatchRepository();

  final SettingsStore settings;
  final MatchRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      repository: repository,
      child: AnimatedBuilder(
        animation: settings,
        builder: (BuildContext context, _) {
          return MaterialApp(
            title: 'MatchMaster',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            // "Lembrar de mim" agora tem efeito: com a opção marcada o app abre
            // direto na home em vez de pedir login de novo.
            home: settings.rememberMe ? const HomeShell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}

/// Injeta as dependências compartilhadas na árvore de widgets.
///
/// Mantém as telas testáveis: um teste monta a árvore com um repositório
/// apontando para um banco em memória.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.repository,
    required super.child,
  });

  final SettingsStore settings;
  final MatchRepository repository;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado acima deste widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings || repository != oldWidget.repository;
}
