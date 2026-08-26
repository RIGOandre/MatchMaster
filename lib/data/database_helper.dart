import 'package:flutter/foundation.dart';
import 'package:matchmaster/core/utils/formatters.dart';
import 'package:matchmaster/models/match_record.dart';
import 'package:matchmaster/models/sport.dart';
import 'package:matchmaster/scoring/scoring_engine.dart';
import 'package:path/path.dart';
// `sqflite_common_ffi` reexporta a API do sqflite; no Android/iOS o plugin
// registra a fábrica nativa sozinho (dartPluginClass), então basta este import.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abre e migra o banco local de partidas.
class DatabaseHelper {
  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static final DatabaseHelper _instance = DatabaseHelper._internal();

  static const String matchesTable = 'matches';
  static const String _fileName = 'matchmaster.db';
  static const int _schemaVersion = 3;

  /// Nome do arquivo usado até a versão 2 do app.
  static const String _legacyFileName = 'matchmasterrr.db';

  Database? _database;

  /// Abertura em andamento.
  ///
  /// As abas do app pedem dados ao mesmo tempo assim que a casca é montada; sem
  /// guardar o future, cada chamada concorrente abriria o banco por conta
  /// própria e as conexões travavam umas às outras durante a migração.
  Future<Database>? _opening;

  /// Fábrica alternativa, usada pelos testes para rodar em memória.
  @visibleForTesting
  static DatabaseFactory? overrideFactory;

  /// Caminho alternativo, usado pelos testes.
  @visibleForTesting
  static String? overridePath;

