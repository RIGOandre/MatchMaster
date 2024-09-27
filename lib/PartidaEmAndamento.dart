import 'dart:async';
import 'package:flutter/material.dart';
import 'package:matchmaster/db/database_helper.dart';
import 'package:matchmaster/home.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/usuario.dart';

class PartidaEmAndamento extends StatefulWidget {
  final String team1Name;
  final String team2Name;
  final List<String> team1Players; 
  final List<String> team2Players; 

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
    _timer.cancel(); 
    String matchDuration = _formatTime(_seconds); 
    String team1Players = widget.team1Players.join(', ');
    String team2Players = widget.team2Players.join(', ');

    String winner;
    if (team1Score > team2Score) {
      winner = widget.team1Name;
    } else if (team2Score > team1Score) {
      winner = widget.team2Name;
    } else {
      winner = 'Empate';
    }

    await DatabaseHelper().insertMatch(
      widget.team1Name, widget.team2Name,
      team1Score, team2Score, matchDuration,
      team1Players, team2Players, winner,
      nomePartida: 'Nome da Partida',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partida salva com sucesso!')),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserScreen()),
    );
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
              },
              color: Colors.black,
            ),
            IconButton(
              icon: Icon(Icons.home),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
              },
              color: Colors.black,
            ),
            IconButton(
              icon: Icon(Icons.person),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => UserScreen()));
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
            style: TextStyle(color: Colors.white, fontSize: 28),
          ),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreColumn(widget.team1Name, team1Score, () => _incrementScore(1), () => _decrementScore(1)),
              Image.network(
                'https://media.giphy.com/media/3o7TKsQ9tGkBf81DW0/giphy.gif',
                height: 60,
              ),
              _buildScoreColumn(widget.team2Name, team2Score, () => _incrementScore(2), () => _decrementScore(2)),
            ],
          ),
          SizedBox(height: 30),
          Text(
            'Jogadores do ${widget.team1Name}: ${widget.team1Players.join(', ')}',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          Text(
            'Jogadores do ${widget.team2Name}: ${widget.team2Players.join(', ')}',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          SizedBox(height: 50),
          ElevatedButton(
            onPressed: _saveMatch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Text('Salvar', style: TextStyle(fontSize: 16)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
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
          style: TextStyle(color: Colors.white, fontSize: 60),
        ),
        Text(
          teamName,
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        Row(
          children: [
            IconButton(
              onPressed: increment,
              icon: Icon(Icons.add_circle, color: Colors.yellow, size: 48),
            ),
            IconButton(
              onPressed: decrement,
              icon: Icon(Icons.remove_circle, color: Colors.yellow, size: 48),
            ),
          ],
        ),
      ],
    );
  }
}