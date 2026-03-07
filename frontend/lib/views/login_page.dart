import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dashboard_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _handleLogin() async {
    String username = _userController.text.trim();
    String password = _passController.text.trim();

    final result = await _apiService.login(username, password);

    if (result['status'] == 200) {
      final prefs = await SharedPreferences.getInstance();

      // Ambil data body
      final data = result['body'];

      // DEBUG: Cek di terminal VS Code, pastikan isinya ada 'token' dan 'is_admin'
      print("HASIL DARI DJANGO: $data");

      // 1. Ambil Token (Di Django Bapak namanya 'token', bukan 'access')
      await prefs.setString('access_token', data['token'] ?? "");

      // 2. Ambil is_admin (Di Django Bapak sudah benar 'is_admin')
      await prefs.setBool('is_admin', data['is_admin'] ?? false);

      // 3. Ambil Username
      await prefs.setString('username', data['username'] ?? username);

      if (!mounted) return;

      // Navigasi ke Dashboard (Cukup satu kali saja Navigator-nya Pak)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    } else {
      // TAMBAHKAN INI PAK:
      if (!mounted) return;
      setState(() => _loading = false); // Matikan loading jika gagal

      String pesan = result['body']?['error'] ?? "Gagal Masuk Sistem";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesan), backgroundColor: Colors.red),
      );
    }

    // Pastikan ini tetap ada di paling bawah
    if (mounted) setState(() => _loading = false);
  }

  Future<void> loginUser(String username, String password) async {
    final String baseUrl = "http://10.0.2.2:8000";

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login/"),
        body: {'username': username, 'password': password},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('is_admin', responseData['is_admin'] ?? false);
        await prefs.setString('username', responseData['username'] ?? "User");

        print("Data Login Disimpan - Admin: ${responseData['is_admin']}");

        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      print("Error: $e");
    }
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
                    ),
                    onPressed: _handleLogin,
                    child: const Text("MASUK SISTEM"),
                  ),
          ],
        ),
      ),
    );
  }
}
