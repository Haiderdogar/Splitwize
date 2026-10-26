import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Offline-first local store (SQLite via sqflite).
///
/// Every signed-in user gets their own database file
/// (`splitwize_<uid>.db`), so signing out wipes personal data in one
/// move and nothing leaks between accounts on a shared device.
///
/// Documents are stored as JSON blobs (the exact Firestore-shaped map,
/// with dates as millisecond ints). A row is never a source of truth for
/// anyone else — it is a local mirror of what was synced, plus locally
/// created/edited rows marked `sync_state = 'pending'` until
/// [SyncService] pushes them.
///
/// Tables:
/// - `bills`, `groups` — mirror of the user's bills/groups
/// - `users` — cached profiles (me + friends + anyone in my bills/groups)
/// - `connections` — accepted friends (full user payloads)
/// - `requests` — pending incoming/outgoing connection requests
/// - `notifications` — my inbox (read flags may be pending a push)
/// - `outbox` — mutations waiting to be sent to Firestore, in order
/// - `meta` — last-pull cursors and other sync bookkeeping
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static LocalDatabase? _instance;
  static String? _openForUid;

  /// Opens (or reuses) the database for [uid].
  static Future<LocalDatabase> open(String uid) async {
    if (_instance != null && _openForUid == uid) return _instance!;
    await close();
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'splitwize_$uid.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createSchema,
    );
    _instance = LocalDatabase._(db);
    _openForUid = uid;
    return _instance!;
  }

  static Future<void> close() async {
    await _instance?._db.close();
    _instance = null;
    _openForUid = null;
  }

  /// Wipes the local database for [uid] (called on sign-out).
  static Future<void> deleteForUid(String uid) async {
    await close();
    final dir = await getDatabasesPath();
    await deleteDatabase(p.join(dir, 'splitwize_$uid.db'));
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bills(
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        sync_state TEXT NOT NULL DEFAULT 'synced'
      )''');
    await db.execute('''
      CREATE TABLE groups(
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        sync_state TEXT NOT NULL DEFAULT 'synced'
      )''');
    await db.execute('''
      CREATE TABLE users(
        uid TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE connections(
        uid TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE requests(
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        direction TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE notifications(
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        sync_state TEXT NOT NULL DEFAULT 'synced'
      )''');
    await db.execute('''
      CREATE TABLE outbox(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retries INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
  }

  // ---------------------------------------------------------- JSON helpers

  /// Converts a model map into a JSON-encodable map (dates -> ms ints).
  static Map<String, dynamic> jsonify(Map<String, dynamic> map) {
    final out = <String, dynamic>{};
    for (final e in map.entries) {
      final v = e.value;
      if (v is DateTime) {
        out[e.key] = v.millisecondsSinceEpoch;
      } else if (v is Timestamp) {
        out[e.key] = v.millisecondsSinceEpoch;
      } else if (v is Map) {
        out[e.key] = jsonify(Map<String, dynamic>.from(v));
      } else if (v is List) {
        out[e.key] = v
            .map((x) => x is Map
                ? jsonify(Map<String, dynamic>.from(x))
                : x is DateTime
                    ? x.millisecondsSinceEpoch
                    : x)
            .toList();
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }

  static String encode(Map<String, dynamic> map) => jsonEncode(jsonify(map));

  static Map<String, dynamic> decode(String payload) =>
      Map<String, dynamic>.from(jsonDecode(payload) as Map);

  static int ms(DateTime? dt) =>
      (dt ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch;

  // ------------------------------------------------------------------ bills

  Future<void> upsertBill(String id, Map<String, dynamic> map,
      {String syncState = 'synced'}) async {
    await _db.insert(
      'bills',
      {
        'id': id,
        'payload': encode(map),
        'updated_at': ms(_updatedAtOf(map)),
        'sync_state': syncState,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markBillSynced(String id) async {
    await _db.update('bills', {'sync_state': 'synced'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> billSyncState(String id) async {
    final rows = await _db.query('bills',
        columns: ['sync_state'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first['sync_state'] as String?;
  }

  Future<void> deleteBill(String id) async {
    await _db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> billRow(String id) async {
    final rows =
        await _db.query('bills', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : decode(rows.first['payload'] as String);
  }

  /// Bills involving [uid], newest first.
  Future<List<Map<String, dynamic>>> billsFor(String uid) async {
    final rows = await _db.query('bills', orderBy: 'updated_at DESC');
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final map = decode(r['payload'] as String);
      final ids = (map['participantIds'] as List?) ?? const [];
      if (ids.contains(uid)) out.add(map..['__id'] = r['id']);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> billsForGroup(String groupId) async {
    final rows = await _db.query('bills', orderBy: 'updated_at DESC');
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final map = decode(r['payload'] as String);
      if (map['groupId'] == groupId) out.add(map..['__id'] = r['id']);
    }
    return out;
  }

  /// Locally created bills that have not been pushed yet.
  Future<List<Map<String, dynamic>>> pendingBills() async {
    final rows = await _db
        .query('bills', where: 'sync_state = ?', whereArgs: ['pending']);
    return [
      for (final r in rows) decode(r['payload'] as String)..['__id'] = r['id']
    ];
  }

  // ----------------------------------------------------------------- groups

  Future<void> upsertGroup(String id, Map<String, dynamic> map,
      {String syncState = 'synced'}) async {
    await _db.insert(
      'groups',
      {
        'id': id,
        'payload': encode(map),
        'updated_at': ms(_updatedAtOf(map)),
        'sync_state': syncState,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markGroupSynced(String id) async {
    await _db.update('groups', {'sync_state': 'synced'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> groupSyncState(String id) async {
    final rows = await _db.query('groups',
        columns: ['sync_state'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first['sync_state'] as String?;
  }

  Future<void> deleteGroup(String id) async {
    await _db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> groupRow(String id) async {
    final rows =
        await _db.query('groups', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : decode(rows.first['payload'] as String);
  }

  Future<List<Map<String, dynamic>>> groupsFor(String uid) async {
    final rows = await _db.query('groups', orderBy: 'updated_at DESC');
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final map = decode(r['payload'] as String);
      final members = (map['members'] as List?) ?? const [];
      final invited = (map['invited'] as List?) ?? const [];
      if (members.contains(uid) || invited.contains(uid)) {
        out.add(map..['__id'] = r['id']);
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> pendingGroups() async {
    final rows = await _db
        .query('groups', where: 'sync_state = ?', whereArgs: ['pending']);
    return [
      for (final r in rows) decode(r['payload'] as String)..['__id'] = r['id']
    ];
  }

  // ------------------------------------------------------------------ users

  Future<void> upsertUser(String uid, Map<String, dynamic> map) async {
    await _db.insert(
      'users',
      {
        'uid': uid,
        'payload': encode(map),
        'updated_at': ms(_updatedAtOf(map)),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> userRow(String uid) async {
    final rows =
        await _db.query('users', where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : decode(rows.first['payload'] as String);
  }

  // ------------------------------------------------------------ connections

  Future<void> upsertConnection(String uid, Map<String, dynamic> map) async {
    await _db.insert(
      'connections',
      {
        'uid': uid,
        'payload': encode(map),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteConnection(String uid) async {
    await _db.delete('connections', where: 'uid = ?', whereArgs: [uid]);
  }

  Future<void> replaceConnections(List<Map<String, dynamic>> users) async {
    await _db.transaction((tx) async {
      await tx.delete('connections');
      for (final u in users) {
        final uid = (u['uid'] as String?) ?? '';
        if (uid.isEmpty) continue;
        await tx.insert('connections', {
          'uid': uid,
          'payload': encode(u),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> connectionRows() async {
    final rows = await _db.query('connections');
    return [
      for (final r in rows) decode(r['payload'] as String)..['uid'] ??= r['uid']
    ];
  }

  // --------------------------------------------------------------- requests

  Future<void> upsertRequest(
      String id, Map<String, dynamic> map, String direction) async {
    await _db.insert(
      'requests',
      {
        'id': id,
        'payload': encode(map),
        'direction': direction,
        'updated_at': ms(_updatedAtOf(map)),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRequest(String id) async {
    await _db.delete('requests', where: 'id = ?', whereArgs: [id]);
  }

  /// Re-keys a locally created request row to its remote id once the
  /// `conn.send` op has landed. Without this, delta pulls (which key
  /// rows by the remote id) would show the request twice and could
  /// never clear the local copy when its status changes remotely.
  /// No-op if the local row is already gone.
  Future<void> remapRequestId(String localId, String remoteId) async {
    if (localId == remoteId) return;
    final rows = await _db.query('requests',
        where: 'id = ?', whereArgs: [localId], limit: 1);
    if (rows.isEmpty) return;
    final row = rows.first;
    await _db.transaction((tx) async {
      await tx.delete('requests', where: 'id = ?', whereArgs: [localId]);
      await tx.insert(
        'requests',
        {
          'id': remoteId,
          'payload': row['payload'],
          'direction': row['direction'],
          'updated_at': row['updated_at'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<Map<String, dynamic>>> requestRows(String direction) async {
    final rows = await _db.query('requests',
        where: 'direction = ?',
        whereArgs: [direction],
        orderBy: 'updated_at DESC');
    return [
      for (final r in rows) decode(r['payload'] as String)..['__id'] = r['id']
    ];
  }

  // ---------------------------------------------------------- notifications

  Future<void> upsertNotification(String id, Map<String, dynamic> map,
      {String syncState = 'synced'}) async {
    await _db.insert(
      'notifications',
      {
        'id': id,
        'payload': encode(map),
        'updated_at': ms(_updatedAtOf(map)),
        'sync_state': syncState,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markNotificationReadLocal(String id) async {
    final rows = await _db.query('notifications',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final map = decode(rows.first['payload'] as String);
    map['read'] = true;
    await _db.update(
      'notifications',
      {'payload': encode(map), 'sync_state': 'pending_read'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> pendingReadNotificationIds() async {
    final rows = await _db.query('notifications',
        columns: ['id'], where: 'sync_state = ?', whereArgs: ['pending_read']);
    return [for (final r in rows) r['id'] as String];
  }

  Future<void> markNotificationSynced(String id) async {
    await _db.update('notifications', {'sync_state': 'synced'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllNotificationsReadLocal() async {
    final rows = await _db.query('notifications');
    await _db.transaction((tx) async {
      for (final r in rows) {
        final map = decode(r['payload'] as String);
        if ((map['read'] as bool?) == true) continue;
        map['read'] = true;
        await tx.update(
          'notifications',
          {'payload': encode(map), 'sync_state': 'pending_read'},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> notificationRows() async {
    final rows = await _db.query('notifications', orderBy: 'updated_at DESC');
    return [
      for (final r in rows) decode(r['payload'] as String)..['__id'] = r['id']
    ];
  }

  Future<int> unreadCount() async {
    final rows = await _db.query('notifications');
    var n = 0;
    for (final r in rows) {
      final map = decode(r['payload'] as String);
      if ((map['read'] as bool?) != true) n++;
    }
    return n;
  }

  // ----------------------------------------------------------------- outbox

  /// Enqueues a mutation to run against Firestore when online.
  /// [type] examples: bill.create, bill.setPaid, conn.send, conn.accept,
  /// conn.decline, conn.cancel, conn.remove, notify, notif.readAll,
  /// user.upsert.
  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    await _db.insert('outbox', {
      'type': type,
      'payload': jsonEncode(jsonify(Map<String, dynamic>.from(payload))),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    });
  }

  Future<List<Map<String, dynamic>>> peekOutbox() async {
    final rows = await _db.query('outbox', orderBy: 'id ASC', limit: 200);
    return [
      for (final r in rows)
        {
          'id': r['id'],
          'type': r['type'],
          'payload': Map<String, dynamic>.from(
              jsonDecode(r['payload'] as String) as Map),
          'retries': r['retries'],
        }
    ];
  }

  Future<void> removeOutbox(int id) async {
    await _db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> bumpOutboxRetries(int id) async {
    await _db.rawUpdate(
        'UPDATE outbox SET retries = retries + 1 WHERE id = ?', [id]);
  }

  Future<int> outboxCount() async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return (r.first['c'] as int?) ?? 0;
  }

  // ------------------------------------------------------------------- meta

  Future<String?> getMeta(String key) async {
    final rows =
        await _db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    await _db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  DateTime? _updatedAtOf(Map<String, dynamic> map) {
    final v = map['updatedAt'];
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
