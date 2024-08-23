import 'package:flutter/material.dart';
import 'package:matchmaster/db/database_helper.dart';
import 'package:matchmaster/home.dart';
import 'package:matchmaster/main.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  List<Map<String, dynamic>> _completedMatches = [];

  @override
  void initState() {
    super.initState();
    _fetchCompletedMatches();
  }

  Future<void> _fetchCompletedMatches() async {
    DatabaseHelper dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    List<Map<String, dynamic>> matches = await db.query('matches');
    setState(() {
      _completedMatches = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 17, 17, 17),
      appBar: AppBar(
        title: Text('Perfil do Usuário', style: TextStyle(color: Colors.yellow)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(),
            SizedBox(height: 60),
            _buildPerformanceSection(),
            SizedBox(height: 60),
            _buildMatchesSection(),
          ],
        ),
      ),
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
    );
  }

  Widget _buildProfileSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.yellow,
          child: Text(
            'M', 
            style: TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'André Rigo', 
          style: TextStyle(fontSize: 24, color: Colors.yellow),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gráfico de Pontos
        Container(
          width: 170,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('50 pontos', style: TextStyle(fontSize: 16, color: Colors.yellow)),
              SizedBox(height: 5),
              Text('50% WIN\n100 Partidas', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.yellow)),
            ],
          ),
        ),
        // Ranking
        Container(
          width: 170,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '#1',
              style: TextStyle(fontSize: 40, color: Colors.yellow),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesSection() {
    return Expanded(
      child: ListView.builder(
        itemCount: _completedMatches.length,
        itemBuilder: (context, index) {
          final match = _completedMatches[index];
          return Card(
            color: Colors.grey[900],
            child: ListTile(
              leading: Icon(Icons.sports_soccer, color: Colors.yellow),
              title: Text('Partida contra ${match['team2Name']}', style: TextStyle(color: Colors.yellow)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${match['nomePartida']}', style: TextStyle(color: Colors.white)),
                  Text('${match['team1Score']} vs ${match['team2Score']}', style: TextStyle(color: Colors.white)),
                ],
              ),
              trailing: Text('Vitória', style: TextStyle(color: Colors.green)),
            ),
          );
        },
      ),
    );
  }
}
