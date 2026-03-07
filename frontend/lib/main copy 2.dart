import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen()),
  );
}

// ==========================================
// UI: SPLASH SCREEN (Dengan Cek Login)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 3));
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    if (!mounted) return;

    // Jika token ada, masuk Dashboard. Jika tidak, ke Login.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            token != null ? const DashboardPage() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "e-PAKSI Mobile",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // TOMBOL LOGOUT
                IconButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Hapus semua token
                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                ),
              ],
            ),
            const Text(
              "Sistem Pengelolaan Aset Irigasi",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// UI: HALAMAN LOGIN (Koneksi ke JWT Django)
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _loading = false;

  Future<void> _handleLogin() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse("${SurveyService.baseUrl}/api/token/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text,
          "password": _passController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      } else {
        _showMsg("Login Gagal! Pastikan Username/Password benar.");
      }
    } catch (e) {
      _showMsg("Terjadi kesalahan koneksi ke server.");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              "LOGIN SURVEYOR",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: _handleLogin,
                    child: const Text(
                      "MASUK SISTEM",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Logout"),
      content: const Text("Apakah Anda yakin ingin keluar dari sistem?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal"),
        ),
        TextButton(
          onPressed: () async {
            // 1. Hapus token dari SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear(); // Menghapus access_token dkk

            if (!context.mounted) return;

            // 2. Tendang balik ke halaman Login
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false, // Hapus semua history navigasi
            );
          },
          child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

// ==========================================
// SERVICE: LOGIKA DATABASE & API
// ==========================================
class SurveyService {
  // PENTING: Gunakan IP Laptop Bapak agar HP bisa akses (0.0.0.0 di Django)
  // static const String baseUrl = "http://192.168.1.15:8000";
  static const String baseUrl = "http://10.0.2.2:8000";
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
        db.execute(
          "CREATE TABLE surveys(id INTEGER PRIMARY KEY AUTOINCREMENT, di_name TEXT, surveyor TEXT, kondisi_umum TEXT, catatan TEXT, lat REAL, lng REAL, fotoPaths TEXT, status_sync INTEGER)",
        );
        db.execute(
          "CREATE TABLE saluran(id INTEGER PRIMARY KEY AUTOINCREMENT, nama_saluran TEXT, jenis_konstruksi TEXT, kondisi TEXT, lat REAL, lng REAL, status_sync INTEGER)",
        );
      },
    );
  }
}

