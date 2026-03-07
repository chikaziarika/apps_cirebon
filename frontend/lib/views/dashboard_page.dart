import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import '../services/sync_page.dart';
import '../views/main_survey_page.dart';
import '../views/master_di_page.dart';
import '../views/widgets/app_drawer.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _currentSurveyor = "Surveyor";

  @override
  void initState() {
    super.initState();
    _loadUser();
    // _loadStatistics();
  }

  int _totalSaluran = 0;
  int _totalBangunan = 0;
  int _belumSinkron = 0;

  // Future<void> _loadStatistics() async {
  //   final db = DatabaseService();
  //   final dbClient = await db.database;

  //   // 1. Hitung Total Saluran
  //   final countSaluran =
  //       Sqflite.firstIntValue(
  //         await dbClient.rawQuery('SELECT COUNT(*) FROM saluran'),
  //       ) ??
  //       0;

  //   // 2. Hitung Total Bangunan (dari tabel surveys)
  //   final countBangunan =
  //       Sqflite.firstIntValue(
  //         await dbClient.rawQuery('SELECT COUNT(*) FROM surveys'),
  //       ) ??
  //       0;

  //   // 3. Hitung Data Belum Sinkron (status_sync = 0 dari kedua tabel)
  //   final unsyncedSaluran =
  //       Sqflite.firstIntValue(
  //         await dbClient.rawQuery(
  //           'SELECT COUNT(*) FROM saluran WHERE status_sync = 0',
  //         ),
  //       ) ??
  //       0;
  //   final unsyncedBangunan =
  //       Sqflite.firstIntValue(
  //         await dbClient.rawQuery(
  //           'SELECT COUNT(*) FROM surveys WHERE status_sync = 0',
  //         ),
  //       ) ??
  //       0;

  //   setState(() {
  //     _totalSaluran = countSaluran;
  //     _totalBangunan = countBangunan;
  //     _belumSinkron = unsyncedSaluran + unsyncedBangunan;
  //   });
  // }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSurveyor = prefs.getString('username') ?? "Surveyor";
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Warna background lebih soft
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // 1. HEADER SECTION (Modern Gradient)
          _buildHeader(context),

          // 2. MENU SECTION
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Layanan Utama",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    children: [
                      _menuTile(
                        context,
                        "Survey D.I.",
                        Icons.map_outlined,
                        const Color(0xFF1E88E5),
                        const MainSurveyPage(),
                      ),
                      _menuTile(
                        context,
                        "Riwayat Sync",
                        Icons.sync_rounded,
                        const Color(0xFF8E24AA),
                        const SyncPage(),
                      ),
                      _menuTile(
                        context,
                        "Master Data DI",
                        Icons.storage_rounded,
                        const Color(0xFFD81B60),
                        const MasterDiPage(),
                      ),
                      // Menu Peta GIS, Saluran, Bangunan disembunyikan dulu
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 50, 25, 35),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP ROW: Menu & Logout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                onPressed: () => _handleLogout(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // JUDUL, DESKRIPSI & LOGO
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // KIRI: Teks Judul & Deskripsi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SIRIGASI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Sistem Indeks Irigasi DPUTR Kab. Cirebon",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              // KANAN: Logo SIRIGASI
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                  image: const DecorationImage(
                    image: AssetImage(
                      'assets/images/logo_sirigasi.png',
                    ), // Pastikan file ada di folder assets
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // USER INFO
          Text(
            "Selamat Bekerja,",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
          Text(
            _currentSurveyor.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),

          // CARD RINGKASAN DATA (UPDATING LABELS)
          // Container(
          //   padding: const EdgeInsets.symmetric(vertical: 18),
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.12),
          //     borderRadius: BorderRadius.circular(20),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceAround,
          //     children: [
          //       _headerStat(
          //         "$_totalSaluran",
          //         "Total Saluran",
          //       ), // Pakai variabel Pak
          //       _vDivider(),
          //       _headerStat("$_totalBangunan", "Total Bangunan"),
          //       _vDivider(),
          //       _headerStat("$_belumSinkron", "Belum Sinkron"),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(height: 20, width: 1, color: Colors.white24);

  Widget _headerStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Widget _menuTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
