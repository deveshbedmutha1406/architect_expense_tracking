import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/client.dart';
import '../models/agency.dart';
import '../models/payment.dart';
import '../models/client_contribution.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expense_tracker.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        project_name TEXT NOT NULL,
        site_address TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE client_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE agencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        client_id INTEGER NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agency_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_given_by TEXT NOT NULL,
        FOREIGN KEY (agency_id) REFERENCES agencies (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS clients');
      await db.execute('DROP TABLE IF EXISTS client_contributions');
      await db.execute('DROP TABLE IF EXISTS agencies');
      await db.execute('DROP TABLE IF EXISTS payments');
      await _onCreate(db, newVersion);
    }
  }

  // Client Operations
  Future<int> insertClient(Client client) async {
    Database db = await database;
    return await db.insert('clients', client.toMap());
  }

  Future<int> updateClient(Client client) async {
    Database db = await database;
    return await db.update('clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  Future<int> deleteClient(int id) async {
    Database db = await database;
    return await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Client>> getClients() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('clients');
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  // Client Contributions
  Future<int> insertContribution(ClientContribution contribution) async {
    Database db = await database;
    return await db.insert('client_contributions', contribution.toMap());
  }

  Future<int> updateContribution(ClientContribution contribution) async {
    Database db = await database;
    return await db.update('client_contributions', contribution.toMap(), where: 'id = ?', whereArgs: [contribution.id]);
  }

  Future<int> deleteContribution(int id) async {
    Database db = await database;
    return await db.delete('client_contributions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClientContribution>> getContributionsByClient(int clientId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('client_contributions', where: 'client_id = ?', whereArgs: [clientId], orderBy: 'date DESC');
    return List.generate(maps.length, (i) => ClientContribution.fromMap(maps[i]));
  }

  Future<double> getTotalClientContributions(int clientId) async {
    Database db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('SELECT SUM(amount) as total FROM client_contributions WHERE client_id = ?', [clientId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Agency Operations
  Future<int> insertAgency(Agency agency) async {
    Database db = await database;
    return await db.insert('agencies', agency.toMap());
  }

  Future<int> updateAgency(Agency agency) async {
    Database db = await database;
    return await db.update('agencies', agency.toMap(), where: 'id = ?', whereArgs: [agency.id]);
  }

  Future<int> deleteAgency(int id) async {
    Database db = await database;
    return await db.delete('agencies', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Agency>> getAgenciesByClient(int clientId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('agencies', where: 'client_id = ?', whereArgs: [clientId]);
    return List.generate(maps.length, (i) => Agency.fromMap(maps[i]));
  }

  // Payment Operations
  Future<int> insertPayment(Payment payment) async {
    Database db = await database;
    return await db.insert('payments', payment.toMap());
  }

  Future<int> updatePayment(Payment payment) async {
    Database db = await database;
    return await db.update('payments', payment.toMap(), where: 'id = ?', whereArgs: [payment.id]);
  }

  Future<int> deletePayment(int id) async {
    Database db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Payment>> getPaymentsByAgency(int agencyId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('payments', where: 'agency_id = ?', whereArgs: [agencyId], orderBy: 'date ASC');
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  Future<double> getTotalPaymentsBySource(int clientId, String source, {DateTime? upToDate}) async {
    Database db = await database;
    String query = '''
      SELECT SUM(p.amount) as total 
      FROM payments p 
      JOIN agencies a ON p.agency_id = a.id 
      WHERE a.client_id = ? AND p.payment_given_by = ?
    ''';
    List<dynamic> args = [clientId, source];

    if (upToDate != null) {
      query += ' AND p.date <= ?';
      args.add(upToDate.toIso8601String());
    }

    final List<Map<String, dynamic>> result = await db.rawQuery(query, args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getAllPaymentsForClient(int clientId) async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT p.*, a.name as agency_name 
      FROM payments p 
      JOIN agencies a ON p.agency_id = a.id 
      WHERE a.client_id = ?
    ''', [clientId]);
  }
}
