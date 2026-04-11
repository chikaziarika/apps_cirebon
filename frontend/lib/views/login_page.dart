import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _loading = false;
  
  // Variabel untuk Limit Login
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockCountdown = 60;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer() {
    setState(() {
      _isLocked = true;
      _lockCountdown = 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_lockCountdown > 0) {
          _lockCountdown--;
        } else {
          _isLocked = false;
          _failedAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleLogin() async {
    if (_isLocked) return;

    String username = _userController.text.trim();
    String password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError("Username dan Password tidak boleh kosong.");
      return;
    }

    setState(() => _loading = true);

    final result = await _apiService.login(username, password);

    if (!mounted) return;

    if (result['status'] == 200) {
      // RESET ATTEMPTS KALAU SUKSES
      _failedAttempts = 0;
      
      final prefs = await SharedPreferences.getInstance();
      final data = result['body'];
      
      await prefs.setString('access_token', data['token'] ?? "");
      await prefs.setBool('is_admin', data['is_admin'] ?? false);
      await prefs.setString('username', data['username'] ?? username);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    } else {
      // PENANGANAN GAGAL LOGIN
      _failedAttempts++;
      
      String errorMsgFromApi = result['body']?['error']?.toString().toLowerCase() ?? "";
      String customPesan = "Terjadi kesalahan saat masuk sistem.";

      // Menyesuaikan pesan error elegan sesuai instruksi
      if (errorMsgFromApi.contains("password")) {
        customPesan = "Kredensial tidak cocok. Silakan periksa kembali kata sandi Anda.";
      } else if (errorMsgFromApi.contains("user") || errorMsgFromApi.contains("not found")) {
        customPesan = "Akun tidak ditemukan. Silakan hubungi Administrator DPUTR Kabupaten Cirebon.";
      } else {
        customPesan = "Akses ditolak. Pastikan username dan kata sandi sudah benar.";
      }

      if (_failedAttempts >= 3) {
        _showError("Batas percobaan habis. Silakan tunggu $_lockCountdown detik.");
        _startLockoutTimer();
      } else {
        _showError("$customPesan (Percobaan gagal: $_failedAttempts/3)");
      }
    }
    
    setState(() => _loading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _lupaPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lupa Kata Sandi", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Untuk alasan keamanan, pengaturan ulang kata sandi harus melalui verifikasi pusat.\n\n"
          "Silakan hubungi Administrator IT DPUTR Kabupaten Cirebon untuk bantuan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: SingleChildScrollView( // Agar tidak mentok keyboard saat ngetik
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 20), // Spacer Atas
                  
                  // ==============================
                  // BAGIAN ATAS: LOGO & JUDUL
                  // ==============================
                  Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        padding: const EdgeInsets.all(15), // Kasih ruang napas ke dalam
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white, // Kasih background putih biar kalau PNG transparan tetap aman
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo_sirigasi.png',
                          fit: BoxFit.contain, // INI KUNCINYA: Biar logo proporsional & gak nge-zoom
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        "SIRIGASI",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D47A1),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Sistem Informasi Kinerja Jaringan Irigasi\nDPUTR Kabupaten Cirebon",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  
                  // ==============================
                  // BAGIAN TENGAH: FORM LOGIN
                  // ==============================
                  Column(
                    children: [
                      const SizedBox(height: 40),
                      TextField(
                        controller: _userController,
                        enabled: !_isLocked,
                        decoration: InputDecoration(
                          labelText: "Username Surveyor",
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        enabled: !_isLocked,
                        decoration: InputDecoration(
                          labelText: "Kata Sandi",
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                          ),
                        ),
                      ),
                      
                      // Fitur Lupa Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLocked ? null : _lupaPassword,
                          child: const Text(
                            "Lupa Kata Sandi?",
                            style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Tombol Login / Loading / Peringatan Terkunci
                      _loading
                          ? const CircularProgressIndicator()
                          : _isLocked
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timer, color: Colors.red.shade700),
                                      const SizedBox(width: 10),
                                      Text(
                                        "Terkunci. Coba lagi dalam $_lockCountdown detik.",
                                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D47A1),
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    minimumSize: const Size(double.infinity, 55),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _handleLogin,
                                  child: const Text(
                                    "MASUK SISTEM",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                  ),
                                ),
                    ],
                  ),

                  // ==============================
                  // BAGIAN BAWAH: COPYRIGHT
                  // ==============================
                  const Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: Column(
                      children: [
                        Text(
                          "© 2026 DPUTR Kabupaten Cirebon.",
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "All Rights Reserved.\nDeveloped for SIRIGASI Project.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: Colors.blueGrey, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}