// ==========================================
// UI: HALAMAN DASHBOARD UTAMA
// ==========================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Biru
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                left: 25,
                right: 25,
                bottom: 30,
              ),
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARIS JUDUL DAN TOMBOL LOGOUT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "e-PAKSI Mobile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // TOMBOL LOGOUT DI SINI
                      IconButton(
                        icon: const Icon(
                          Icons.power_settings_new,
                          color: Colors.white,
                        ),
                        onPressed: () => _showLogoutDialog(context),
                      ),
                    ],
                  ),
                  const Text(
                    "Sistem Pengelolaan Aset Irigasi",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _headerStat("120", "Target DI"),
                      _headerStat("45", "Selesai"),
                      _headerStat("5", "Pending"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // MODUL: SEBARAN D.I (HORIZONTAL LIST & MAP)
            _buildDIMapSection(context),

            const SizedBox(height: 25),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Pilih Inventarisasi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(25),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  _menuTile(
                    context,
                    "Data Bangunan",
                    Icons.apartment_rounded,
                    Colors.orange,
                    const FormBangunanPage(),
                  ),
                  _menuTile(
                    context,
                    "Data Saluran",
                    Icons.water_outlined,
                    Colors.blue,
                    const FormSaluranPage(),
                  ),
                  _menuTile(
                    context,
                    "Peta GIS",
                    Icons.map_outlined,
                    Colors.green,
                    null,
                  ),
                  _menuTile(
                    context,
                    "Riwayat Sync",
                    Icons.sync_rounded,
                    Colors.purple,
                    null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDIMapSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            "Sebaran Daerah Irigasi",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              List<String> namaDI = [
                "D.I. Cipeujeuh",
                "D.I. Kamun",
                "D.I. Ciwaringin",
              ];
              List<String> luas = ["2.095 Ha", "1.450 Ha", "850 Ha"];
              return Container(
                width: MediaQuery.of(context).size.width * 0.8,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          image: const DecorationImage(
                            image: NetworkImage(
                              "https://docs.mapbox.com/android/maps/assets/images/screenshots/map-styles.png",
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  namaDI[index],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "Luas: ${luas[index]}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _headerStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _menuTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget? page,
  ) {
    return InkWell(
      onTap: () {
        if (page != null)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: color),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// UI: MODUL 1 - INVENTARISASI BANGUNAN
// ==========================================
class FormBangunanPage extends StatefulWidget {
  const FormBangunanPage({super.key});
  @override
  State<FormBangunanPage> createState() => _FormBangunanPageState();
}

class _FormBangunanPageState extends State<FormBangunanPage> {
  final TextEditingController _diController = TextEditingController();
  final TextEditingController _namaAsetController = TextEditingController();
  final TextEditingController _nomenklaturController = TextEditingController();
  final TextEditingController _surveyorController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();

  double? _lat, _lng;
  String _selectedKategori = 'Bangunan Utama';
  String _selectedKondisiAset = 'Baik';
  List<File> _images = [];
  bool _isLoading = false;

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
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengambil GPS.")));
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 35,
    );
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Form Inventarisasi Bangunan"),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Identitas Aset"),
            TextField(
              controller: _diController,
              decoration: const InputDecoration(
                labelText: "Nama Daerah Irigasi (D.I)",
                prefixIcon: Icon(Icons.water),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField(
              value: _selectedKategori,
              decoration: const InputDecoration(
                labelText: "Kategori Aset",
                border: OutlineInputBorder(),
              ),
              items: [
                'Bangunan Utama',
                'Bangunan Bagi',
                'Bangunan Sadap',
                'Bangunan Pelengkap',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedKategori = v as String),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _namaAsetController,
              decoration: const InputDecoration(
                labelText: "Nama Aset / Lokasi",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nomenklaturController,
              decoration: const InputDecoration(
                labelText: "Nomenklatur (Kode Aset)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),
            _sectionTitle("Lokasi & Dokumentasi"),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Lat: ${_lat?.toStringAsFixed(6) ?? '-'}",
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      Text(
                        "Lng: ${_lng?.toStringAsFixed(6) ?? '-'}",
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getLocation,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed),
                    label: const Text("Ambil Titik"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._images.map(
                    (f) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              f,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: InkWell(
                            onTap: () => setState(() => _images.remove(f)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_images.length < 5)
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            _sectionTitle("Dimensi & Kondisi"),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lebarController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Lebar (m)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _tinggiController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Tinggi (m)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField(
              value: _selectedKondisiAset,
              decoration: const InputDecoration(
                labelText: "Kondisi Fisik Bangunan",
                border: OutlineInputBorder(),
              ),
              items: [
                'Baik',
                'Rusak Ringan',
                'Rusak Berat',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) =>
                  setState(() => _selectedKondisiAset = v as String),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _surveyorController,
              decoration: const InputDecoration(
                labelText: "Nama Petugas Surveyor",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "SIMPAN DATA INVENTARISASI",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.orange[900],
        ),
      ),
    );
  }
}

// ==========================================
// UI: MODUL 2 - INVENTARISASI SALURAN
// ==========================================
class FormSaluranPage extends StatefulWidget {
  const FormSaluranPage({super.key});
  @override
  State<FormSaluranPage> createState() => _FormSaluranPageState();
}

class _FormSaluranPageState extends State<FormSaluranPage> {
  String _jenisSaluran = 'Tanah';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Input Data Saluran"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: "Nama Ruas Saluran",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField(
              value: _jenisSaluran,
              decoration: const InputDecoration(
                labelText: "Jenis Konstruksi",
                border: OutlineInputBorder(),
              ),
              items: [
                'Tanah',
                'Pasangan Batu',
                'Beton',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _jenisSaluran = v as String),
            ),
            const SizedBox(height: 15),
            const TextField(
              decoration: InputDecoration(
                labelText: "Lebar Atas (m)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            const TextField(
              decoration: InputDecoration(
                labelText: "Tinggi Saluran (m)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("SIMPAN DATA SALURAN"),
            ),
          ],
        ),
      ),
    );
  }
}
