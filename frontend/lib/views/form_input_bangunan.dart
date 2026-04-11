import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class DoorItem {
  TextEditingController namaCtrl;
  String jenis;
  String kondisi;
  TextEditingController lebarCtrl;
  TextEditingController tinggiCtrl;
  String? foto;

  DoorItem(String defaultNama)
      : namaCtrl = TextEditingController(text: defaultNama),
        jenis = 'Sorong',
        kondisi = 'BAIK',
        lebarCtrl = TextEditingController(text: '0'),
        tinggiCtrl = TextEditingController(text: '0'),
        foto = null;
}

class FormBangunanPage extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final int diId;
  final String namaDI;
  final String namaSaluran;
  final double lat;
  final double lng;
  final double jarakDariHulu;
  final List<Map<String, String>> bangunanChoices;
  final List<Map<String, dynamic>> listBangunanHulu;

  const FormBangunanPage({
    super.key,
    this.editData,
    required this.diId,
    required this.namaDI,
    required this.namaSaluran,
    required this.lat,
    required this.lng,
    required this.jarakDariHulu,
    required this.bangunanChoices,
    required this.listBangunanHulu,
  });

  @override
  State<FormBangunanPage> createState() => _FormBangunanPageState();
}

class _FormBangunanPageState extends State<FormBangunanPage> {
  // 1. Controller Identitas & Lokasi
  final TextEditingController _panjangRuasCtrl = TextEditingController(text: "0");
  final TextEditingController _namaAsetCtrl = TextEditingController();
  final TextEditingController _kecamatanCtrl = TextEditingController();
  final TextEditingController _desaCtrl = TextEditingController();
  final TextEditingController _lebarPintuCtrl = TextEditingController(text: "0");
  final TextEditingController _tinggiPintuCtrl = TextEditingController(text: "0");
  
  // 2. Controller Dimensi Saluran Lanjutan
  final TextEditingController _lebarCtrl = TextEditingController(text: "0");
  final TextEditingController _tinggiCtrl = TextEditingController(text: "0");
  
  // 3. Controller Pintu
  final TextEditingController _jenisPintuCtrl = TextEditingController();
  final TextEditingController _pB = TextEditingController(text: "0");
  final TextEditingController _pRR = TextEditingController(text: "0");
  final TextEditingController _pRB = TextEditingController(text: "0");

  // 4. Controller Percabangan (Kiri, Tengah, Kanan)
  final TextEditingController _nomKiriCtrl = TextEditingController();
  final TextEditingController _luasKiriCtrl = TextEditingController(text: "0");
  final TextEditingController _nomTengahCtrl = TextEditingController();
  final TextEditingController _luasTengahCtrl = TextEditingController(text: "0");
  final TextEditingController _nomKananCtrl = TextEditingController();
  final TextEditingController _luasKananCtrl = TextEditingController(text: "0");
  
  final TextEditingController _ketCtrl = TextEditingController();

  double? _lat, _lng;
  String _selKodeAset = 'P01'; 
  String _selectedKondisiAset = 'BAIK';
  
  String? _terhubungKeId;
  bool _isSaluranBerlanjut = true; 
  
  String? _jenisKiri = 'TERSIER';
  String? _jenisTengah = 'INDUK';
  String? _jenisKanan = 'TERSIER';

  // ARRAY FOTO: Dipisah antara foto umum bangunan dan foto khusus pintu
  List<File?> _fotos = List.filled(5, null);
  List<DoorItem> _listPintu = [DoorItem(" - Pintu 1")]; // Inisialisasi 1 pintu pertama
  final List<String> _pilihanJenisPintu = ['Sorong', 'Romyn', 'Tarik', 'Klep', 'Otomatis'];
  
  bool _isLoading = false;

  final List<String> _asetBerpintu = [
    'B01', 'B02', 'B03', 'P01', 'P02', 'P03', 'P04', 'P11', 
    'C16', 'C20', 'C02', 'C03', 'C12', 'C13', 'C08', 'C09', 'C10', 'S13'
  ];
  

