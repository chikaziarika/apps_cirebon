import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ApiService {
  // Gunakan IP Laptop jika pakai Emulator, atau IP Lokal jika pakai HP asli
  // static const String baseUrl = "http://10.0.2.2:8000";
  // static const String baseUrl = "http://192.168.18.30:8000";
  // static const String baseUrl = "https://05c3b3fa29c164.lhr.life";\
  static const String baseUrl = "https://api.pentasconstruction.com";

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final body = jsonDecode(response.body);

      // --- TAMBAHKAN BAGIAN INI PAK ---
      if (response.statusCode == 200 && body['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'token',
          body['token'],
        ); // Simpan token ke memori HP
        debugPrint("✅ TOKEN BERHASIL DISIMPAN: ${body['token']}");
      }
      // --------------------------------

      return {"status": response.statusCode, "body": body};
    } catch (e) {
      print("ERROR LOGIN API: $e");
      return {
        "status": 500,
        "body": {"error": e.toString()},
      };
    }
  }

  Future<List<dynamic>> fetchMasterHulu(int diId) async {
    try {
      // Pastikan endpoint ini sesuai dengan yang ada di Django/Server Bapak
      final response = await http.get(
        Uri.parse('$baseUrl/api/master-hulu/$diId/'),
      );

      if (response.statusCode == 200) {
        // Kita asumsikan server mengembalikan data dalam bentuk List
        final List<dynamic> responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Gagal menarik data hulu dari server');
      }
    } catch (e) {
      throw Exception('Koneksi server gagal: $e');
    }
  }

  // --- FUNGSI FETCH DATA ---
  Future<List<dynamic>> fetchDaerahIrigasi() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/daerah-irigasi/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Gagal mengambil data D.I.');
      }
    } catch (e) {
      throw Exception('Koneksi server gagal: $e');
    }
  }

  Future<bool> syncSaluran(Map<String, dynamic> data) async {
    debugPrint("🔍 DATA YANG AKAN DI-SYNC: " + jsonEncode(data));

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    if (token == null) return false;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/sync/saluran/"),
      );

      // 1. Header
      request.headers['Authorization'] = "Bearer $token";

      // 2. Data Utama (Gunakan null check yang kuat)
      request.fields['di_id'] = (data['di_id'] ?? "").toString();
      request.fields['nama_saluran'] = data['nama_saluran']?.toString() ?? "";
      request.fields['surveyor'] = data['surveyor']?.toString() ?? "Anonim";
      request.fields['panjang_saluran'] = (data['panjang_saluran'] ?? 0)
          .toString();
      request.fields['tingkat_jaringan'] =
          data['tingkat_jaringan']?.toString() ?? "";
      request.fields['kewenangan'] = data['kewenangan']?.toString() ?? "";
      request.fields['path_koordinat'] =
          data['path_koordinat']?.toString() ?? "";
      request.fields['path_kondisi'] = data['path_kondisi']?.toString() ?? "[]";

      // 3. Data Kondisi (Pastikan field BAP selalu terkirim sebagai string, jangan null)
      // Server error 'bap' biasanya karena field ini kosong atau tidak terdefinisi
      request.fields['panjang_bap'] = (data['panjang_bap'] ?? 0).toString();
      request.fields['keterangan_baik'] = (data['keterangan_baik'] ?? "")
          .toString();
      request.fields['keterangan_rr'] = (data['keterangan_rr'] ?? "")
          .toString();
      request.fields['keterangan_rb'] = (data['keterangan_rb'] ?? "")
          .toString();
      request.fields['keterangan_bap'] = (data['keterangan_bap'] ?? "")
          .toString();

      if (data.containsKey('kondisi_aktif')) {
        request.fields['kondisi_utama'] = data['kondisi_aktif'].toString();
      }

      // 4. Logika Upload Foto (Sudah Rapi)
      void addImageFile(String fieldName, String? jsonPath) {
        if (jsonPath != null && jsonPath != "[]" && jsonPath.isNotEmpty) {
          try {
            String filePath = "";
            if (jsonPath.startsWith('[')) {
              List<dynamic> paths = jsonDecode(jsonPath);
              if (paths.isNotEmpty) filePath = paths[0];
            } else {
              filePath = jsonPath;
            }

            if (filePath.isNotEmpty) {
              File gambar = File(filePath);
              if (gambar.existsSync()) {
                request.files.add(
                  http.MultipartFile.fromBytes(
                    fieldName,
                    gambar.readAsBytesSync(),
                    filename: filePath.split('/').last,
                  ),
                );
                debugPrint("📸 Foto $fieldName berhasil dilampirkan.");
              }
            }
          } catch (e) {
            debugPrint("⚠️ Gagal memproses path foto $fieldName: $e");
          }
        }
      }

      addImageFile('foto_baik', data['foto_baik']);
      addImageFile('foto_rr', data['foto_rr']);
      addImageFile('foto_rb', data['foto_rb']);
      addImageFile('foto_bap', data['foto_bap']);

      // 5. Kirim data
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      debugPrint(
        "🟢 HASIL SYNC: ${responseData.statusCode} - ${responseData.body}",
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint("🔴 ERROR FATAL: $e");
      return false;
    }
  }

  // --- SYNC DAERAH IRIGASI ---
  Future<Map<String, dynamic>?> syncDaerahIrigasi(
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      debugPrint("❌ ERROR: Token kosong!");
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/sync/daerah-irigasi/"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      debugPrint("🟢 RESPONSE DI: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Balikin datanya dalam bentuk Map supaya bisa dibaca response['id']
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("🔴 ERROR SYNC DI: $e");
      return null;
    }
  }

  Future<bool> syncBangunan(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) return false;

    try {
      // 1. Gunakan MultipartRequest untuk kirim Foto
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/sync/bangunan/"),
      );

      // 2. Header Token
      request.headers['Authorization'] = "Bearer $token";

      // 3. Tambahkan Data Teks
      // Pastikan key (sebelah kiri) SAMA PERSIS dengan field di Django Bapak
      request.fields['di_id'] = data['di_id'].toString();
      request.fields['nama_di'] = data['nama_di'] ?? "";
      request.fields['nama_saluran'] = data['nama_saluran'] ?? "";
      request.fields['nama_bangunan'] = data['nama_bangunan'] ?? "";
      request.fields['kode_aset'] = data['kode_aset'] ?? "";
      request.fields['kondisi_bangunan'] = data['kondisi_bangunan'] ?? "";
      request.fields['surveyor'] = data['surveyor'] ?? "Anonim";
      request.fields['lebar_saluran'] = data['lebar_saluran'].toString();
      request.fields['tinggi_saluran'] = data['tinggi_saluran'].toString();
      request.fields['pintu_baik'] = data['pintu_baik'].toString();
      request.fields['pintu_rr'] = data['pintu_rr'].toString();
      request.fields['pintu_rb'] = data['pintu_rb'].toString();
      request.fields['jenis_pintu'] = data['jenis_pintu'] ?? "";
      request.fields['jarak_dari_hulu'] = data['jarak_dari_hulu'].toString();
      request.fields['desa'] = data['desa'] ?? "";
      request.fields['kecamatan'] = data['kecamatan'] ?? "";
      request.fields['lat'] = data['lat'].toString();
      request.fields['lng'] = data['lng'].toString();
      request.fields['keterangan'] =
          data['keterangan'] ?? ""; // Keterangan Bangunan

      // 4. Tambahkan File Foto (foto1 sampai foto5)
      for (int i = 1; i <= 5; i++) {
        String key = 'foto$i';
        String? filePath = data[key];

        if (filePath != null &&
            filePath.isNotEmpty &&
            !filePath.startsWith('http')) {
          File gambar = File(filePath);
          if (gambar.existsSync()) {
            request.files.add(
              await http.MultipartFile.fromPath(
                key,
                filePath,
                filename: filePath.split('/').last,
              ),
            );
            debugPrint("📸 Lampirkan $key: $filePath");
          }
        }
      }

      // 5. Kirim ke Server
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint(
        "🟢 RESPONSE BANGUNAN: ${response.statusCode} - ${response.body}",
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("🔴 ERROR FATAL SYNC BANGUNAN: $e");
      return false;
    }
  }

  Future<List<dynamic>> fetchSaluranMaster(int diId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/saluran/$diId/'));

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception(
          'Gagal menarik data saluran: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Koneksi server gagal: $e');
    }
  }

  Future<List<dynamic>> fetchBangunanMaster(int diId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/bangunan/$diId/'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception(
          'Gagal menarik data bangunan: Status ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Koneksi server gagal: $e');
    }
  }

  // --- PROSES LOGOUT ---
  Future<void> prosesLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Gunakan pushReplacement agar tidak bisa 'Back'
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<List<dynamic>> fetchPendingSurveySaluran(int diId) async {
    try {
      // Pastikan URL ini mengarah ke API list saluran (bukan API sinkronisasi)
      final response = await http.get(Uri.parse('$baseUrl/api/saluran/$diId/'));

      if (response.statusCode == 200) {
        // Perhatikan format JSON dari Django Bapak
        var decoded = json.decode(response.body);
        List<dynamic> allData = decoded['data'] ?? [];

        // FILTER DI SINI: Hanya ambil yang is_approved == false
        return allData.where((item) => item['is_approved'] == false).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error: $e");
      return [];
    }
  }
}
