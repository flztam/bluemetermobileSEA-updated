import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fixnum/fixnum.dart';
import '../models/player_info.dart';

class SavedEncounter {
  final int id;
  final int startTime;
  final int endTime;
  final int durationSeconds;
  final String totalDamage;
  final String totalHeal;
  final String bossName;

  SavedEncounter({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalDamage,
    required this.totalHeal,
    required this.bossName,
  });
}

class SavedEncounterPlayer {
  final int encounterId;
  final String playerUid;
  final String playerName;
  final int professionId;
  final String totalDamage;
  final double dps;
  final String totalHeal;
  final double hps;
  final String totalTaken;
  final int hitCount;
  final int critHits;
  final int luckyHits;

  SavedEncounterPlayer({
    required this.encounterId,
    required this.playerUid,
    required this.playerName,
    required this.professionId,
    required this.totalDamage,
    required this.dps,
    required this.totalHeal,
    required this.hps,
    required this.totalTaken,
    required this.hitCount,
    required this.critHits,
    required this.luckyHits,
  });
}

class SavedEncounterSkill {
  final int encounterId;
  final String playerUid;
  final String skillId;
  final String skillName;
  final String totalDamage;
  final int hitCount;
  final int critHits;
  final int luckyHits;

  SavedEncounterSkill({
    required this.encounterId,
    required this.playerUid,
    required this.skillId,
    required this.skillName,
    required this.totalDamage,
    required this.hitCount,
    required this.critHits,
    required this.luckyHits,
  });
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'bluemetersea.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players(
        uid TEXT PRIMARY KEY,
        name TEXT,
        professionId INTEGER,
        combatPower INTEGER,
        level INTEGER,
        rankLevel INTEGER,
        critical INTEGER,
        lucky INTEGER,
        maxHp TEXT,
        hp TEXT,
        last_seen INTEGER
      )
    ''');
    await _createEncounterTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createEncounterTables(db);
    }
  }

  Future<void> _createEncounterTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS encounters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time INTEGER,
        end_time INTEGER,
        duration_seconds INTEGER,
        total_damage TEXT,
        total_heal TEXT,
        boss_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS encounter_players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encounter_id INTEGER,
        player_uid TEXT,
        player_name TEXT,
        profession_id INTEGER,
        total_damage TEXT,
        dps REAL,
        total_heal TEXT,
        hps REAL,
        total_taken TEXT,
        hit_count INTEGER,
        crit_hits INTEGER,
        lucky_hits INTEGER,
        FOREIGN KEY(encounter_id) REFERENCES encounters(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS encounter_skills(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encounter_id INTEGER,
        player_uid TEXT,
        skill_id TEXT,
        skill_name TEXT,
        total_damage TEXT,
        hit_count INTEGER,
        crit_hits INTEGER,
        lucky_hits INTEGER,
        FOREIGN KEY(encounter_id) REFERENCES encounters(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> saveEncounter({
    required int startTime,
    required int endTime,
    required int durationSeconds,
    required String totalDamage,
    required String totalHeal,
    required String bossName,
    required List<SavedEncounterPlayer> players,
    required List<SavedEncounterSkill> skills,
  }) async {
    final db = await database;
    int encounterId = 0;

    await db.transaction((txn) async {
      encounterId = await txn.insert('encounters', {
        'start_time': startTime,
        'end_time': endTime,
        'duration_seconds': durationSeconds,
        'total_damage': totalDamage,
        'total_heal': totalHeal,
        'boss_name': bossName,
      });

      for (final p in players) {
        await txn.insert('encounter_players', {
          'encounter_id': encounterId,
          'player_uid': p.playerUid,
          'player_name': p.playerName,
          'profession_id': p.professionId,
          'total_damage': p.totalDamage,
          'dps': p.dps,
          'total_heal': p.totalHeal,
          'hps': p.hps,
          'total_taken': p.totalTaken,
          'hit_count': p.hitCount,
          'crit_hits': p.critHits,
          'lucky_hits': p.luckyHits,
        });
      }

      for (final s in skills) {
        await txn.insert('encounter_skills', {
          'encounter_id': encounterId,
          'player_uid': s.playerUid,
          'skill_id': s.skillId,
          'skill_name': s.skillName,
          'total_damage': s.totalDamage,
          'hit_count': s.hitCount,
          'crit_hits': s.critHits,
          'lucky_hits': s.luckyHits,
        });
      }
    });

    return encounterId;
  }

  Future<List<SavedEncounter>> getEncounters() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'encounters',
      orderBy: 'start_time DESC',
      limit: 50,
    );

    return maps.map((map) {
      return SavedEncounter(
        id: map['id'] as int,
        startTime: map['start_time'] as int,
        endTime: map['end_time'] as int,
        durationSeconds: map['duration_seconds'] as int,
        totalDamage: map['total_damage'] as String? ?? '0',
        totalHeal: map['total_heal'] as String? ?? '0',
        bossName: map['boss_name'] as String? ?? 'Field Boss',
      );
    }).toList();
  }

  Future<List<SavedEncounterPlayer>> getEncounterPlayers(int encounterId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'encounter_players',
      where: 'encounter_id = ?',
      whereArgs: [encounterId],
      orderBy: 'dps DESC',
    );

    return maps.map((map) {
      return SavedEncounterPlayer(
        encounterId: map['encounter_id'] as int,
        playerUid: map['player_uid'] as String,
        playerName: map['player_name'] as String? ?? 'Unknown',
        professionId: map['profession_id'] as int? ?? 0,
        totalDamage: map['total_damage'] as String? ?? '0',
        dps: (map['dps'] as num?)?.toDouble() ?? 0.0,
        totalHeal: map['total_heal'] as String? ?? '0',
        hps: (map['hps'] as num?)?.toDouble() ?? 0.0,
        totalTaken: map['total_taken'] as String? ?? '0',
        hitCount: map['hit_count'] as int? ?? 0,
        critHits: map['crit_hits'] as int? ?? 0,
        luckyHits: map['lucky_hits'] as int? ?? 0,
      );
    }).toList();
  }

  Future<List<SavedEncounterSkill>> getEncounterSkills(int encounterId, String playerUid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'encounter_skills',
      where: 'encounter_id = ? AND player_uid = ?',
      whereArgs: [encounterId, playerUid],
    );

    return maps.map((map) {
      return SavedEncounterSkill(
        encounterId: map['encounter_id'] as int,
        playerUid: map['player_uid'] as String,
        skillId: map['skill_id'] as String,
        skillName: map['skill_name'] as String? ?? 'Skill',
        totalDamage: map['total_damage'] as String? ?? '0',
        hitCount: map['hit_count'] as int? ?? 0,
        critHits: map['crit_hits'] as int? ?? 0,
        luckyHits: map['lucky_hits'] as int? ?? 0,
      );
    }).toList();
  }

  Future<void> deleteEncounter(int encounterId) async {
    final db = await database;
    await db.delete('encounters', where: 'id = ?', whereArgs: [encounterId]);
    await db.delete('encounter_players', where: 'encounter_id = ?', whereArgs: [encounterId]);
    await db.delete('encounter_skills', where: 'encounter_id = ?', whereArgs: [encounterId]);
  }

  Future<void> clearAllEncounters() async {
    final db = await database;
    await db.delete('encounters');
    await db.delete('encounter_players');
    await db.delete('encounter_skills');
  }

  Future<void> savePlayer(PlayerInfo player) async {
    final db = await database;

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> maps = await txn.query(
        'players',
        where: 'uid = ?',
        whereArgs: [player.uid.toString()],
      );

      if (maps.isEmpty) {
        await txn.insert('players', {
          'uid': player.uid.toString(),
          'name': player.name,
          'professionId': player.professionId,
          'combatPower': player.combatPower,
          'level': player.level,
          'rankLevel': player.rankLevel,
          'critical': player.critical,
          'lucky': player.lucky,
          'maxHp': player.maxHp?.toString(),
          'hp': player.hp?.toString(),
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        final updateValues = <String, dynamic>{
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        };

        if (player.name != null) updateValues['name'] = player.name;
        if (player.professionId != null && player.professionId != 0)
          updateValues['professionId'] = player.professionId;
        if (player.combatPower != null && player.combatPower != 0)
          updateValues['combatPower'] = player.combatPower;
        if (player.seasonStrength != null && player.seasonStrength != 0)
          updateValues['seasonStrength'] = player.seasonStrength;
        if (player.level != null && player.level != 0)
          updateValues['level'] = player.level;
        if (player.rankLevel != null && player.rankLevel != 0)
          updateValues['rankLevel'] = player.rankLevel;
        if (player.critical != null && player.critical != 0)
          updateValues['critical'] = player.critical;
        if (player.lucky != null && player.lucky != 0)
          updateValues['lucky'] = player.lucky;
        if (player.maxHp != null && player.maxHp != Int64.ZERO)
          updateValues['maxHp'] = player.maxHp.toString();

        await txn.update(
          'players',
          updateValues,
          where: 'uid = ?',
          whereArgs: [player.uid.toString()],
        );
      }

      await txn.rawDelete(
        'DELETE FROM players WHERE uid NOT IN (SELECT uid FROM players ORDER BY last_seen DESC LIMIT 100)',
      );
    });
  }

  Future<PlayerInfo?> getPlayer(Int64 uid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'uid = ?',
      whereArgs: [uid.toString()],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return PlayerInfo(
      uid: Int64.parseInt(map['uid'] as String),
      name: map['name'] as String?,
      professionId: map['professionId'] as int?,
      combatPower: map['combatPower'] as int?,
      seasonStrength: map['seasonStrength'] as int?,
      level: map['level'] as int?,
      rankLevel: map['rankLevel'] as int?,
      critical: map['critical'] as int?,
      lucky: map['lucky'] as int?,
      maxHp: map['maxHp'] != null
          ? Int64.parseInt(map['maxHp'] as String)
          : null,
      hp: map['hp'] != null ? Int64.parseInt(map['hp'] as String) : null,
    );
  }
}
