import 'package:flutter/material.dart';
import 'package:matchmaster/screens/history_screen.dart';
import 'package:matchmaster/screens/new_match_screen.dart';
import 'package:matchmaster/screens/profile_screen.dart';
import 'package:matchmaster/screens/stats_screen.dart';

/// Casca do app com a barra de navegação inferior.
///
/// A versão anterior usava `Navigator.push` em cada botão da barra — inclusive
/// para ir da Home para a Home. Cada toque empilhava uma tela nova, a pilha
/// crescia sem limite e o botão "voltar" percorria o histórico de navegação de
/// trás para frente. Aqui as abas são um [IndexedStack]: trocar de aba não
/// empilha nada e cada aba preserva seu estado.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  /// Chaves para pedir que uma aba recarregue quando os dados mudarem.
  final GlobalKey<HistoryScreenState> _historyKey =
      GlobalKey<HistoryScreenState>();
  final GlobalKey<StatsScreenState> _statsKey = GlobalKey<StatsScreenState>();

  /// Vai para a aba [index] e atualiza os dados dela.
  void goTo(int index) {
    setState(() => _index = index);
    refreshData();
  }

  /// Recarrega histórico e estatísticas — chamado após salvar ou excluir.
  void refreshData() {
    _historyKey.currentState?.reload();
    _statsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          const NewMatchScreen(),
          HistoryScreen(key: _historyKey),
          StatsScreen(key: _statsKey),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Nova',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Estatísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