  final List<String> _pilihanJenisSaluran = ['INDUK', 'SEKUNDER', 'TERSIER', 'MANUAL'];

  List<Map<String, dynamic>> _huluListLokal = [];

Future<void> _fetchHuluLokal() async {
    final dbClient = await DatabaseService().database;
    // Mengambil semua kolom (*) agar lat dan lng pasti ikut terbawa
    final res = await dbClient.query('surveys', where: 'di_id = ?', whereArgs: [widget.diId]);
    
    setState(() {
      _huluListLokal = res;
    });
    
    // DEBUG: Cek isi list hulu yang ditarik dari SQLite HP
    if (res.isNotEmpty) {
      print("📦 ISI DATA HULU PERTAMA DI HP: ${res.first}");
    }
  }

  @override
  void initState() {
    super.initState();
    _lat = widget.lat;
    _lng = widget.lng;
    
    if (_lat != 0.0 && _lng != 0.0) _getAlamatOtomatis(_lat!, _lng!);

    _namaAsetCtrl.addListener(_autofillNomenklaturCabang);
    
    _fetchHuluLokal();

    if (widget.editData != null) {
      _loadEditData();
    }
  }

  @override
  void dispose() {
    _namaAsetCtrl.removeListener(_autofillNomenklaturCabang);
    super.dispose();
  }

  void _autofillNomenklaturCabang() {
    String baseName = _namaAsetCtrl.text.trim();
    if (baseName.isNotEmpty) {
      if (_nomKiriCtrl.text.isEmpty) _nomKiriCtrl.text = "$baseName Kiri";
      if (_nomTengahCtrl.text.isEmpty) _nomTengahCtrl.text = "$baseName Tengah";
      if (_nomKananCtrl.text.isEmpty) _nomKananCtrl.text = "$baseName Kanan";
    }
  }

  void _loadEditData() {
    final d = widget.editData!;
    _namaAsetCtrl.text = d['nama_bangunan'] ?? "";
    _selKodeAset = d['kode_aset'] ?? "P01";
    _desaCtrl.text = d['desa'] ?? "";
    _kecamatanCtrl.text = d['kecamatan'] ?? "";
    _lebarCtrl.text = d['lebar_saluran']?.toString() ?? "0";
    _tinggiCtrl.text = d['tinggi_saluran']?.toString() ?? "0";
    _pB.text = d['pintu_baik']?.toString() ?? "0";
    _pRR.text = d['pintu_rr']?.toString() ?? "0";
    _pRB.text = d['pintu_rb']?.toString() ?? "0";
    _jenisPintuCtrl.text = d['jenis_pintu'] ?? "";
    _ketCtrl.text = d['keterangan'] ?? "";
    _selectedKondisiAset = d['kondisi_bangunan'] ?? "BAIK";
    
    _terhubungKeId = d['terhubung_ke_id'];
    _isSaluranBerlanjut = d['is_saluran_berlanjut'] == 1 || d['is_saluran_berlanjut'] == true;
    _jenisKiri = d['jenis_saluran_kiri'];
    _nomKiriCtrl.text = d['nomenklatur_kiri'] ?? "";
    _luasKiriCtrl.text = d['luas_kiri']?.toString() ?? "0";
    _jenisTengah = d['jenis_saluran_tengah'];
    _nomTengahCtrl.text = d['nomenklatur_tengah'] ?? "";
    _luasTengahCtrl.text = d['luas_tengah']?.toString() ?? "0";
    _jenisKanan = d['jenis_saluran_kanan'];
    _nomKananCtrl.text = d['nomenklatur_kanan'] ?? "";
    _luasKananCtrl.text = d['luas_kanan']?.toString() ?? "0";

    _lebarPintuCtrl.text = d['lebar_pintu']?.toString() ?? "0";
    _tinggiPintuCtrl.text = d['tinggi_pintu']?.toString() ?? "0";

    // Load foto umum
    for (int i = 1; i <= 5; i++) {
      String? pathFoto = d['foto$i'];
      if (pathFoto != null && pathFoto.isNotEmpty) _fotos[i - 1] = File(pathFoto);
    }
    
    // Load foto pintu
    for (int i = 1; i <= 3; i++) {
      String? pathFotoPintu = d['foto_pintu1'];
    if (pathFotoPintu != null && pathFotoPintu.isNotEmpty) {
      _listPintu[0].foto = pathFotoPintu; // Pakai .foto (tanpa 's') dan langsung ke string
    }
    }
  }

