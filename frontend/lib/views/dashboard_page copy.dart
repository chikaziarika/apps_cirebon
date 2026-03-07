import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import '../services/sync_page.dart';
import 'form_bangunan.dart';
import 'form_saluran.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../views/form_di_page.dart';
import '../views/main_survey_page.dart';
import '../views/master_di_page.dart';
import '../views/widgets/app_drawer.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // 1. FUNGSI LOGOUT
  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    print(
      "Memori dibersihkan. is_admin sekarang: ${prefs.getBool('is_admin')}",
    );

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // 2. FUNGSI SYNC MASSAL (TAMBAHAN BARU)
  Future<void> _runMassSync(BuildContext context) async {
    final api = ApiService();
    final db = DatabaseService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    int successCount = 0;

    try {
      // 1. Sync Data Bangunan (Titik Survey)
      final unsyncedSurveys = await db.getUnsyncedSurveys();
      for (var item in unsyncedSurveys) {
        // Kirim data ke Django
        bool ok = await api.syncBangunan(item);
        if (ok) {
          await db.updateSyncStatus('surveys', item['id']);
          successCount++;
        }
      }

      // 2. Sync Data Saluran (Jalur Saluran)
      final dbClient = await db.database;
      final List<Map<String, dynamic>> unsyncedSaluran = await dbClient.query(
        'saluran',
        where: 'status_sync = ?',
        whereArgs: [0],
      );

      for (var item in unsyncedSaluran) {
        bool ok = await api.syncSaluran(item);
        if (ok) {
          await db.updateSyncStatus('saluran', item['id']);
          successCount++;
        }
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Tutup Loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Berhasil sinkron $successCount data ke server!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal sync: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER SECTION
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "SIKERIS DPUTR KAB. CIREBON",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              softWrap: true,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.power_settings_new,
                          color: Colors.white,
                        ),
                        onPressed: () => _handleLogout(context),
                      ),
                    ],
                  ),
                  const Text(
                    "Sistem Pengelolaan Aset Irigasi",
                    style: TextStyle(color: Colors.white70),
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

            const SizedBox(height: 30),

            // MENU GRID
            // MENU GRID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GridView.count(
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
                    Colors.blue,
                    const MainSurveyPage(), // Mengarah ke Peta/Survey
                  ),
                  // _menuTile(
                  //   context,
                  //   "Data Bangunan",
                  //   Icons.apartment,
                  //   Colors.orange,
                  //   const FormBangunanPage(),
                  // ),
                  // _menuTile(
                  //   context,
                  //   "Data Saluran",
                  //   Icons.water,
                  //   Colors.blue,
                  //   const FormSaluranPage(),
                  // ),
                  // _menuTile(
                  //   context,
                  //   "Peta GIS",
                  //   Icons.public, // Mengganti ikon agar berbeda dengan Survey
                  //   Colors.green,
                  //   null, // Fitur belum ada
                  // ),
                  _menuTile(
                    context,
                    "Riwayat Sync",
                    Icons.sync,
                    Colors.purple,
                    const SyncPage(),
                  ),
                  _menuTile(
                    context,
                    "Data Master D.I.",
                    Icons.storage_rounded,
                    Colors.redAccent,
                    const MasterDiPage(), // SEKARANG MENGARAH KE MASTER DI PAGE
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  // WIDGET MENU TILE YANG SUDAH DIMODIFIKASI
  Widget _menuTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget? page,
  ) {
    return InkWell(
      onTap: () {
        if (page != null) {
          // Navigasi sesuai dengan halaman yang dimasukkan di parameter 'page'
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        } else {
          // Jika parameter page null, baru tampilkan "Segera datang"
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Fitur segera datang!"),
              duration: Duration(seconds: 1),
            ),
          );
        }
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
