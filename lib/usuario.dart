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
  List<Map<String, dynamic>> _filteredMatches = []; 
  String? _selectedSport = 'Todos'; 
  bool _isLoading = false;

  final List<String> _sports = ['Todos', 'Tênis', 'Tênis de Mesa', 'Vôlei']; 

  @override
  void initState() {
    super.initState();
    _fetchCompletedMatches();
  }

  Future<void> _fetchCompletedMatches() async {
    setState(() {
      _isLoading = true;
    });
    DatabaseHelper dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    List<Map<String, dynamic>> matches = await db.query('matches');
    setState(() {
      _completedMatches = matches;
      _filteredMatches = matches;
      _isLoading = false;
    });
  }

  Future<void> _deleteMatch(int id) async {
    DatabaseHelper dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    await db.delete('matches', where: 'id = ?', whereArgs: [id]);
    _fetchCompletedMatches();
  }

  void _filterMatches(String? sport) {
    setState(() {
      _selectedSport = sport;
      if (sport == null || sport == 'Todos') {
        _filteredMatches = _completedMatches; 
      } else {
        _filteredMatches = _completedMatches
            .where((match) => match['sport'] == sport)
            .toList();
      }
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
            // SizedBox(height: 20),
            // _buildPerformanceSection(),
            SizedBox(height: 20),
            _buildSportFilter(), 
            SizedBox(height: 20),
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
    return const Row(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.yellow,
        ),
        SizedBox(width: 10),
        Text(
          'André Rigo', 
          style: TextStyle(fontSize: 24, color: Colors.yellow),
        ),
      ],
    );
  }

  // Widget _buildPerformanceSection() {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //     children: [
  //       Container(
  //         width: 170,
  //         height: 200,
  //         decoration: BoxDecoration(
  //           color: Colors.grey[850],
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         child: const Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             Text('1 ponto', style: TextStyle(fontSize: 16, color: Colors.yellow)),
  //             SizedBox(height: 5),
  //             Text('100% WIN\n1 Partida', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.yellow)),
  //           ],
  //         ),
  //       ),
  //       Container(
  //         width: 170,
  //         height: 200,
  //         decoration: BoxDecoration(
  //           color: Colors.grey[850],
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         child: const Center(
  //           child: Text(
  //             '#1',
  //             style: TextStyle(fontSize: 40, color: Colors.yellow),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildSportFilter() {
    return DropdownButton<String>(
      value: _selectedSport ?? 'Todos', 
      dropdownColor: Colors.black,
      style: const TextStyle(color: Colors.yellow),
      iconEnabledColor: Colors.yellow,
      items: _sports.map((String sport) {
        return DropdownMenuItem<String>(
          value: sport,
          child: Text(sport),
        );
      }).toList(),
      onChanged: (String? newValue) {
        _filterMatches(newValue); 
      },
    );
  }

  Widget _buildMatchesSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_filteredMatches.isEmpty) {
      return const Text('Nenhuma partida encontrada', style: TextStyle(color: Colors.white));
    } else {
      return Expanded(
        child: ListView.builder(
          itemCount: _filteredMatches.length,
          itemBuilder: (context, index) {
            final match = _filteredMatches[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding:const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellow),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Partida: ${match['team1Name']} vs ${match['team2Name']}',
                        style: const TextStyle(
                          color: Colors.yellow, 
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon:const Icon(Icons.delete, color: Colors.red), 
                        onPressed: () {
                          _deleteMatch(match['id']); 
                        },
                      ),
                    ],
                  ),
                  const SizedBox (height: 8),
                  Text(
                    'Esporte: ${match['sport'] ?? 'Não especificado'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Duração: ${match['matchDuration']}',
                    style:const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Vencedor: ${match['winner']}',
                    style:const TextStyle(
                      color: Colors.yellow, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Jogadores do ${match['team1Name']}: ${match['team1Players']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Jogadores do ${match['team2Name']}: ${match['team2Players']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }
}
