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
  bool _isObscure = true;
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
      _failedAttempts++;
      
      String errorMsgFromApi = result['body']?['error']?.toString().toLowerCase() ?? "";
      String customPesan = "Terjadi kesalahan saat masuk sistem.";
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
                        obscureText: _isObscure,
                        enabled: !_isLocked,
                        decoration: InputDecoration(
                          labelText: "Kata Sandi",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscure = !_isObscure; // Membalikkan keadaan mata terbuka/tertutup
                              });
                            },
                          ),
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
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Text(
                              "Kebijakan Privasi",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      "Terakhir diperbarui: 11 April 2026\n",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(
                                      "Kebijakan privasi ini berlaku untuk aplikasi SIRIGASI untuk perangkat seluler yang dibuat oleh Admin Caruban sebagai layanan Gratis.\n",
                                      style: TextStyle(fontSize: 13),
                                      textAlign: TextAlign.justify,
                                    ),
                                    Text(
                                      "1. Pengumpulan dan Penggunaan Informasi",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Aplikasi mengumpulkan lokasi perangkat Anda untuk membantu kami:\n"
                                      "• Menyediakan layanan Geolokasi untuk pemetaan aset irigasi.\n"
                                      "• Menganalisis dan meningkatkan fungsionalitas Aplikasi.\n\n"
                                      "Kami mungkin meminta Anda untuk memberikan informasi pengenal pribadi tertentu, termasuk namun tidak terbatas pada Nama, Email, Lokasi, dan Foto.\n",
                                      style: TextStyle(fontSize: 13),
                                      textAlign: TextAlign.justify,
                                    ),
                                    Text(
                                      "2. Akses Pihak Ketiga",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Hanya data yang diagregasi dan dianonimkan yang secara berkala dikirimkan ke layanan eksternal untuk membantu peningkatan Aplikasi. Kami dapat mengungkapkan informasi hanya jika diwajibkan oleh hukum atau untuk melindungi keamanan.\n",
                                      style: TextStyle(fontSize: 13),
                                      textAlign: TextAlign.justify,
                                    ),
                                    Text(
                                      "3. Penyimpanan Data & Keamanan",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Kami akan menyimpan data selama Anda menggunakan Aplikasi. Kami menyediakan pengamanan fisik, elektronik, dan prosedural untuk melindungi kerahasiaan informasi Anda.\n",
                                      style: TextStyle(fontSize: 13),
                                      textAlign: TextAlign.justify,
                                    ),
                                    Text(
                                      "4. Hak Menolak (Opt-Out)",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Anda dapat menghentikan semua pengumpulan informasi dengan mudah melalui penghapusan instalasi (uninstall) Aplikasi.\n",
                                      style: TextStyle(fontSize: 13),
                                      textAlign: TextAlign.justify,
                                    ),
                                    Text(
                                      "5. Hubungi Kami",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Jika Anda memiliki pertanyaan mengenai privasi, silakan hubungi kami melalui email di devappscaruban@gmail.com.\n",
                                      style: TextStyle(fontSize: 13),
                                      textAlign: TextAlign.justify,
                                    ),
                                    Text(
                                      "Dengan menggunakan Aplikasi, Anda menyetujui pemrosesan informasi Anda sebagaimana diatur dalam Kebijakan Privasi ini.",
                                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                                      textAlign: TextAlign.justify,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D47A1),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text("Saya Mengerti", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text(
                      '© 2026 DPUTR Kabupaten Cirebon\nKetuk untuk baca Kebijakan Privasi',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}