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
    await db.execute(
      'CREATE TABLE teams(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
    );
    await db.execute(
      'CREATE TABLE players(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, teamId INTEGER, FOREIGN KEY(teamId) REFERENCES teams(id))',
    );
  }

  Future<int> insertTeam(String name) async {
    Database db = await database;
    return await db.insert('teams', {'name': name});
  }

  Future<int> insertPlayer(String name, int teamId) async {
    Database db = await database;
    return await db.insert('players', {'name': name, 'teamId': teamId});
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
