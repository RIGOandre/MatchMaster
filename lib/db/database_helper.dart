import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'matchmaster.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Criação da tabela teams
    await db.execute(
      'CREATE TABLE teams(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
    );

    // Criação da tabela players
    await db.execute(
      'CREATE TABLE players(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, teamId INTEGER, FOREIGN KEY(teamId) REFERENCES teams(id))',
    );

    // Criação da tabela matches
Future<void> _onCreate(Database db, int version) async {
  // ...
  await db.execute(
    '''CREATE TABLE matches(
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      team1Name TEXT, 
      team2Name TEXT, 
      team1Score INTEGER, 
      team2Score INTEGER, 
      matchDuration TEXT,
      nomePartida TEXT
    )''',
  );
}

  Future<int> insertMatch(String team1Name, String team2Name, int team1Score, int team2Score, String matchDuration, String nomePartida) async {
    final db = await database;
    return await db.insert(
      'matches',
      {
        'team1Name': team1Name,
        'team2Name': team2Name,
        'team1Score': team1Score,
        'team2Score': team2Score,
        'matchDuration': matchDuration,
        'nomePartida': nomePartida,
      },
    );
  }
}

  Future<int> insertTeam(String name) async {
    Database db = await database;
    return await db.insert('teams', {'name': name});
  }

  Future<int> insertPlayer(String name, int teamId) async {
    Database db = await database;
    return await db.insert('players', {'name': name, 'teamId': teamId});
  }

  Future<int> insertMatch(String team1Name, String team2Name, int team1Score, int team2Score, String matchDuration, {required String nomePartida}) async {
    Database db = await database;
      Map<String, dynamic> matchData = {
        'team1Name': team1Name,
        'team2Name': team2Name,
        'team1Score': team1Score,
        'team2Score': team2Score,
        'matchDuration': matchDuration,
        'nomePartida': nomePartida,
      };
    return await db.insert('matches', matchData);
  }

  Future<List<Map<String, dynamic>>> getTeams() async {
    Database db = await database;
    return await db.query('teams');
  }

  Future<List<Map<String, dynamic>>> getPlayers(int teamId) async {
    Database db = await database;
    return await db.query('players', where: 'teamId = ?', whereArgs: [teamId]);
  }

  Future<void> close() async {
    Database db = await database;
    await db.close();
  }
}
