import 'dart:async';
import 'package:flutter/material.dart';
import 'package:matchmaster/db/database_helper.dart';
import 'package:matchmaster/home.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/usuario.dart';

class PartidaEmAndamento extends StatefulWidget {
  final String team1Name;
  final String team2Name;
  final List<String> team1Players; // Lista de jogadores do time 1
  final List<String> team2Players; // Lista de jogadores do time 2

  PartidaEmAndamento({
    required this.team1Name,
    required this.team2Name,
    required this.team1Players,
    required this.team2Players,
  });

  @override
  _PartidaEmAndamentoState createState() => _PartidaEmAndamentoState();
}

class _PartidaEmAndamentoState extends State<PartidaEmAndamento> {
  int team1Score = 0;
  int team2Score = 0;
  late Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _incrementScore(int team) {
    setState(() {
      if (team == 1) {
        team1Score++;
      } else {
        team2Score++;
      }
    });
  }

  void _decrementScore(int team) {
    setState(() {
      if (team == 1 && team1Score > 0) {
        team1Score--;
      } else if (team == 2 && team2Score > 0) {
        team2Score--;
      }
    });
  }

  Future<void> _saveMatch() async {
    _timer.cancel(); // Para o timer
    String matchDuration = _formatTime(_seconds);
    String team2Players = widget.team2Players.join(', ');
    String team1Players = widget.team1Players.join(', ');



    // Determina o vencedor
    String winner;
    if (team1Score > team2Score) {
      winner = widget.team1Name;
    } else if (team2Score > team1Score) {
      winner = widget.team2Name;
    } else {
      winner = 'Empate';
    }

    // Insere os detalhes da partida no banco de dados
    await DatabaseHelper().insertMatch(
      widget.team1Name,
      widget.team2Name,
      team1Score,
      team2Score,
      matchDuration,
      team1Players,
      team2Players,
      winner,
      nomePartida: 'Nome da Partida',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partida salva com sucesso!')),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserScreen()),
    ).then((_) {
      // Atualiza a lista de partidas completas
      // _fetchCompletedMatches();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        color: Color(0xFFFFDE5B),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              color: Colors.black,
            ),
            IconButton(
              icon: Icon(Icons.home),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              },
              color: Colors.black,
            ),
            IconButton(
              icon: Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserScreen()),
                );
              },
              color: Colors.black,
            ),
          ],
        ),
      ),

      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Partida em andamento'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Tempo: ${_formatTime(_seconds)}',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreColumn(widget.team1Name, team1Score, () => _incrementScore(1), () => _decrementScore(1)),
              Text(
                'GIF', // Adicionar GIF
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              _buildScoreColumn(widget.team2Name, team2Score, () => _incrementScore(2), () => _decrementScore(2)),
            ],
          ),
          SizedBox(height: 20),
          Text('Jogadores do ${widget.team1Name}: ${widget.team1Players.join(', ')}',
              style: TextStyle(color: Colors.white)),
          Text('Jogadores do ${widget.team2Name}: ${widget.team2Players.join(', ')}',
              style: TextStyle(color: Colors.white)),
          SizedBox(height: 50),
          ElevatedButton(
            onPressed: _saveMatch,
            child: Text('Salvar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
    
  }

  Widget _buildScoreColumn(String teamName, int score, VoidCallback increment, VoidCallback decrement) {
    return Column(
      children: [
        Text(
          score.toString(),
          style: TextStyle(color: Colors.white, fontSize: 48),
        ),
        Text(
          teamName,
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        Row(
          children: [
            IconButton(
              onPressed: increment,
              icon: Icon(Icons.add, color: Colors.yellow),
            ),
            IconButton(
              onPressed: decrement,
              icon: Icon(Icons.remove, color: Colors.yellow),
            ),
          ],
        ),
      ],
    );
  }
}
