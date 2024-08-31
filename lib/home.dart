import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:matchmaster/PartidaEmAndamento.dart';
import 'package:matchmaster/db/database_helper.dart';
import 'package:matchmaster/main.dart';
import 'package:matchmaster/usuario.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _selectedPlayers = 2;
  final TextEditingController _team1Controller = TextEditingController();
  final TextEditingController _team2Controller = TextEditingController();
  final List<TextEditingController> _team1PlayersControllers = [];
  final List<TextEditingController> _team2PlayersControllers = [];

  void _updatePlayerOptions(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _selectPlayers(int players) {
    setState(() {
      _selectedPlayers = players;
      _team1PlayersControllers.clear();
      _team2PlayersControllers.clear();
      for (int i = 0; i < players; i++) {
        _team1PlayersControllers.add(TextEditingController());
        _team2PlayersControllers.add(TextEditingController());
      }
    });
  }

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    for (var controller in _team1PlayersControllers) {
      controller.dispose();
    }
    for (var controller in _team2PlayersControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 17, 17, 17),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      radius: 30.0,
                      backgroundColor: Color.fromARGB(255, 238, 255, 3),
                      child: Icon(Icons.person, color: Colors.black),
                    ),
                    SizedBox(width: 18.0),
                    Text(
                      'André Rigo',
                      style: TextStyle(color: Colors.yellow, fontSize: 16.0),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                const Center(
                  child: Text(
                    'Crie uma partida',
                    style: TextStyle(
                      color: Color(0xFFFFDE5B),
                      fontSize: 24.0,
                    ),
                  ),
                ),
                SizedBox(height: 60),
                Center(child: ImageSlider(onIconChange: _updatePlayerOptions)),
                SizedBox(height: 16.0),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Nome da partida',
                    hintStyle: TextStyle(color: Color.fromARGB(255, 229, 255, 0)),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color.fromARGB(255, 229, 255, 0)),
                    ),
                  ),
                                        style: TextStyle(color: Colors.white), 
                ),
                SizedBox(height: 20.0),
                const Text(
                  'Número de jogadores:',
                  style: TextStyle(color: Colors.yellow, fontSize: 16.0),
                ),
                SizedBox(height: 10.0),
                Center(
                  child: PlayerNumberSelection(
                    selectedIndex: _selectedIndex,
                    onPlayersSelected: _selectPlayers,
                  ),
                ),
                SizedBox(height: 20.0),
                const Text(
                  'Nome dos Times:',
                  style: TextStyle(color: Colors.yellow, fontSize: 16.0),
                ),
                SizedBox(height: 10.0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _team1Controller,
                        decoration: const InputDecoration(
                          hintText: 'Time 1',
                          hintStyle: TextStyle(color: Color.fromARGB(255, 229, 255, 0)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color.fromARGB(255, 229, 255, 0)),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {

                          });
                        },
                        style: TextStyle(color: Colors.white), 
                      ),
                      
                    ),
                    SizedBox(width: 20.0),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: Colors.white),
                        controller: _team2Controller,
                        decoration: const InputDecoration(
                          hintText: 'Time 2',
                          hintStyle: TextStyle(color: Color.fromARGB(255, 229, 255, 0)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color.fromARGB(255, 229, 255, 0)),
                          ),
                        ),
                        
                        onChanged: (value) {
                          setState(() {
                          });
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.0),
                
                SizedBox(height: 10.0),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4.0,
                    crossAxisSpacing: 20.0,
                    mainAxisSpacing: 20.0,
                  ),
                  itemCount: _selectedPlayers * 2,
                  itemBuilder: (context, index) {
                    int teamIndex = index % 2 == 0 ? 1 : 2;
                    int playerIndex = index ~/ 2;
                    return TextField(
                      controller: teamIndex == 1
                          ? _team1PlayersControllers[playerIndex]
                          : _team2PlayersControllers[playerIndex],
                      decoration: InputDecoration(
                        hintText: 'Jogador ${playerIndex + 1} - Time $teamIndex',
                        hintStyle: const TextStyle(color: Color.fromARGB(255, 229, 255, 0)),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color.fromARGB(255, 229, 255, 0)),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {

                        });
                      },
                    );
                  },
                ),
                SizedBox(height: 20.0),
                Center(
                  child:
ElevatedButton(
  onPressed: () async {
    try {
      final databaseHelper = DatabaseHelper();
      await databaseHelper.insertMatch(
        _team1Controller.text, 
        _team2Controller.text, 
        0, 
        0, 
        '00:00', 
        'Jogador1, Jogador2', 
        'Jogador3, Jogador4', 
        'Empate', 
        nomePartida: 'Partida 1', 
      );
      print('Deu Boa');
    } catch (e) {
      print('Deu bosta: $e');
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => PartidaEmAndamento(
          team1Name: _team1Controller.text,
          team2Name: _team2Controller.text,
          team1Players: _team1PlayersControllers.map((controller) => controller.text).toList(),
          team2Players: _team2PlayersControllers.map((controller) => controller.text).toList(),
        ),
      ),
      (Route<dynamic> route) => false,
    );
  },
  child: const Text(
    'Salvar',
    style: TextStyle(color: Colors.black),
  ),
)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ImageSlider extends StatelessWidget {
  final Function(int) onIconChange;

  ImageSlider({required this.onIconChange});

  final List<IconData> _icons = [
    Icons.sports_tennis_rounded,
    Icons.circle,
    Icons.sports_volleyball_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 120.0,
        enlargeCenterPage: true,
        onPageChanged: (index, reason) {
          if (index >= 0 && index < _icons.length) {
            onIconChange(index);
          }
        },
      ),
      items: _icons.map((iconData) {
        return Builder(
          builder: (BuildContext context) {
            return CircleAvatar(
              radius: 60,
              backgroundColor: Color.fromARGB(255, 251, 255, 0),
              child: Icon(iconData, size: 60, color: Colors.black),
            );
          },
        );
      }).toList(),
    );
  }
}

class PlayerNumberSelection extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onPlayersSelected;

  PlayerNumberSelection({required this.selectedIndex, required this.onPlayersSelected});

  @override
  Widget build(BuildContext context) {
    List<int> playerNumbers;
    if (selectedIndex == 2) {
      playerNumbers = [2, 6];
    } else {
      playerNumbers = [2, 4];
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: playerNumbers.map((number) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: ElevatedButton(
            onPressed: () {
              onPlayersSelected(number);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            ),
            child: Text(
              '$number',
              style: TextStyle(fontSize: 16.0, color: Colors.black),
            ),
          ),
        );
      }).toList(),
    );
  }
}

