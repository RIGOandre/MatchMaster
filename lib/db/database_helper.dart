import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    databaseFactory = databaseFactoryFfi; // <--- Add this line

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
    await db.execute(
      'CREATE TABLE teams(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
    );

    await db.execute(
      'CREATE TABLE players(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, teamId INTEGER, FOREIGN KEY(teamId) REFERENCES teams(id))',
    );

    await db.execute(
      '''CREATE TABLE matches(
          id INTEGER PRIMARY KEY AUTOINCREMENT, 
          team1Name TEXT, 
          team2Name TEXT, 
          team1Score INTEGER, 
          team2Score INTEGER, 
          matchDuration TEXT,
          nomePartida TEXT,
          team1Players TEXT,
          team2Players TEXT,
          winner TEXT
      )''',
    );
  }

  Future<int> insertMatch(
    String team1Name,
    String team2Name,
    int team1Score,
    int team2Score,
    String duration,
    String team1Players,
    String team2Players,
    String winner,
    {required String nomePartida}
  ) async {
    final db = await database;
    return await db.insert(
      'matches',
      {
        'team1Name': team1Name,
        'team2Name': team2Name,
        'team1Score': team1Score,
        'team2Score': team2Score,
        'matchDuration': duration,
        'nomePartida': nomePartida,
        'team1Players': team1Players,
        'team2Players': team2Players,
        'winner': winner,
      },
    );
  }

  // Adicione outras funções do DatabaseHelper, se necessário

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