  Future<Database> get database {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) {
      return Future<Database>.value(existing);
    }
    return _opening ??= _open().then(
      (Database db) {
        _database = db;
        _opening = null;
        return db;
      },
      onError: (Object error, StackTrace stackTrace) {
        _opening = null;
        throw Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<Database> _open() async {
    final DatabaseFactory factory = overrideFactory ?? await _resolveFactory();
    final String path = overridePath ?? await _resolvePath(factory);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: (Database db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  }

  Future<DatabaseFactory> _resolveFactory() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'O MatchMaster precisa de armazenamento local; a versão web do sqflite '
        'não é suportada.',
      );
    }
    const Set<TargetPlatform> desktop = <TargetPlatform>{
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    };
    if (desktop.contains(defaultTargetPlatform)) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<String> _resolvePath(DatabaseFactory factory) async {
    final String directory = await factory.getDatabasesPath();
    return join(directory, _fileName);
  }

  /// Caminho do banco usado pelas versões 1 e 2 do app.
  Future<String> legacyDatabasePath() async {
    final DatabaseFactory factory = overrideFactory ?? await _resolveFactory();
    return join(await factory.getDatabasesPath(), _legacyFileName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createMatchesTable(db);
  }

  Future<void> _createMatchesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $matchesTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sport TEXT NOT NULL,
        scoringMode TEXT NOT NULL,
        team1Name TEXT NOT NULL,
        team2Name TEXT NOT NULL,
        team1Players TEXT NOT NULL,
        team2Players TEXT NOT NULL,
        team1Score INTEGER NOT NULL,
        team2Score INTEGER NOT NULL,
        sets TEXT NOT NULL,
        durationSeconds INTEGER NOT NULL,
        winner TEXT NOT NULL,
        playedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_matches_sport ON $matchesTable(sport)');
    await db.execute(
      'CREATE INDEX idx_matches_played_at ON $matchesTable(playedAt DESC)',
    );
  }

  /// Migra o schema antigo preservando o histórico já gravado.
  ///
  /// A tabela da versão 2 tinha `nomePartida TEXT UNIQUE` e era gravada sempre
  /// com o mesmo texto fixo, usando `ConflictAlgorithm.replace` — na prática só
  /// uma partida sobrevivia no banco. A tabela nova não tem essa restrição.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= newVersion) return;

    final List<Map<String, dynamic>> legacyRows = await _readLegacyRows(db);

    await db.execute('DROP TABLE IF EXISTS $matchesTable');
    // `teams` e `players` nunca chegaram a ser usadas pelo app.
    await db.execute('DROP TABLE IF EXISTS players');
    await db.execute('DROP TABLE IF EXISTS teams');
    await _createMatchesTable(db);

    if (legacyRows.isEmpty) return;
    final Batch batch = db.batch();
    for (final Map<String, dynamic> row in legacyRows) {
      batch.insert(matchesTable, migrateLegacyRow(row).toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> _readLegacyRows(Database db) async {
    final List<Map<String, Object?>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      <Object?>[matchesTable],
    );
    if (tables.isEmpty) return const <Map<String, dynamic>>[];
    try {
      return await db.query(matchesTable);
    } on DatabaseException {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Converte uma linha do schema antigo no registro atual.
  ///
  /// Exposto para que a migração possa ser testada sem abrir um banco real.
  @visibleForTesting
  static MatchRecord migrateLegacyRow(Map<String, dynamic> row) {
    final String team1Name =
        (row['team1Name'] as String?)?.trim().isNotEmpty == true
            ? (row['team1Name'] as String).trim()
            : 'Time 1';
    final String team2Name =
        (row['team2Name'] as String?)?.trim().isNotEmpty == true
            ? (row['team2Name'] as String).trim()
            : 'Time 2';

    final int team1Score = (row['team1Score'] as num?)?.toInt() ?? 0;
    final int team2Score = (row['team2Score'] as num?)?.toInt() ?? 0;

    final String legacyWinner = (row['winner'] as String?)?.trim() ?? '';
    final MatchOutcome outcome;
    if (legacyWinner.isNotEmpty && legacyWinner == team1Name) {
      outcome = MatchOutcome.team1;
    } else if (legacyWinner.isNotEmpty && legacyWinner == team2Name) {
      outcome = MatchOutcome.team2;
    } else if (team1Score > team2Score) {
      outcome = MatchOutcome.team1;
    } else if (team2Score > team1Score) {
      outcome = MatchOutcome.team2;
    } else {
      outcome = MatchOutcome.draw;
    }

    // "Nome da Partida" era o texto fixo gravado por todas as partidas antigas.
    final String legacyName = (row['nomePartida'] as String?)?.trim() ?? '';
    final String name = (legacyName.isEmpty || legacyName == 'Nome da Partida')
        ? ''
        : legacyName;

    return MatchRecord(
      name: name,
      sport: Sport.fromId(row['sport'] as String?),
      // O app antigo só sabia contar pontos corridos.
      scoringMode: ScoringMode.free,
      team1Name: team1Name,
      team2Name: team2Name,
      team1Players: _splitLegacyPlayers(row['team1Players']),
      team2Players: _splitLegacyPlayers(row['team2Players']),
      team1Score: team1Score,
      team2Score: team2Score,
      sets: const [],
      durationSeconds: parseDurationToSeconds(row['matchDuration'] as String?),
      outcome: outcome,
      playedAt: _parseLegacyTimestamp(row['created_at']),
    );
  }

  static List<String> _splitLegacyPlayers(Object? raw) {
    if (raw == null) return const <String>[];
    return raw
        .toString()
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  static DateTime _parseLegacyTimestamp(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    final String? text = raw?.toString();
    if (text == null || text.isEmpty) return DateTime.now();
    // SQLite grava CURRENT_TIMESTAMP em UTC, no formato "yyyy-MM-dd HH:mm:ss".
    return DateTime.tryParse(text.replaceFirst(' ', 'T'))?.toLocal() ??
        DateTime.now();
  }

  Future<void> close() async {
    final Future<Database>? opening = _opening;
    if (opening != null) {
      // Não deixa uma abertura em andamento reviver a conexão após o close.
      await opening.then<void>((_) {}, onError: (Object _) {});
    }
    final Database? db = _database;
    _database = null;
    _opening = null;
    if (db != null && db.isOpen) await db.close();
  }

  /// Apaga o banco inteiro. Usado pela opção "limpar histórico" do perfil.
  Future<void> wipe() async {
    final Database db = await database;
    await db.delete(matchesTable);
  }
}
