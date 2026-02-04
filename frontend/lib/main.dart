import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: SurveyPage()),
  );
}

// ==========================================
// SERVICE: LOGIKA DATABASE & API
// ==========================================
class SurveyService {
  static const String baseUrl =
      "https://unretentive-nichole-unweaponed.ngrok-free.dev";
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = p.join(await getDatabasesPath(), 'survey_v4_final.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE surveys(id INTEGER PRIMARY KEY AUTOINCREMENT, di_name TEXT, surveyor TEXT, kondisi_umum TEXT, catatan TEXT, lat REAL, lng REAL, fotoPaths TEXT, status_sync INTEGER)",
        );
      },
    );
  }

  Future<bool> kirimKeServer(Map<String, dynamic> data) async {
    try {
      var uri = Uri.parse(
        "$baseUrl/upload-survey/",
      ); // Sesuai url di urls.py Django
      var request = http.MultipartRequest('POST', uri);

      request.fields['di_name'] = data['di_name'] ?? "";
      request.fields['surveyor'] = data['surveyor'] ?? "";
      request.fields['kondisi_umum'] = data['kondisi_umum'] ?? "";
      request.fields['catatan'] = data['catatan'] ?? "";
      request.fields['lat'] = data['lat'].toString();
      request.fields['lng'] = data['lng'].toString();

      // Ambil foto pertama untuk dikirim (sesuai model Django saat ini)
      List<String> paths = data['fotoPaths'].split(',');
      if (paths.isNotEmpty && await File(paths[0]).exists()) {
        request.files.add(await http.MultipartFile.fromPath('foto', paths[0]));
      }

      var response = await request.send().timeout(const Duration(seconds: 20));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> sinkronkanData(Function onComplete) async {
    final db = await database;
    final List<Map<String, dynamic>> offlineData = await db.query(
      'surveys',
      where: 'status_sync = 0',
    );

    for (var row in offlineData) {
      bool sukses = await kirimKeServer(Map<String, dynamic>.from(row));
      if (sukses) {
        await db.update(
          'surveys',
          {'status_sync': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    onComplete();
  }
}

// ==========================================
// UI: HALAMAN UTAMA
// ==========================================
class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});
  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final TextEditingController _diController = TextEditingController();
  final TextEditingController _surveyorController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  double? _lat, _lng;
  String _selectedKondisi = 'Baik';
  List<File> _images = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await SurveyService().database;
    final data = await db.query('surveys', orderBy: 'id DESC');
    setState(() => _history = data);
  }

  Future<void> _getLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _showSnackBar("GPS Error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      _showSnackBar("Maksimal 5 foto", Colors.orange);
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 35,
    );
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  // --- FUNGSI POP-UP DETAIL ---
  void _showDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Detail: ${item['di_name']}"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailText("Surveyor", item['surveyor']),
              _detailText("Kondisi", item['kondisi_umum']),
              _detailText("Koordinat", "${item['lat']}, ${item['lng']}"),
              _detailText("Catatan", item['catatan'] ?? "-"),
              const SizedBox(height: 10),
              const Text(
                "Foto:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                children: item['fotoPaths'].split(',').map<Widget>((path) {
                  return Image.file(
                    File(path),
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text("$label: $val", style: const TextStyle(fontSize: 14)),
  );

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Irigasi"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => SurveyService().sinkronkanData(_loadHistory),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _diController,
                    decoration: const InputDecoration(
                      labelText: "Nama D.I",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Koordinat: ${_lat ?? '-'} , ${_lng ?? '-'}",
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _getLocation,
                        child: const Text("Get GPS"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._images.map(
                          (f) => Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.file(
                              f,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (_images.length < 5)
                          IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_a_photo, size: 40),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _surveyorController,
                    decoration: const InputDecoration(
                      labelText: "Nama Surveyor",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    value: _selectedKondisi,
                    decoration: const InputDecoration(
                      labelText: "Kondisi",
                      border: OutlineInputBorder(),
                    ),
                    items: ['Baik', 'Kurang Baik', 'Rusak']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedKondisi = v as String),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _catatanController,
                    decoration: const InputDecoration(
                      labelText: "Catatan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (_images.isEmpty || _lat == null) {
                          _showSnackBar("Foto & GPS wajib!", Colors.red);
                          return;
                        }
                        final data = {
                          'di_name': _diController.text,
                          'surveyor': _surveyorController.text,
                          'kondisi_umum': _selectedKondisi,
                          'catatan': _catatanController.text,
                          'lat': _lat,
                          'lng': _lng,
                          'fotoPaths': _images.map((e) => e.path).join(','),
                        };
                        bool ok = await SurveyService().kirimKeServer(data);
                        final db = await SurveyService().database;
                        await db.insert('surveys', {
                          ...data,
                          'status_sync': ok ? 1 : 0,
                        });
                        _showSnackBar(
                          ok ? "Berhasil!" : "Offline Mode",
                          ok ? Colors.green : Colors.orange,
                        );
                        _loadHistory();
                      },
                      child: const Text("KIRIM"),
                    ),
                  ),
                  const Divider(height: 40),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "History Survey Perangkat:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, i) {
                      final item = _history[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            item['status_sync'] == 1
                                ? Icons.check_circle
                                : Icons.cloud_off,
                            color: item['status_sync'] == 1
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text("${item['di_name']}"),
                          subtitle: Text("Surveyor: ${item['surveyor']}"),
                          onTap: () => _showDetailDialog(item),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
