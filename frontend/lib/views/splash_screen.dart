import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFE3F2FD),
            ], // Gradasi putih ke biru muda
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Kabupaten Cirebon
            Image.asset(
              "assets/images/logo_sirigasi.png", // Pakai logo lokal yang sudah ada
              height: 150,
            ),
            const SizedBox(height: 30),
            const Text(
              "SIRIGASI",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0D47A1),
                letterSpacing: 2,
              ),
            ),
            const Text(
              "DPUTR KABUPATEN CIREBON",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            ),
            const SizedBox(height: 20),
            const Text(
              "Memuat Data...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