  Future<void> _getAlamatOtomatis(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        setState(() {
          _desaCtrl.text = placemarks[0].subLocality ?? "";
          _kecamatanCtrl.text = placemarks[0].locality ?? "";
        });
      }
    } catch (e) { }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoading = true);
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _lat = pos.latitude; _lng = pos.longitude; _isLoading = false;
      });
      _getAlamatOtomatis(pos.latitude, pos.longitude);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // FUNGSI PICKER FOTO UMUM
  Future<void> _pickImage(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 35);
    if (picked != null) setState(() => _fotos[index] = File(picked.path));
  }

  Future<void> _pickImagePintuList(int doorIndex) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 35);
    if (picked != null) {
      setState(() => _listPintu[doorIndex].foto = picked.path); // Cukup simpan path string-nya ke .foto
    }
  }

  Future<void> _handleSave() async {
    if (_namaAsetCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama Bangunan wajib diisi!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);


    int pB = 0, pRR = 0, pRB = 0;
    String jenisPintuDominan = 'Sorong';
    String lebarPintuUtama = '0';
    String tinggiPintuUtama = '0';
    List<String> kumpulFotoPintu = [];

    for (int i = 0; i < _listPintu.length; i++) {
      var p = _listPintu[i];
      
      if (i == 0) {
        jenisPintuDominan = p.jenis;
        lebarPintuUtama = p.lebarCtrl.text;
        tinggiPintuUtama = p.tinggiCtrl.text;
      }
      
      if (p.kondisi == 'BAIK') pB++;
      else if (p.kondisi == 'RR') pRR++;
      else if (p.kondisi == 'RB') pRB++;

      if (p.foto != null && p.foto!.isNotEmpty) {
        kumpulFotoPintu.add(p.foto!);
      }
    }

    

    // if (_terhubungKeId != null && _terhubungKeId!.isNotEmpty && _lat != null && _lng != null) {
    //   try {
    //     // 1. Cari data hulu di SQLite yang namanya persis sama dengan yang dipilih
    //     var hulu = _huluListLokal.firstWhere(
    //       (b) => (b['nomenklatur_ruas'] ?? b['nama_bangunan']) == _terhubungKeId,
    //     );

    //     double latHulu = double.tryParse(hulu['lat'].toString()) ?? 0.0;
    //     double lngHulu = double.tryParse(hulu['lng'].toString()) ?? 0.0;

    //     debugPrint("📍 Koordinat Hulu: $latHulu, $lngHulu | Titik Skrg: $_lat, $_lng");

    //     // 2. Jika koordinat hulu BUKAN 0.0, barulah hitung!
    //     if (latHulu != 0.0 && lngHulu != 0.0) {
    //       jarakOtomatis = Geolocator.distanceBetween(latHulu, lngHulu, _lat!, _lng!);
    //       debugPrint("✅ BERHASIL DIHITUNG! Jaraknya: $jarakOtomatis meter");
    //     } else {
    //       debugPrint("⚠️ GAGAL HITUNG: Bangunan Hulu ini tidak punya koordinat (0.0) di SQLite!");
    //     }
    //   } catch (e) {
    //     debugPrint("⚠️ GAGAL HITUNG: Nama Hulu '$_terhubungKeId' tidak ditemukan di database HP.");
    //   }
    // }

    // // Fallback: Jika gagal dihitung, ambil dari inputan manual atau tracking
    // if (jarakOtomatis <= 0.0) {
    //   jarakOtomatis = double.tryParse(_panjangRuasCtrl.text) ?? widget.jarakDariHulu;
    // }

    String namaHuluTerpilih = "";
    if (_terhubungKeId != null) {
      var hulu = _huluListLokal.firstWhere((b) => b['id'] == _terhubungKeId, orElse: () => {});
      namaHuluTerpilih = hulu['nomenklatur_ruas'] ?? hulu['nama_bangunan'] ?? "";
    }
    String textJarak = _panjangRuasCtrl.text.replaceAll(',', '.');
    double jarakOtomatis = double.tryParse(textJarak) ?? 0.0;
    
    debugPrint("✅ JARAK FINAL YANG DISIMPAN: $jarakOtomatis meter");

    final prefs = await SharedPreferences.getInstance();
    String namaSurveyor = prefs.getString('username') ?? "Anonim";

    final data = {
      'di_id': widget.diId,
      'nama_di': widget.namaDI,
      'nama_saluran': widget.namaSaluran,
      'nama_bangunan': _namaAsetCtrl.text,
      'kode_aset': _selKodeAset,
      'kondisi_bangunan': _selectedKondisiAset,
      'surveyor': namaSurveyor, 
      
      'lebar_saluran': double.tryParse(_lebarCtrl.text) ?? 0,
      'tinggi_saluran': double.tryParse(_tinggiCtrl.text) ?? 0,
      
      // --- GUNAKAN HASIL REKAPAN PINTU DI SINI ---
      'pintu_baik': pB,
      'pintu_rr': pRR,
      'pintu_rb': pRB,
      'jenis_pintu': jenisPintuDominan,
      'lebar_pintu': double.tryParse(lebarPintuUtama) ?? 0,
      'tinggi_pintu': double.tryParse(tinggiPintuUtama) ?? 0,
      
      'foto_pintu1': kumpulFotoPintu.isNotEmpty ? kumpulFotoPintu[0] : '',
      'foto_pintu2': kumpulFotoPintu.length > 1 ? kumpulFotoPintu[1] : '',
      'foto_pintu3': kumpulFotoPintu.length > 2 ? kumpulFotoPintu[2] : '',
      // -------------------------------------------
      
      'terhubung_ke_id': _terhubungKeId ?? "", 
      'jarak_dari_hulu': jarakOtomatis,
      
      'jenis_saluran_kiri': _jenisKiri ?? "",
      'nomenklatur_kiri': _nomKiriCtrl.text,
      'luas_kiri': double.tryParse(_luasKiriCtrl.text) ?? 0,
      
      'jenis_saluran_tengah': _jenisTengah ?? "",
      'nomenklatur_tengah': _nomTengahCtrl.text,
      'luas_tengah': double.tryParse(_luasTengahCtrl.text) ?? 0,
      
      'jenis_saluran_kanan': _jenisKanan ?? "",
      'nomenklatur_kanan': _nomKananCtrl.text,
      'luas_kanan': double.tryParse(_luasKananCtrl.text) ?? 0,
      

      'desa': _desaCtrl.text,
      'kecamatan': _kecamatanCtrl.text,
      'lat': _lat ?? 0.0,
      'lng': _lng ?? 0.0,
      'keterangan': _ketCtrl.text,
      
      // Foto Umum Bangunan
      'foto1': _fotos[0]?.path ?? '',
      'foto2': _fotos[1]?.path ?? '',
      'foto3': _fotos[2]?.path ?? '',
      'foto4': _fotos[3]?.path ?? '',
      'foto5': _fotos[4]?.path ?? '',
      
      'status_sync': 0, 
    };

    try {
      final db = DatabaseService();
      if (widget.editData == null) {
        await db.insertSurvey(data);
      } else {
        await db.updateSurvey(widget.editData!['id'], data);
      }

      if (!mounted) return;
      Navigator.pop(context, data);
    } catch (e) {
      debugPrint("Gagal Simpan: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      appBar: AppBar(
        title: const Text("Inventarisasi Aset Bangunan", style: TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(color: Colors.blue.shade900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Terikat Pada:", style: TextStyle(fontSize: 11, color: Colors.white70)),
                Text("D.I. ${widget.namaDI}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text("Saluran: ${widget.namaSaluran}", style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  // 1. DATA BANGUNAN & SKEMA HULU
                  _buildExpansionCard(
                    title: "1. Identitas Bangunan",
                    icon: Icons.apartment,
                    initiallyExpanded: true,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _myTextField(_kecamatanCtrl, "Kecamatan")),
                            const SizedBox(width: 10),
                            Expanded(child: _myTextField(_desaCtrl, "Desa")),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Lat: ${_lat?.toStringAsFixed(6) ?? '-'}", style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                  Text("Lng: ${_lng?.toStringAsFixed(6) ?? '-'}", style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _getLocation,
                                icon: const Icon(Icons.gps_fixed, size: 16),
                                label: const Text("Refresh GPS", style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 30),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selKodeAset,
                          decoration: const InputDecoration(labelText: "Jenis Bangunan (Kode Aset)", border: OutlineInputBorder()),
                          items: widget.bangunanChoices.map((b) => DropdownMenuItem(value: b['code'], child: Text(b['name']!))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selKodeAset = v!;
                              if (!_asetBerpintu.contains(_selKodeAset)) {
                                _pB.text = "0"; _pRR.text = "0"; _pRB.text = "0"; _jenisPintuCtrl.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _namaAsetCtrl, 
                          decoration: const InputDecoration(labelText: "Nama Bangunan (Nomenklatur Ruas)", border: OutlineInputBorder()),
                          onChanged: (val) {
                            setState(() {
        
                              _nomKiriCtrl.text = "$val Kiri";
                              _nomTengahCtrl.text = "$val Tengah";
                              _nomKananCtrl.text = "$val Kanan";


                              for (int i = 0; i < _listPintu.length; i++) {
                                _listPintu[i].namaCtrl.text = "$val - Pintu ${i + 1}";
                              }
                            });
                          },
                          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedKondisiAset,
                          decoration: const InputDecoration(labelText: "Kondisi Fisik Bangunan", border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'BAIK', child: Text("Kondisi: BAIK")),
                            DropdownMenuItem(value: 'RR', child: Text("Kondisi: RUSAK RINGAN")),
                            DropdownMenuItem(value: 'RB', child: Text("Kondisi: RUSAK BERAT")),
                          ],
                          onChanged: (v) => setState(() => _selectedKondisiAset = v!),
                        ),
                        const Divider(height: 30),
                        const Align(alignment: Alignment.centerLeft, child: Text("Skema Aliran (Relasi Hulu):", style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: _terhubungKeId,
                          decoration: const InputDecoration(
                            labelText: "Terhubung Ke (Bangunan Hulu)", 
                            hintText: "Pilih bangunan hulu...",
                            border: OutlineInputBorder(), prefixIcon: Icon(Icons.schema)
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text("Titik Awal (Tidak ada Hulu)")),
                            ..._huluListLokal.map((b) {
    
                              String namaHulu = b['nomenklatur_ruas'] ?? b['nama_bangunan'] ?? "Unknown";
                              return DropdownMenuItem<String?>(
                                value: namaHulu, 
                                child: Text(namaHulu, overflow: TextOverflow.ellipsis)
                              );
                            }).toList(),
                          ],
                          onChanged: (v) async {
                            setState(() { _terhubungKeId = v; });
                            
                            if (v != null) {
                              try {
                                print("🚀 Nembak API Server untuk cari koordinat '$v'...");
                                
                                // =======================================================
                                // PERBAIKAN: Nembak ke DI ID, bukan ID Bangunan
                                // =======================================================
                                final response = await http.get(Uri.parse("${ApiService.baseUrl}/api/bangunan/${widget.diId}/"));
                                
                                if (response.statusCode == 200) {
                                  var jsonRes = jsonDecode(response.body);
                                  var listData = jsonRes['data'] as List; 

                                  // Cari bangunan yang namanya persis dengan yang dipilih
                                  var dataFresh = listData.firstWhere(
                                    (b) => (b['nomenklatur_ruas'] ?? b['nama_bangunan']) == v,
                                    orElse: () => null
                                  );

                                  if (dataFresh != null) {
                                    double latH = double.tryParse(dataFresh['latitude'].toString()) ?? 0.0;
                                    double lngH = double.tryParse(dataFresh['longitude'].toString()) ?? 0.0;

                                    print("🎯 KOORDINAT FRESH DARI SERVER: $latH, $lngH");

                                    if (latH != 0.0 && _lat != null && _lat != 0.0) {
                                      double jarak = Geolocator.distanceBetween(latH, lngH, _lat!, _lng!);
                                      
                                      // Jangan lupa pakai setState agar UI kotaknya ikut ter-refresh
                                      setState(() {
                                        _panjangRuasCtrl.text = jarak.toStringAsFixed(2);
                                      });
                                      
                                      print("✅ JARAK SELESAI: ${_panjangRuasCtrl.text} m");
                                    } else {
                                      print("⚠️ Koordinat Hulu 0.0 atau GPS HP belum Lock!");
                                    }
                                  } else {
                                    print("❌ Bangunan '$v' tidak ditemukan di data server.");
                                  }
                                }
                              } catch (e) {
                                print("❌ KONEKSI GAGAL ATAU DATA TIDAK ADA: $e");
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _panjangRuasCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Jarak Otomatis dari Hulu (Meter)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. LOKASI GPS & DOKUMENTASI UMUM
                  _buildExpansionCard(
                    title: "2. Dokumentasi Bangunan",
                    icon: Icons.camera_alt,
                    child: Column(
                      children: [
                        
                        TextField(
                          controller: _ketCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: "Keterangan Tambahan", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 15),
                        const Align(alignment: Alignment.centerLeft, child: Text("Foto Lokasi/Bangunan (Maks 5):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (c, i) => GestureDetector(
                              onTap: () => _pickImage(i), // Memanggil picker foto umum
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: _fotos[i] != null 
                                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_fotos[i]!, fit: BoxFit.cover))
                                    : const Icon(Icons.add_a_photo, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  

                  // 3. PINTU AIR (DYNAMIC LIST)
                    if (_asetBerpintu.contains(_selKodeAset))
                      _buildExpansionCard(
                        title: "3. Kondisi Pintu Air",
                        icon: Icons.settings_input_component,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._listPintu.asMap().entries.map((entry) {
                              int idx = entry.key;
                              DoorItem door = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.blueGrey.shade50
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Pintu ${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                        if (idx > 0)
                                          IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  padding: EdgeInsets.zero, // <--- Ganti jadi padding
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _listPintu.removeAt(idx)),
                                )
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: door.namaCtrl,
                                  decoration: const InputDecoration(labelText: "Nama Pintu", isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(labelText: "Jenis", isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                                        value: door.jenis,
                                        items: _pilihanJenisPintu.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                        onChanged: (v) => setState(() => door.jenis = v!),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(labelText: "Kondisi", isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                                        value: door.kondisi,
                                        items: ['BAIK', 'RR', 'RB'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                        onChanged: (v) => setState(() => door.kondisi = v!),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: TextFormField(controller: door.lebarCtrl, decoration: const InputDecoration(labelText: "Lebar (m)", isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                                    const SizedBox(width: 8),
                                    Expanded(child: TextFormField(controller: door.tinggiCtrl, decoration: const InputDecoration(labelText: "Tinggi (m)", isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text("Dokumentasi Pintu (1 Foto):", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    GestureDetector(
                                    onTap: () => _pickImagePintuList(idx),
                                  child: Container(
                                    width: 60, height: 60, margin: const EdgeInsets.only(top: 5),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueGrey.shade200)),
                                    child: door.foto != null 
                                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(File(door.foto!), fit: BoxFit.cover))
                                      : const Icon(Icons.add_a_photo, color: Colors.blueGrey, size: 20),
                                  ),
              )
                              ],
                            ),
                          );
                        }).toList(),
                        
                        if (_listPintu.length < 5)
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  String baseName = _namaAsetCtrl.text.isEmpty ? "Bangunan" : _namaAsetCtrl.text;
                                  _listPintu.add(DoorItem("$baseName - Pintu ${_listPintu.length + 1}"));
                                });
                              },
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              label: const Text("Tambah Pintu", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          )
                      ],
                    ),
                  ),            

                // 4. KELANJUTAN & PERCABANGAN
                  _buildExpansionCard(
                    title: "4. Data Percabangan & Kelanjutan",
                    icon: Icons.account_tree,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("Saluran Lanjutan Masih Ada?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: const Text("Matikan jika ini adalah bangunan ujung (Tail).", style: TextStyle(fontSize: 11)),
                          value: _isSaluranBerlanjut,
                          activeColor: Colors.blue,
                          onChanged: (bool value) => setState(() => _isSaluranBerlanjut = value),
                        ),
                        if (_isSaluranBerlanjut) ...[
                          const SizedBox(height: 10),
                          const Text("Dimensi Saluran Lanjutan / Tersier:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _myTextField(_lebarCtrl, "Lebar (m)", isNumber: true)),
                              const SizedBox(width: 10),
                              Expanded(child: _myTextField(_tinggiCtrl, "Tinggi (m)", isNumber: true)),
                            ],
                          ),
                        ],
                        const Divider(height: 30),
                        const Text("Detail Areal Percabangan Lahan:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 10),
                        _buildCabangInput("Kiri", _nomKiriCtrl, _luasKiriCtrl, _jenisKiri, (v) => setState(()=> _jenisKiri = v)),
                        _buildCabangInput("Tengah", _nomTengahCtrl, _luasTengahCtrl, _jenisTengah, (v) => setState(()=> _jenisTengah = v)),
                        _buildCabangInput("Kanan", _nomKananCtrl, _luasKananCtrl, _jenisKanan, (v) => setState(()=> _jenisKanan = v)),
                      ],
                    ),
                  ),

                  

                  // TOMBOL SIMPAN
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _handleSave,
                            icon: const Icon(Icons.save),
                            label: const Text("SIMPAN DATA BANGUNAN", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                  const SizedBox(height: 40), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildExpansionCard({required String title, required IconData icon, required Widget child, bool initiallyExpanded = false}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: const Color(0xFF0D47A1),
          collapsedIconColor: Colors.grey,
          leading: Icon(icon, color: const Color(0xFF0D47A1)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D47A1))),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
              child: child,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCabangInput(String arah, TextEditingController nomCtrl, TextEditingController luasCtrl, String? jenisVal, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Arah $arah:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: jenisVal,
            decoration: const InputDecoration(labelText: "Jenis Saluran", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: _pilihanJenisSaluran.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 2, child: _myTextField(nomCtrl, "Nomenklatur Arah $arah")),
              const SizedBox(width: 8),
              Expanded(flex: 1, child: _myTextField(luasCtrl, "Luas (Ha)", isNumber: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _myTextField(TextEditingController ctrl, String label, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }

  Widget _pintuInput(TextEditingController ctrl, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}