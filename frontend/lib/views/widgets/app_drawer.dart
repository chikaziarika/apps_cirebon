import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_page.dart';
import '../master_di_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _username = "User";
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // Mengambil data user yang disimpan saat login
  void _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "User";
      _isAdmin = prefs.getBool('is_admin') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // HEADER: Tempat Nama & Profil
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blueAccent),
            accountName: Text(
              _username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              _isAdmin ? "Status: Administrator" : "Status: Surveyor",
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
            ),
          ),

          // MENU LIST
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard Utama"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text("Peta Irigasi"),
            onTap: () {
              /* Navigasi ke Peta */
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text("Master Daerah Irigasi"),
            onTap: () {
              Navigator.pop(context); // Tutup drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MasterDiPage()),
              );
            },
          ),

          const Spacer(), // Dorong menu logout ke paling bawah
          const Divider(),

          // TOMBOL LOGOUT
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Keluar Aplikasi",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              // 1. Bersihkan Memori
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!context.mounted) return;

              // 2. Lempar ke Login (Route '/' atau LoginPage)
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
