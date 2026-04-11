import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = p.join(await getDatabasesPath(), 'epaksi.db');
    return await openDatabase(
      path,
      version: 12, // <-- VERSI NAIK JADI 10
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE surveys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            di_id INTEGER,
            nama_di TEXT,
            nama_saluran TEXT,
            nama_bangunan TEXT,
            kode_aset TEXT,
            kondisi_bangunan TEXT,
            surveyor TEXT,
            lebar_saluran REAL,
            tinggi_saluran REAL,
            pintu_baik INTEGER,
            pintu_rr INTEGER,
            pintu_rb INTEGER,
            
            -- INI KOLOM BARU YANG WAJIB ADA DI ONCREATE
            lebar_pintu REAL DEFAULT 0,
            tinggi_pintu REAL DEFAULT 0,
            jenis_pintu TEXT,
            jenis_saluran_kiri TEXT,
            saluran_manual_kiri TEXT,
            nomenklatur_kiri TEXT,
            luas_kiri REAL DEFAULT 0,
            jenis_saluran_tengah TEXT,
            saluran_manual_tengah TEXT,
            nomenklatur_tengah TEXT,
            luas_tengah REAL DEFAULT 0,
            jenis_saluran_kanan TEXT,
            saluran_manual_kanan TEXT,
            nomenklatur_kanan TEXT,
            luas_kanan REAL DEFAULT 0,
            jumlah_cabang_sekunder INTEGER DEFAULT 0,
            jumlah_cabang_tersier INTEGER DEFAULT 0,
            is_saluran_berlanjut INTEGER DEFAULT 1,
            -- END KOLOM BARU
            
            jarak_dari_hulu REAL,
            desa TEXT,
            kecamatan TEXT,
            lat REAL,
            lng REAL,
            keterangan TEXT,
            foto1 TEXT,
            foto2 TEXT,
            foto3 TEXT,
            foto4 TEXT,
            foto5 TEXT,
            foto_pintu1 TEXT,
            foto_pintu2 TEXT,
            foto_pintu3 TEXT,
            terhubung_ke_id TEXT,
            status_sync INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
      CREATE TABLE saluran (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        di_id INTEGER,
        nama_di TEXT,
        nama_saluran TEXT,
        surveyor TEXT,
        hulu_id TEXT,
        tipe_hulu TEXT,
        tingkat_jaringan TEXT,
        kewenangan TEXT,
        panjang_saluran REAL,
        path_kondisi TEXT, 
        path_koordinat TEXT,
        foto TEXT,
        keterangan TEXT,
        keterangan_baik TEXT,  
        keterangan_rr TEXT,    
        keterangan_rb TEXT,   
        keterangan_bap TEXT,
        foto_baik TEXT,        
        foto_rr TEXT,         
        foto_rb TEXT,
        foto_bap TEXT,
        panjang_bap REAL DEFAULT 0,
        status_sync INTEGER DEFAULT 0
      )
    ''');

        await db.execute('''
      CREATE TABLE tracking_draft (
        di_id INTEGER PRIMARY KEY,
        nama_hulu TEXT,
        is_manual_hulu INTEGER,
        path_data TEXT,        -- String JSON dari List<LatLng>
        total_distance REAL,
        jarak_segmen REAL,
        kondisi_aktif TEXT
      )
    ''');

        await db.execute('''
          CREATE TABLE daerah_irigasi(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kode_di TEXT UNIQUE, nama_di TEXT, bendung TEXT,
            sumber_air TEXT, luas_permen REAL, luas_onemap REAL,
            coordinates TEXT, status_sync INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE surveys ADD COLUMN kondisi_bangunan TEXT DEFAULT 'BAIK'");
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE surveys ADD COLUMN surveyor TEXT");
          await db.execute("ALTER TABLE surveys ADD COLUMN lebar_saluran REAL DEFAULT 0");
          await db.execute("ALTER TABLE surveys ADD COLUMN tinggi_saluran REAL DEFAULT 0");
        }
        if (oldVersion < 5) {
          var columns = [
            'foto_rr1', 'foto_rr2', 'foto_rr3', 'foto_rr4', 'foto_rr5',
            'foto_rb1', 'foto_rb2', 'foto_rb3', 'foto_rb4', 'foto_rb5',
            'ket_baik', 'ket_rr', 'ket_rb',
          ];
          for (var col in columns) {
            await db.execute("ALTER TABLE surveys ADD COLUMN $col TEXT");
          }
          var saluranCols = [
            'keterangan_baik', 'keterangan_rr', 'keterangan_rb',
            'foto_baik', 'foto_rr', 'foto_rb',
          ];
          for (var col in saluranCols) {
            await db.execute("ALTER TABLE saluran ADD COLUMN $col TEXT");
          }
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tracking_draft (
              di_id INTEGER PRIMARY KEY,
              nama_hulu TEXT,
              is_manual_hulu INTEGER,
              path_data TEXT,
              total_distance REAL,
              jarak_segmen REAL,
              kondisi_aktif TEXT
            )
          ''');
          print("✅ Database di-upgrade ke versi 6");
        }
        if (oldVersion < 7) {
          await db.execute("ALTER TABLE saluran ADD COLUMN surveyor TEXT");
          print("✅ Database di-upgrade ke versi 7");
        }
        if (oldVersion < 8) {
          try {
            await db.execute("ALTER TABLE surveys ADD COLUMN keterangan_tambahan TEXT");
            print("✅ Database di-upgrade ke versi 8");
          } catch (e) { print("ℹ️ Kolom mungkin sudah ada, skip upgrade: $e"); }
        }
        if (oldVersion < 9) {
          try {
            await db.execute("ALTER TABLE saluran ADD COLUMN keterangan_bap TEXT");
            await db.execute("ALTER TABLE saluran ADD COLUMN foto_bap TEXT");
            await db.execute("ALTER TABLE saluran ADD COLUMN panjang_bap REAL DEFAULT 0");
            print("✅ Database di-upgrade ke versi 9");
          } catch (e) { print("ℹ️ Kolom BAP mungkin sudah ada: $e"); }
        }
        
        // --- UPGRADE KE VERSI 10: INJEKSI KOLOM BARU TANPA HAPUS APLIKASI ---
        if (oldVersion < 10) {
          var newColumns = [
            'foto_pintu1 TEXT', 'foto_pintu2 TEXT', 'foto_pintu3 TEXT',
            'terhubung_ke_id INTEGER', 'is_saluran_berlanjut INTEGER',
            'jenis_saluran_kiri TEXT', 'nomenklatur_kiri TEXT', 'luas_kiri REAL',
            'jenis_saluran_tengah TEXT', 'nomenklatur_tengah TEXT', 'luas_tengah REAL',
            'jenis_saluran_kanan TEXT', 'nomenklatur_kanan TEXT', 'luas_kanan REAL'
          ];
          for (var colDef in newColumns) {
            try {
              await db.execute("ALTER TABLE surveys ADD COLUMN $colDef");
            } catch (e) {
              print("ℹ️ Kolom mungkin sudah ada: $e");
            }
          }
          print("✅ Database di-upgrade ke versi 10: Kolom Foto Pintu & Percabangan berhasil ditambahkan.");
        }

        if (oldVersion < 11) {
          try {
            await db.execute("ALTER TABLE surveys ADD COLUMN lebar_pintu REAL DEFAULT 0");
            await db.execute("ALTER TABLE surveys ADD COLUMN tinggi_pintu REAL DEFAULT 0");
            print("✅ Database di-upgrade ke versi 11: Lebar & Tinggi Pintu ditambahkan.");
          } catch (e) {
            print("ℹ️ Kolom mungkin sudah ada: $e");
          }
        }

        if (oldVersion < 12) {
          try {
            await db.execute("ALTER TABLE surveys ADD COLUMN lebar_pintu REAL DEFAULT 0");
            await db.execute("ALTER TABLE surveys ADD COLUMN tinggi_pintu REAL DEFAULT 0");
            await db.execute("ALTER TABLE surveys ADD COLUMN jenis_pintu TEXT");
            
            // Kolom Cabang Kiri
            await db.execute("ALTER TABLE surveys ADD COLUMN jenis_saluran_kiri TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN saluran_manual_kiri TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN nomenklatur_kiri TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN luas_kiri REAL DEFAULT 0");
            
            // Kolom Cabang Tengah
            await db.execute("ALTER TABLE surveys ADD COLUMN jenis_saluran_tengah TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN saluran_manual_tengah TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN nomenklatur_tengah TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN luas_tengah REAL DEFAULT 0");
            
            // Kolom Cabang Kanan
            await db.execute("ALTER TABLE surveys ADD COLUMN jenis_saluran_kanan TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN saluran_manual_kanan TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN nomenklatur_kanan TEXT");
            await db.execute("ALTER TABLE surveys ADD COLUMN luas_kanan REAL DEFAULT 0");
            
            // Lainnya
            await db.execute("ALTER TABLE surveys ADD COLUMN jumlah_cabang_sekunder INTEGER DEFAULT 0");
            await db.execute("ALTER TABLE surveys ADD COLUMN jumlah_cabang_tersier INTEGER DEFAULT 0");
            await db.execute("ALTER TABLE surveys ADD COLUMN is_saluran_berlanjut INTEGER DEFAULT 1");
          } catch (e) {
            print("ℹ️ Kolom mungkin sudah ada: $e");
          }
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllDI() async {
    final db = await database;
    return await db.query('daerah_irigasi', orderBy: 'nama_di ASC');
  }

  Future<List<Map<String, dynamic>>> getPendingApprovalSurveys(int diId) async {
    final db = await database;
    return await db.query(
      'surveys',
      where: 'di_id = ? AND status_sync = 1',
      whereArgs: [diId],
      orderBy: 'id DESC', 
    );
  }

  Future<void> saveDraft(Map<String, dynamic> draftData) async {
    final db = await database;
    await db.insert('tracking_draft', draftData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getDraft(int diId) async {
    final db = await database;
    final res = await db.query('tracking_draft', where: 'di_id = ?', whereArgs: [diId]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> deleteDraft(int diId) async {
    final db = await database;
    await db.delete('tracking_draft', where: 'di_id = ?', whereArgs: [diId]);
  }

  Future<int> insertDI(String nama) async {
    final db = await database;
    return await db.insert('daerah_irigasi', {'nama_di': nama}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> markSaluranAsSynced(int id) async {
    final dbClient = await database; 
    return await dbClient.update('saluran', {'status_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> markSurveyAsSynced(int id) async {
    final dbClient = await database; 
    return await dbClient.update('surveys', {'status_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllSurveys() async {
    final db = await database;
    return await db.query('surveys');
  }

  Future<int> insertSurvey(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('surveys', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUnfinishedSurvey(int diId) async {
    final db = await _instance.database;
    final res = await db.query('saluran', where: 'di_id = ? AND status_sync = 0', whereArgs: [diId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<bool> simpanKeteranganSurvey({
    required int diId,
    required String ketBaik,
    required String ketRR,
    required String ketRB,
    required String ketBAP,
  }) async {
    try {
      final db = await _instance.database;
      int count = await db.update(
        'saluran',
        {
          'keterangan_baik': ketBaik,
          'keterangan_rr': ketRR,
          'keterangan_rb': ketRB,
          'keterangan_bap': ketBAP,
          'status_sync': 1, 
        },
        where: 'di_id = ?',
        whereArgs: [diId],
      );
      return count > 0;
    } catch (e) {
      print("Error simpan: $e");
      return false;
    }
  }

  Future<int> updateStatusSurvey(int diId, int status) async {
    final db = await _instance.database;
    return await db.update('saluran', {'status_sync': status}, where: 'di_id = ? AND status_sync = 0', whereArgs: [diId]);
  }

  Future<void> clearAllDI() async {
    final db = await database;
    await db.delete('daerah_irigasi');
  }

  Future<void> saveSurveyLokal(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('surveys', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> cleanDuplicateData() async {
    final db = await database;
    await db.execute('''
    DELETE FROM saluran 
    WHERE id NOT IN (SELECT MAX(id) FROM saluran GROUP BY nama_saluran)
  ''');
    await db.execute('''
    DELETE FROM surveys 
    WHERE id NOT IN (SELECT MAX(id) FROM surveys GROUP BY nama_bangunan)
  ''');
    print("✅ Database bersih dari duplikat");
  }

  Future<int> updateSurvey(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('surveys', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSurveys() async {
    final db = await database;
    return await db.query('surveys', where: 'status_sync = ?', whereArgs: [0]);
  }

  Future<int> deleteSurvey(int id) async {
    final db = await database;
    return await db.delete('surveys', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertDIFull(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('daerah_irigasi', data, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deleteSaluran(int id) async {
    final db = await database;
    return await db.delete('saluran', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateDI(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update('daerah_irigasi', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDI(int id) async {
    final db = await database;
    return await db.delete('daerah_irigasi', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllDIFull() async {
    final db = await database;
    return await db.query('daerah_irigasi', orderBy: 'nama_di ASC');
  }

  Future<int> insertSaluran(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('saluran', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSyncStatus(String table, int id) async {
    final db = await database;
    await db.update(table, {'status_sync': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getUniqueSaluranByDI(int diId) async {
    final db = await database;
    return await db.rawQuery("SELECT DISTINCT nama_saluran FROM saluran WHERE di_id = ?", [diId]);
  }

  Future<List<Map<String, dynamic>>> getUniqueBangunanByDI(int diId) async {
    final db = await database;
    return await db.rawQuery("SELECT DISTINCT nama_bangunan FROM surveys WHERE di_id = ?", [diId]);
  }

  Future<List<Map<String, dynamic>>> getPendingApprovalSaluran(int diId) async {
    final db = await database;
    return await db.query('saluran', where: 'di_id = ? AND status_sync = 0', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getPendingSaluran(int diId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT * FROM saluran 
    WHERE di_id = ? AND status_sync = 0 
    GROUP BY nama_saluran 
    ORDER BY id DESC
  ''', [diId]);
  }

  Future<int> updateSaluran(int id, Map<String, dynamic> data) async {
    final db = await database; 
    return await db.update('saluran', data, where: 'id = ?', whereArgs: [id]);
  }
}