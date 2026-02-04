import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'survey_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE surveys(id INTEGER PRIMARY KEY AUTOINCREMENT, lokasi TEXT, kondisi TEXT, lat REAL, lng REAL, fotoPath TEXT)",
        );
      },
    );
  }

  // Simpan data ke HP
  Future<int> insertSurvey(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('surveys', row);
  }

  // Ambil semua data yang belum terkirim
  Future<List<Map<String, dynamic>>> getOfflineSurveys() async {
    Database db = await database;
    return await db.query('surveys');
  }

  // Hapus data setelah berhasil terkirim ke PostgreSQL
  Future<int> deleteSurvey(int id) async {
    Database db = await database;
    return await db.delete('surveys', where: 'id = ?', whereArgs: [id]);
  }
}
