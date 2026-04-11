import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ApiService {
  static const String baseUrl = "https://sirigasi.dputrkabcirebon.id";

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'token',
          body['token'],
        ); 
        debugPrint("✅ TOKEN BERHASIL DISIMPAN: ${body['token']}");
      }

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

      final response = await http.get(
        Uri.parse('$baseUrl/api/master-hulu/$diId/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Gagal menarik data hulu dari server');
      }
    } catch (e) {
      throw Exception('Koneksi server gagal: $e');
    }
  }

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

      request.headers['Authorization'] = "Bearer $token";
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

      Future<void> attachFoto(String fieldName, String? jsonPath) async {
        if (jsonPath != null && jsonPath != "[]" && jsonPath.isNotEmpty) {
          try {
            String filePath = "";
            if (jsonPath.startsWith('[')) {
              List<dynamic> paths = jsonDecode(jsonPath);
              if (paths.isNotEmpty) filePath = paths[0].toString();
            } else {
              filePath = jsonPath;
            }
            if (filePath.isNotEmpty && !filePath.startsWith('http')) {
              File gambar = File(filePath);
              if (gambar.existsSync()) {
                request.files.add(
                  await http.MultipartFile.fromPath(
                    fieldName, 
                    filePath, 
                    filename: filePath.split('/').last
                  )
                );
                debugPrint("📸 Foto Saluran $fieldName dilampirkan: $filePath");
              }
            }
          } catch (e) {
            debugPrint("⚠️ Gagal memproses path foto $fieldName: $e");
          }
        }
      }

      await attachFoto('foto_baik', data['foto_baik']);
      await attachFoto('foto_rr', data['foto_rr']);
      await attachFoto('foto_rb', data['foto_rb']);
      await attachFoto('foto_bap', data['foto_bap']);

      if (data['path_kondisi'] != null && data['path_kondisi'] != "[]") {
        try {
          List<dynamic> segmenList = jsonDecode(data['path_kondisi']);
          for (int i = 0; i < segmenList.length; i++) {
            List<dynamic> segFotos = segmenList[i]['fotos'] ?? [];
            for (int j = 0; j < segFotos.length; j++) {
              if (j >= 5) break; // Maksimal 5 foto sesuai Django
              String path = segFotos[j].toString();
              if (path.isNotEmpty && !path.startsWith('http')) {
                File img = File(path);
                if (img.existsSync()) {
                  request.files.add(await http.MultipartFile.fromPath(
                      'segmen_${i}_foto_$j', path,
                      filename: path.split('/').last));
                  debugPrint("📸 Foto Segmen Ke-$i (Foto $j) dilampirkan!");
                }
              }
            }
          }
        } catch (e) {
          debugPrint("⚠️ Gagal membungkus foto segmen: $e");
        }
      }

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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/sync/bangunan/"),
      );

      request.headers['Authorization'] = "Bearer $token";
      request.fields['di_id'] = data['di_id'].toString();
      request.fields['nama_di'] = data['nama_di'] ?? "";
      request.fields['nama_saluran'] = data['nama_saluran'] ?? "";
      request.fields['nama_bangunan'] = data['nama_bangunan'] ?? "";
      request.fields['kode_aset'] = data['kode_aset'] ?? "";
      request.fields['kondisi_bangunan'] = data['kondisi_bangunan'] ?? "";
      request.fields['surveyor'] = data['surveyor'] ?? "Anonim";
      request.fields['keterangan'] = data['keterangan'] ?? "";
      request.fields['desa'] = data['desa'] ?? "";
      request.fields['kecamatan'] = data['kecamatan'] ?? "";
      request.fields['lat'] = data['lat']?.toString() ?? "0";
      request.fields['lng'] = data['lng']?.toString() ?? "0";
      String teksHulu = data['terhubung_ke_id']?.toString() ?? "";
      
      request.fields['hulu_nomenklatur'] = teksHulu; 
      request.fields['jarak_dari_hulu'] = data['jarak_dari_hulu']?.toString() ?? "0";
      
      debugPrint("🎯 FIX FINAL MENGIRIM HULU KE DJANGO: $teksHulu");
      request.fields['lebar_saluran'] = data['lebar_saluran']?.toString() ?? "0";
      request.fields['tinggi_saluran'] = data['tinggi_saluran']?.toString() ?? "0";
      request.fields['pintu_baik'] = data['pintu_baik']?.toString() ?? "0";
      request.fields['pintu_rr'] = data['pintu_rr']?.toString() ?? "0";
      request.fields['pintu_rb'] = data['pintu_rb']?.toString() ?? "0";
      request.fields['jenis_pintu'] = data['jenis_pintu'] ?? "";
      request.fields['lebar_pintu'] = data['lebar_pintu']?.toString() ?? "0";
      request.fields['tinggi_pintu'] = data['tinggi_pintu']?.toString() ?? "0";
      request.fields['jenis_saluran_kiri'] = data['jenis_saluran_kiri'] ?? "TERSIER";
      request.fields['saluran_manual_kiri'] = data['saluran_manual_kiri'] ?? "";
      request.fields['nomenklatur_kiri'] = data['nomenklatur_kiri'] ?? "";
      request.fields['luas_kiri'] = data['luas_kiri']?.toString() ?? "0";
      request.fields['jenis_saluran_tengah'] = data['jenis_saluran_tengah'] ?? "INDUK";
      request.fields['saluran_manual_tengah'] = data['saluran_manual_tengah'] ?? "";
      request.fields['nomenklatur_tengah'] = data['nomenklatur_tengah'] ?? "";
      request.fields['luas_tengah'] = data['luas_tengah']?.toString() ?? "0";
      request.fields['jenis_saluran_kanan'] = data['jenis_saluran_kanan'] ?? "TERSIER";
      request.fields['saluran_manual_kanan'] = data['saluran_manual_kanan'] ?? "";
      request.fields['nomenklatur_kanan'] = data['nomenklatur_kanan'] ?? "";
      request.fields['luas_kanan'] = data['luas_kanan']?.toString() ?? "0";
      request.fields['jumlah_cabang_sekunder'] = data['jumlah_cabang_sekunder']?.toString() ?? "0";
      request.fields['jumlah_cabang_tersier'] = data['jumlah_cabang_tersier']?.toString() ?? "0";
      request.fields['is_saluran_berlanjut'] = data['is_saluran_berlanjut']?.toString() ?? "true";
      for (int i = 1; i <= 5; i++) {
        String key = 'foto$i';
        String? filePath = data[key];
        if (filePath != null && filePath.isNotEmpty && !filePath.startsWith('http')) {
          File gambar = File(filePath);
          if (gambar.existsSync()) {
            request.files.add(await http.MultipartFile.fromPath(key, filePath, filename: filePath.split('/').last));
          }
        }
      }
      for (int i = 1; i <= 3; i++) {
        String key = 'foto_pintu$i';
        String? filePath = data[key];
        if (filePath != null && filePath.isNotEmpty && !filePath.startsWith('http')) {
          File gambar = File(filePath);
          if (gambar.existsSync()) {
            request.files.add(await http.MultipartFile.fromPath(key, filePath, filename: filePath.split('/').last));
            debugPrint("📸 Lampirkan PINTU $key: $filePath");
          }
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint("🟢 RESPONSE BANGUNAN: ${response.statusCode} - ${response.body}");
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
  Future<void> prosesLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<List<dynamic>> fetchPendingSurveySaluran(int diId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/saluran/$diId/'));

      if (response.statusCode == 200) {
        var decoded = json.decode(response.body);
        List<dynamic> allData = decoded['data'] ?? [];
        return allData.where((item) => item['is_approved'] == false).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error: $e");
      return [];
    }
  }
}
