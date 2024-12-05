import 'package:flutter/foundation.dart'; 
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; 

class DatabaseException implements Exception {
  final String message;
  final String? code;
  
  DatabaseException(this.message, {this.code});
  
  @override
  String toString() => 'DatabaseException: $message ${code != null ? '(Code: $code)' : ''}';
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (kIsWeb) {
      throw UnsupportedError("A web não é suportada pelo sqflite");
    } else if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<bool> partidaExiste(String nomePartida) async {
    final db = await database;
    var res = await db.query('matches', where: 'nomePartida = ?', whereArgs: [nomePartida]);
    return res.isNotEmpty;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'matchmasterrr.db');
      return await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('Error initializing database: $e');
      throw Exception('Could not initialize database');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE teams(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
    );

    await db.execute(
      'CREATE TABLE players(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, teamId INTEGER, FOREIGN KEY(teamId) REFERENCES teams(id))',
    );


    await db.execute('''
      CREATE TABLE matches(
          id INTEGER PRIMARY KEY AUTOINCREMENT, 
          team1Name TEXT NOT NULL,
          team2Name TEXT NOT NULL,
          team1Score INTEGER NOT NULL,
          team2Score INTEGER NOT NULL,
          matchDuration TEXT NOT NULL,
          nomePartida TEXT UNIQUE NOT NULL,
          team1Players TEXT NOT NULL,
          team2Players TEXT NOT NULL,
          winner TEXT NOT NULL,
          sport TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Add indexes
    await db.execute('CREATE INDEX idx_sport ON matches(sport)');
    await db.execute('CREATE INDEX idx_winner ON matches(winner)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Xử lý upgrade database version
  }

  Future<void> deleteDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'matchmasterrr.db');
      await databaseFactory.deleteDatabase(path);
      _database = null;
    } catch (e) {
      print('Error deleting database: $e');
      throw Exception('Could not delete database');
    }
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
    String sport,
    {required String nomePartida,}
  ) async {
    // Validate data
    if (team1Name.isEmpty || team2Name.isEmpty) {
      throw Exception('Team names cannot be empty');
    }
    
    if (team1Score < 0 || team2Score < 0) {
      throw Exception('Scores cannot be negative');
    }

    try {
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
          'sport': sport,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting match: $e');
      throw Exception('Could not save match');
    }
  }

  Future<List<Map<String, dynamic>>> getMatches() async {
    final db = await database;
    return await db.query('matches');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Get matches by sport
  Future<List<Map<String, dynamic>>> getMatchesBySport(String sport) async {
    final db = await database;
    return await db.query(
      'matches',
      where: 'sport = ?',
      whereArgs: [sport],
      orderBy: 'created_at DESC',
    );
  }

  // Update match
  Future<int> updateMatch(int id, Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.update(
        'matches',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error updating match: $e');
      throw Exception('Could not update match');
    }
  }

  // Execute in transaction
  Future<void> executeInTransaction(Future<void> Function(Transaction txn) action) async {
    final db = await database;
    await db.transaction((txn) async {
      await action(txn);
    });
  }
}