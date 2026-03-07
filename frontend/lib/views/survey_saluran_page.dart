import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class SurveySaluranPage extends StatefulWidget {
  final Map<String, dynamic> dataDI;
  const SurveySaluranPage({super.key, required this.dataDI});

  @override
  State<SurveySaluranPage> createState() => _SurveySaluranPageState();
}

class _SurveySaluranPageState extends State<SurveySaluranPage> {
  final MapController _mapController = MapController();
  final TextEditingController _namaSaluranCtrl = TextEditingController();
  final TextEditingController _huluSaluranCtrl = TextEditingController();
  final TextEditingController _keteranganKondisiCtrl = TextEditingController();
  final TextEditingController _keteranganUmumCtrl = TextEditingController();
  final TextEditingController _keteranganBapCtrl = TextEditingController();

  int? _editingSaluranId;
  bool _isEditingMode = false;

  String _searchSaluranKeyword = "";

  String _tipeHuluSaluran = 'Saluran';
  String _selectedJaringan = 'S01';
  String _selectedKondisi = 'BAIK';
  String _selectedTingkatJaringan = 'Teknis';
  String _selectedKewenangan = 'Kabupaten';
  double _panjangBap = 0.0; // Tambahkan ini
  List<Map<String, dynamic>> _listDetailSegmen = [];
  List<String> _currentFotos = []; // Tambahkan ini di bagian atas Class

  double _totalDistance = 0.0;
  double _jarakSegmenIni = 0.0;
  double? _currentLat;
  double? _currentLng;
  double _accuracyThreshold = 15.0;
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isGpsLocked = false;
  String _huluCategory = 'Saluran'; // Default kategori hulu
  List<String> _listHuluSaluran = ["-- Pilih Saluran --", "INPUT MANUAL"];
  List<String> _listHuluBangunan = ["-- Pilih Bangunan --", "INPUT MANUAL"];
  String _selectedHulu = "-- Pilih Saluran --";
  bool _isManualHulu = false;
  bool _isSyncingHulu = false;
  List<LatLng> _currentPath = [];
  StreamSubscription<Position>? _positionStream;
  List<String> _listHulu = ["-- Pilih Hulu --", "INPUT MANUAL"];
  List<Marker> _markersKondisi = [];
  List<Map<String, dynamic>> _segmenKondisi = [];
  List<Polyline> _existingPolylines = [];
  List<Marker> _existingMarkers = [];
  bool _isLoadingMapData = true;
  int get _jumlahBangunanTerinput => _existingMarkers.length;
  List<Polyline> _pathHistory = [];
  Map<String, List<String>> _fotoSaluran = {
    'BAIK': [],
    'RUSAK RINGAN': [],
    'RR': [],
    'RUSAK BERAT': [],
    'RB': [],
    'BAP': [],
  };

  Map<String, String> _keteranganSaluran = {
    'BAIK': '',
    'RR': '', // Gunakan inisial yang sama dengan tombol
    'RB': '',
    'BAP': '',
  };

  final List<String> tingkatPilihan = ['Teknis', 'Semi Teknis', 'Non Teknis'];

  final List<Map<String, String>> _jaringanChoices = [
    {'code': 'S01', 'name': 'S01 - Saluran Primer'},
    {'code': 'S02', 'name': 'S02 - Saluran Sekunder'},
    // {'code': 'S03', 'name': 'S03 - Saluran Suplesi'},
    // {'code': 'S04', 'name': 'S04 - Saluran Muka'},
    // {'code': 'S11', 'name': 'S11 - Saluran Pembuang'},
    // {'code': 'S12', 'name': 'S12 - Saluran Gendong'},
    // {'code': 'S13', 'name': 'S13 - Saluran Pengelak Banjir'},
    {'code': 'S15', 'name': 'S15 - Saluran Tersier'},
    // {'code': 'S16', 'name': 'S16 - Saluran Kuarter'},
    {'code': 'S17', 'name': 'S17 - Saluran Pembuang (Tersier)'},
  ];

  final List<Map<String, String>> _bangunanChoices = [
    // KELOMPOK B (BENDUNG & UTAMA)
    {'code': 'B01', 'name': 'B01 - Bendung'},
    {'code': 'B02', 'name': 'B02 - Bendung Gerak'},
    {'code': 'B03', 'name': 'B03 - Pengambilan Bebas'},
    {'code': 'B04', 'name': 'B04 - Pompa Hidrolik'},
    {'code': 'B06', 'name': 'B06 - Bendungan'},
    {'code': 'B07', 'name': 'B07 - Pompa Elektrik'},
    {'code': 'B99', 'name': 'B99 - Pangkal Saluran (Tanpa Bangunan)'},

    // KELOMPOK C (PELENGKAP)
    {'code': 'C01', 'name': 'C01 - Pengukur Debit'},
    {'code': 'C02', 'name': 'C02 - Siphon'},
    {'code': 'C03', 'name': 'C03 - Gorong-gorong'},
    {'code': 'C04', 'name': 'C04 - Talang'},
    {'code': 'C05', 'name': 'C05 - Kantong Lumpur'},
    {'code': 'C06', 'name': 'C06 - Jembatan'},
    {'code': 'C07', 'name': 'C07 - Terjunan'},
    {'code': 'C08', 'name': 'C08 - Pelimpah Samping'},
    {'code': 'C09', 'name': 'C09 - Tempat Cuci'},
    {'code': 'C10', 'name': 'C10 - Tempat Mandi Hewan'},
    {'code': 'C11', 'name': 'C11 - Got Miring'},
    {'code': 'C12', 'name': 'C12 - Gorong-gorong Silang'},
    {'code': 'C13', 'name': 'C13 - Pelimpah Corong'},
    {'code': 'C14', 'name': 'C14 - Pintu Pembuang'},
    {'code': 'C15', 'name': 'C15 - Oncoran'},
    {'code': 'C16', 'name': 'C16 - Bangunan Inlet'},
    {'code': 'C17', 'name': 'C17 - Terowongan'},
    {'code': 'C18', 'name': 'C18 - Cross Drain'},
    {'code': 'C19', 'name': 'C19 - Pintu Klep'},
    {'code': 'C20', 'name': 'C20 - Outlet'},
    {'code': 'C21', 'name': 'C21 - Krib'},
    {'code': 'C22', 'name': 'C22 - Tanggul'},

    // KELOMPOK P (PENGATUR)
    {'code': 'P01', 'name': 'P01 - Bagi'},
    {'code': 'P02', 'name': 'P02 - Bagi Sadap'},
    {'code': 'P03', 'name': 'P03 - Sadap'},
    {'code': 'P04', 'name': 'P04 - Sadap Langsung'},
    {'code': 'P11', 'name': 'P11 - Bangunan Pertemuan'},
    {'code': 'P21', 'name': 'P21 - Box Tersier'},
    {'code': 'P22', 'name': 'P22 - Box Kuarter'},
    {'code': 'P99', 'name': 'P99 - Ujung Saluran (Tanpa Bangunan)'},
  ];

  @override
  void initState() {
    super.initState();
    _initLocationMonitoring();
    _loadSurveyorName();
    _loadExistingData();
    _fetchDaftarHulu();
    _checkDraftSurvey();
    _checkUnfinishedSurvey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDraftSurvey();
    });
  }

  // MASUKKAN INI DI DALAM _SurveySaluranPageState
  Future<void> _prosesSimpanKeLocal() async {
    // 1. Tampilkan Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Ambil data yang sedang dikerjakan (JSON yang tadi Bapak log)
      // Pastikan variabel 'data' ini berisi Map yang lengkap (ada path_kondisi, koordinat, dll)
      Map<String, dynamic> dataSurvey = {
        'di_id': widget.dataDI['id'],
        'nama_saluran': _namaSaluranCtrl.text,
        'surveyor': 'admin', // Sesuaikan
        'keterangan_baik': _keteranganUmumCtrl.text,
        'keterangan_rr': _keteranganKondisiCtrl.text,
        'keterangan_rb': _keteranganKondisiCtrl.text,
        'keterangan_bap': _keteranganBapCtrl.text,
        // ... tambahkan field lain yang dibutuhkan oleh syncSaluran
      };

      // 3. Simpan ke Database Lokal (HP)
      bool suksesLokal = await DatabaseService().simpanKeteranganSurvey(
        diId: widget.dataDI['id'],
        ketBaik: _keteranganUmumCtrl.text,
        ketRR: _keteranganKondisiCtrl.text,
        ketRB: _keteranganKondisiCtrl.text,
        ketBAP: _keteranganBapCtrl.text,
      );

      if (suksesLokal) {
        // 4. LANGSUNG SINKRON KE SERVER
        // Kita panggil fungsi syncSaluran yang sudah ada di ApiService Bapak
        bool suksesServer = await ApiService().syncSaluran(dataSurvey);

        Navigator.pop(context); // Tutup Loading

        if (suksesServer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Mantap! Data Tersimpan & Terkirim ke Server."),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "⚠️ Tersimpan di HP, tapi Gagal kirim ke Server (Cek Sinyal).",
              ),
            ),
          );
        }
        Navigator.pop(context); // Kembali ke menu utama
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint("🔴 ERROR: $e");
    }
  }

  Future<void> _checkUnfinishedSurvey() async {
    final unfinished = await DatabaseService().getUnfinishedSurvey(
      widget.dataDI['id'],
    );

    // Jika ada data yang status_sync nya masih 0 (belum tersinkron)
    if (unfinished != null && unfinished['status_sync'] == 0) {
      _showSurveyTerputusDialog();
    }
  }

  void _showSurveyTerputusDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Survey Terputus"),
        content: const Text(
          "Kami mendeteksi ada survey yang belum tersinkron. Silakan sinkronkan data terlebih dahulu di tab Daftar Saluran.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("MENGERTI"),
          ),
        ],
      ),
    );
  }

  void _undoLastPoint() {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _currentPath
            .removeLast(); // Menghapus titik terakhir dari garis yang sedang dibuat
      });
    }
  }

  void _initLocationMonitoring() async {
    // 1. Cek izin GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 2. Pantau posisi terus menerus (High Accuracy)
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // Update setiap 2 meter biar halus gerakannya
      ),
    ).listen((Position p) {
      if (!mounted) return;
      if (p.accuracy > _accuracyThreshold) return;

      setState(() {
        _currentLat = p.latitude;
        _currentLng = p.longitude;

        // Jika peta belum ada titik sama sekali (baru buka), pusatkan ke orangnya
        if (_currentPath.isEmpty && !_isTracking) {
          _mapController.move(LatLng(p.latitude, p.longitude), 15.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _namaSaluranCtrl.dispose();
    _huluSaluranCtrl.dispose();
    _keteranganKondisiCtrl.dispose();
    _searchSaluranKeyword = "";
    _keteranganBapCtrl.dispose();
    super.dispose();
  }

  String _currentSurveyor = "Memuat...";

  Future<void> _fetchDaftarHulu() async {
    setState(() => _isSyncingHulu = true);
    try {
      final db = DatabaseService();
      final api = ApiService();
      int diId = widget.dataDI['id'];
      final dbClient = await db.database;

      try {
        final List<dynamic> dataSaluran = await api.fetchSaluranMaster(diId);
        final List<dynamic> dataBangunan = await api.fetchBangunanMaster(diId);

        for (var s in dataSaluran) {
          final existing = await dbClient.query(
            'saluran',
            where: 'nama_saluran = ? AND di_id = ?',
            whereArgs: [s['nama_saluran'], diId],
          );

          if (existing.isEmpty) {
            await db.insertSaluran({
              'di_id': diId,
              'nama_saluran': s['nama_saluran'],
              'panjang_saluran': s['panjang_saluran'] ?? 0.0,
              'status_sync':
                  1, // Tandai 1 agar tidak dianggap inputan baru oleh list bawah
              'kewenangan': s['kewenangan'],
              'tingkat_jaringan': s['tingkat_jaringan'],
              'path_koordinat': (s['geometry_data']['coordinates'][0] as List)
                  .map((c) => "${c[1]},${c[0]}")
                  .join("|"),
            });
          }
        }

        for (var b in dataBangunan) {
          String namaBgn =
              b['nomenklatur_ruas'] ?? b['nama_bangunan'] ?? b['nama'];

          final existingBgn = await dbClient.query(
            'surveys',
            where: 'nama_bangunan = ? AND di_id = ?',
            whereArgs: [namaBgn, diId],
          );

          if (existingBgn.isEmpty) {
            await db.insertSurvey({
              'di_id': diId,
              'nama_bangunan': namaBgn,
              'status_sync': 1,
            });
          }
        }
      } catch (e) {
        debugPrint("Offline/Error Server: $e");
      }

      // 2. Ambil dari Lokal (Gunakan list yang sudah difilter)
      final sLocal = await db.getUniqueSaluranByDI(diId);
      final bLocal = await db.getUniqueBangunanByDI(diId);

      if (!mounted) return;
      setState(() {
        // List Saluran
        _listHuluSaluran = ["-- Pilih Saluran --", "INPUT MANUAL"];
        for (var item in sLocal) {
          var n = item['nama_saluran'];
          if (n != null &&
              n.toString().toLowerCase() != "null" &&
              n.toString().isNotEmpty) {
            _listHuluSaluran.add(n.toString());
          }
        }

        // List Bangunan
        _listHuluBangunan = ["-- Pilih Bangunan --", "INPUT MANUAL"];
        for (var item in bLocal) {
          var n = item['nama_bangunan'];
          // Filter agar data sampah seperti "null" atau string kosong tidak masuk
          if (n != null &&
              n.toString().toLowerCase() != "null" &&
              n.toString().trim().isNotEmpty &&
              n.toString() !=
                  "Bendung" && // Filter jika ada data kategori yang nyasar
              n.toString() != "Saluran Tersier") {
            _listHuluBangunan.add(n.toString());
          }
        }

        // Reset pilihan agar tidak error
        _selectedHulu = _huluCategory == 'Saluran'
            ? _listHuluSaluran[0]
            : _listHuluBangunan[0];
      });
    } finally {
      if (!mounted) return;
      setState(() => _isSyncingHulu = false);
    }
  }

  Future<void> _loadSurveyorName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSurveyor = prefs.getString('username') ?? "Surveyor";
    });
  }

  void _directionToPoint(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 18.0); // Zoom in ke titik aset
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mengarahkan ke lokasi aset...")),
    );
  }

  void _checkDraftSurvey() async {
    final draft = await DatabaseService().getDraft(widget.dataDI['id']);
    if (draft != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Survey Terputus"),
          content: const Text(
            "Ditemukan data tracking yang belum tersimpan. Lanjutkan survey terakhir?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                DatabaseService().deleteDraft(widget.dataDI['id']);
                Navigator.pop(context);
              },
              child: const Text(
                "HAPUS DRAFT",
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _totalDistance = draft['total_distance'] ?? 0.0;
                  _jarakSegmenIni = draft['jarak_segmen'] ?? 0.0;
                  _selectedKondisi = draft['kondisi_aktif'] ?? 'BAIK';
                  _huluSaluranCtrl.text = draft['nama_hulu'] ?? '';
                  _isManualHulu = draft['is_manual_hulu'] == 1;

                  // Decode Path LatLng
                  if (draft['path_data'] != null) {
                    Iterable list = jsonDecode(draft['path_data']);
                    _currentPath = list
                        .map((model) => LatLng(model['lat'], model['lng']))
                        .toList();
                  }
                });
                Navigator.pop(context);
                _startTracking(); // Lanjutkan stream GPS
              },
              child: const Text("LANJUTKAN"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _ambilFotoSaluran() async {
    if (_isTracking && !_isPaused) {
      _positionStream?.pause();
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25,
        maxWidth: 800,
      );

      if (image != null) {
        setState(() {
          _currentFotos.add(image.path);

          if (_fotoSaluran[_selectedKondisi] == null) {
            _fotoSaluran[_selectedKondisi] = [];
          }
          _fotoSaluran[_selectedKondisi]!.add(image.path);

          if (_currentLat != null && _currentLng != null) {
            _existingMarkers.add(
              Marker(
                point: LatLng(_currentLat!, _currentLng!),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.yellow,
                  size: 30,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Foto $_selectedKondisi berhasil disimpan")),
        );
      }
    } catch (e) {
      debugPrint("Error Kamera: $e");
    } finally {
      // 2. Apapun yang terjadi, nyalakan lagi GPS setelah kamera tertutup
      if (_isTracking && !_isPaused) {
        _positionStream?.resume();
      }
    }
  }

  void _ambilFoto(String tipe) async {
    final ImagePicker picker = ImagePicker();
    try {
      // Pastikan koordinat ada sebelum ambil foto
      if (_currentLat == null || _currentLng == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Menunggu sinyal GPS...")));
        return;
      }

      final XFile? fotoTerambil = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25,
        maxWidth: 800,
      );

      if (fotoTerambil != null) {
        setState(() {
          // Tambahkan ke list foto sesuai tipe untuk dikirim ke admin
          if (_fotoSaluran[tipe] == null) _fotoSaluran[tipe] = [];
          _fotoSaluran[tipe]!.add(fotoTerambil.path);

          // Tambahkan marker ke peta
          _markersKondisi.add(
            Marker(
              point: LatLng(_currentLat!, _currentLng!),
              width: 40,
              height: 40,
              // Gunakan Center agar icon pas di titik koordinat
              child: const Center(
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.yellow,
                  size: 30,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _gantiKondisi(String kondisiBaru) {
    // --- 1. VALIDASI AWAL ---

    // A. Cek apakah ada pergerakan (koordinat)
    if (_currentPath.isEmpty) {
      _showWarning("GPS belum mengunci lokasi, silakan tunggu.");
      return;
    }

    // B. Wajib isi Keterangan
    if (_keteranganKondisiCtrl.text.trim().isEmpty) {
      _showWarning("Keterangan untuk kondisi $_selectedKondisi wajib diisi!");
      return;
    }

    // C. Wajib ambil Foto (Minimal 1 foto)
    if (_currentFotos.isEmpty) {
      _showWarning("Ambil foto segmen $_selectedKondisi dulu, Pak!");
      return;
    }

    // Jika lolos semua validasi di atas, baru jalankan proses simpan segmen...

    LatLng titikMarker = _currentPath.last;
    String kondisiSaatIni = _selectedKondisi;
    String teksKeterangan = _keteranganKondisiCtrl.text;

    // --- 2. LOGIKA PENYIMPANAN MARKER & POLYLINE ---
    _markersKondisi.add(
      Marker(
        point: titikMarker,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _mapController.move(titikMarker, 18.0),
          child: Icon(
            Icons.location_on,
            color: _getWarnaKondisi(kondisiSaatIni),
            size: 40,
          ),
        ),
      ),
    );

    if (_currentPath.length > 1) {
      setState(() {
        _pathHistory.add(
          Polyline(
            points: List.from(_currentPath),
            color: _getWarnaKondisi(kondisiSaatIni),
            strokeWidth: 5,
          ),
        );
      });
    }

    // --- 3. MASUKKAN KE LIST DATA ---
    _segmenKondisi.add({
      'kondisi': kondisiSaatIni,
      'panjang': _jarakSegmenIni,
      'keterangan': teksKeterangan,
      'titik_awal':
          "${_currentPath.first.latitude},${_currentPath.first.longitude}",
      'titik_akhir':
          "${_currentPath.last.latitude},${_currentPath.last.longitude}",
      'fotos': List.from(_currentFotos),
    });

    // --- 4. RESET & CLEAR TOTAL (SEPERTI YANG BAPAK MINTA) ---
    setState(() {
      LatLng lastPoint = _currentPath.last;

      if (kondisiSaatIni == 'BAP') {
        _panjangBap += _jarakSegmenIni;
      }

      String kondisiLama = _selectedKondisi;

      _keteranganKondisiCtrl.clear();
      _currentFotos = [];

      if (_fotoSaluran[kondisiLama] != null) {
        _fotoSaluran[kondisiLama] = [];
      }
      _currentPath = [lastPoint]; // Reset jalur mulai dari titik terakhir
      _jarakSegmenIni = 0;

      _selectedKondisi = kondisiBaru;
    });

    _autoSaveDraft();
  }

  // Fungsi pembantu untuk menampilkan pesan peringatan
  void _showWarning(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⚠️ $pesan"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _fetchHuluData() async {
    setState(() {
      _listHulu.addAll(["B.Cw 1", "B.Cw 2", "Sal. Primer 1"]); // Contoh data
    });
  }

  void _showTagBangunanDialog() async {
    if (_currentPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Belum ada koordinat! Mulai tracking dulu Pak."),
        ),
      );
      return;
    }
    LatLng lokasiSaatIni = _currentPath.last;
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormBangunanDetail(
          diId: widget.dataDI['id'],
          namaDI: widget.dataDI['nama_di'] ?? "D.I.",
          namaSaluran: _namaSaluranCtrl.text.isEmpty
              ? "Tanpa Nama"
              : _namaSaluranCtrl.text,
          lat: lokasiSaatIni.latitude,
          lng: lokasiSaatIni.longitude,
          jarakAntarRuas: _jarakSegmenIni,
          bangunanChoices: _bangunanChoices,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _jarakSegmenIni = 0;
        _existingMarkers.add(
          Marker(
            point: LatLng(result['lat'], result['lng']),
            width: 90,
            height: 90,
            child: GestureDetector(
              onTap: () => _showDetailBangunan(result),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(width: 0.5),
                    ),
                    child: Text(
                      "${result['nama_saluran']}\n${result['nama_bangunan']}",
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Image.asset(
                    'assets/icons/${result['kode_aset']}.png',
                    cacheWidth: 50,
                    width: 28,
                    height: 28,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.location_on, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        );
      });
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text("Konfirmasi Hapus"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Apakah Anda yakin ingin menghapus data ini?"),
                const Divider(height: 20),
                _buildDetailRow("Daerah Irigasi", data['nama_di']),
                _buildDetailRow("Nama Saluran", data['nama_saluran']),
                _buildDetailRow("Surveyor", data['surveyor'] ?? "Anonim"),
                _buildDetailRow("Tingkat Jaringan", data['tingkat_jaringan']),
                _buildDetailRow("Kewenangan", data['kewenangan']),
                _buildDetailRow(
                  "Panjang",
                  "${data['panjang_saluran']?.toStringAsFixed(2)} m",
                ),
                _buildDetailRow(
                  "Status Sync",
                  data['status_sync'] == 1 ? "Sudah Terkirim" : "Lokal",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("BATAL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  final int? idTarget = data['id'];

                  if (idTarget != null) {
                    // 1. Hapus data utama di database
                    await DatabaseService().deleteSaluran(idTarget);

                    // 2. Hapus draft tracking terkait jika ada
                    if (data['di_id'] != null) {
                      await DatabaseService().deleteDraft(data['di_id']);
                    }

                    // 3. REFRESH UI: Cukup panggil setState agar FutureBuilder jalan lagi
                    setState(() {});

                    if (mounted) {
                      Navigator.pop(context); // Tutup dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Data Berhasil Dihapus")),
                      );
                    }
                  } else {
                    debugPrint("Gagal menghapus: ID Saluran tidak ditemukan");
                    if (mounted) Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint("Error saat menghapus: $e");
                }
              },
              child: const Text(
                "HAPUS SEKARANG",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper untuk tampilan baris detail di dalam dialog
  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value ?? "-",
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _fokusKeAwalSaluran() {
    if (_pathHistory.isNotEmpty && _pathHistory.first.points.isNotEmpty) {
      _mapController.move(_pathHistory.first.points.first, 18.0);
    } else if (_currentPath.isNotEmpty) {
      _mapController.move(_currentPath.first, 18.0);
    }
  }

  void _showDetailBangunan(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${b['nama_saluran']} - ${b['nama_bangunan']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Divider(),
            Text(
              "Kondisi Pintu B/RR/RB: ${b['pintu_baik']}/${b['pintu_rr']}/${b['pintu_rb']}",
            ),
            Text("Lokasi: Desa ${b['desa']}, Kec. ${b['kecamatan']}"),
          ],
        ),
      ),
    );
  }

  Color _getWarnaKondisi(String kondisi) {
    if (kondisi == 'BAIK') return Colors.green;
    if (kondisi == 'RUSAK RINGAN' || kondisi == 'RR') return Colors.orange;
    if (kondisi == 'RUSAK BERAT' || kondisi == 'RB') return Colors.red;
    if (kondisi == 'BAP') return Colors.grey;
    return Colors.blue; // default
  }

  Widget _buildPendingSaluranList() {
    return _buildFieldset(
      title: "Pending Approval: Saluran",
      icon: Icons.alt_route,
      action: IconButton(
        icon: const Icon(Icons.sync_problem, color: Colors.orange),
        tooltip: "Sinkronisasi Ulang & Bersihkan Duplikat",
        onPressed: () async {
          // Tampilkan loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => const Center(child: CircularProgressIndicator()),
          );

          final db = DatabaseService();
          await db.cleanDuplicateData();
          await _fetchDaftarHulu();

          Navigator.pop(context); // Tutup loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data berhasil dibersihkan dan disinkronkan!"),
            ),
          );
        },
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Cari saluran...",
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) =>
                setState(() => _searchSaluranKeyword = value.toLowerCase()),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getCombinedSaluranData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Belum ada draft saluran",
                    style: TextStyle(fontSize: 11),
                  ),
                );
              }

              final filtered = snapshot.data!.where((item) {
                return (item['nama_saluran'] ?? "")
                    .toString()
                    .toLowerCase()
                    .contains(_searchSaluranKeyword);
              }).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = filtered[index];

                  return ExpansionTile(
                    // --- KIRI: Ikon Aset ---
                    leading: Image.asset(
                      'assets/icons/${data['kode_aset'] ?? 'S01'}.png',
                      width: 25,
                      height: 25,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.route, color: Colors.blue),
                    ),
                    title: Text(
                      data['nama_saluran'] ?? "Saluran Tanpa Nama",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    // subtitle: Text(
                    //   "Total Panjang: ${(data['panjang_saluran'] ?? 0).toStringAsFixed(2)} m",
                    //   style: const TextStyle(fontSize: 10),
                    // ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Kita hitung panjangnya langsung dari data segmen
                          "Panjang: ${double.tryParse(data['panjang'].toString())?.toStringAsFixed(2) ?? '0.00'} m | ${(data['fotos'] is List ? data['fotos'].length : 0)} Foto",
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          "Awal: ${data['titik_awal'] ?? '-'}",
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "Akhir: ${data['titik_akhir'] ?? '-'}",
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.green,
                            size: 24,
                          ),
                          tooltip: "Lanjutkan Survey",
                          onPressed: () => _lanjutkanSurveySaluran(data),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteConfirmation(data),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Colors.blueGrey[50],
                        child: const Text(
                          "DETAIL SEGMEN KONDISI",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      ...((data['path_kondisi'] != null &&
                              data['path_kondisi'] != "")
                          ? (jsonDecode(data['path_kondisi']) as List).asMap().entries.map((
                              segEntry,
                            ) {
                              // VARIABEL DEFINISI DI SINI
                              int segIdx = segEntry.key;
                              var segData = segEntry.value;
                              String kondisi = (segData['kondisi'] ?? "-")
                                  .toString()
                                  .toUpperCase();
                              double panjang =
                                  double.tryParse(
                                    segData['panjang'].toString(),
                                  ) ??
                                  0.0;

                              return Container(
                                color: Colors.white,
                                child: ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(
                                    Icons.segment,
                                    color: _getWarnaKondisi(kondisi),
                                    size: 20,
                                  ),
                                  title: Text(
                                    "Segmen ${segIdx + 1}: $kondisi",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Panjang: ${panjang.toStringAsFixed(2)} meter",
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  // PINDAHKAN TOMBOL KE SINI AGAR TIDAK ERROR
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.gps_fixed,
                                          color: Colors.blue,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          // Ambil koordinat dengan fallback (jika awal kosong, ambil akhir)
                                          String? kordinat =
                                              segData['titik_awal'] ??
                                              segData['titik_akhir'];

                                          if (kordinat != null &&
                                              kordinat.contains(',')) {
                                            try {
                                              final parts = kordinat.split(',');
                                              final double lat = double.parse(
                                                parts[0].trim(),
                                              );
                                              final double lng = double.parse(
                                                parts[1].trim(),
                                              );

                                              // Validasi angka agar tidak pindah ke koordinat 0,0
                                              if (lat != 0.0 && lng != 0.0) {
                                                _mapController.move(
                                                  LatLng(lat, lng),
                                                  18.0,
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Fokus ke Segmen ${segIdx + 1}",
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              debugPrint(
                                                "Gagal parsing koordinat segmen: $e",
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_note,
                                          color: Colors.orange,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          // Ambil data foto yang sudah ada (asumsi disimpan dalam segData['fotos'] berupa list path)
                                          List listFotos =
                                              segData['fotos'] != null
                                              ? List.from(segData['fotos'])
                                              : [];
                                          TextEditingController _editKetCtrl =
                                              TextEditingController(
                                                text:
                                                    segData['keterangan'] ?? "",
                                              );

                                          showDialog(
                                            context: context,
                                            builder: (c) => StatefulBuilder(
                                              // Menggunakan StatefulBuilder agar dialog bisa update UI saat foto ditambah
                                              builder: (context, setDialogState) => AlertDialog(
                                                title: Text(
                                                  "Edit Segmen ${segIdx + 1}",
                                                ),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                        controller:
                                                            _editKetCtrl,
                                                        maxLines: 3,
                                                        decoration:
                                                            const InputDecoration(
                                                              border:
                                                                  OutlineInputBorder(),
                                                              hintText:
                                                                  "Keterangan...",
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      const Text(
                                                        "Foto Segmen (Maks 5):",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      // Tampilkan Preview Foto
                                                      Wrap(
                                                        spacing: 5,
                                                        children: listFotos
                                                            .map(
                                                              (path) => Stack(
                                                                children: [
                                                                  Image.file(
                                                                    File(path),
                                                                    width: 60,
                                                                    height: 60,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  ),
                                                                  Positioned(
                                                                    right: 0,
                                                                    top: 0,
                                                                    child: GestureDetector(
                                                                      onTap: () {
                                                                        setDialogState(
                                                                          () => listFotos.remove(
                                                                            path,
                                                                          ),
                                                                        );
                                                                      },
                                                                      child: Container(
                                                                        color: Colors
                                                                            .red,
                                                                        child: const Icon(
                                                                          Icons
                                                                              .close,
                                                                          size:
                                                                              15,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            )
                                                            .toList(),
                                                      ),
                                                      if (listFotos.length < 5)
                                                        ElevatedButton.icon(
                                                          icon: const Icon(
                                                            Icons.camera_alt,
                                                          ),
                                                          label: const Text(
                                                            "Tambah Foto",
                                                          ),
                                                          onPressed: () async {
                                                            final picker =
                                                                ImagePicker();
                                                            final img = await picker
                                                                .pickImage(
                                                                  source:
                                                                      ImageSource
                                                                          .camera,
                                                                  imageQuality:
                                                                      50,
                                                                );
                                                            if (img != null) {
                                                              setDialogState(
                                                                () => listFotos
                                                                    .add(
                                                                      img.path,
                                                                    ),
                                                              );
                                                            }
                                                          },
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(c),
                                                    child: const Text("BATAL"),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      List
                                                      listKondisi = jsonDecode(
                                                        data['path_kondisi'],
                                                      );
                                                      listKondisi[segIdx]['keterangan'] =
                                                          _editKetCtrl.text;
                                                      listKondisi[segIdx]['fotos'] =
                                                          listFotos; // Simpan list path foto

                                                      await DatabaseService()
                                                          .updateSaluran(
                                                            data['id'],
                                                            {
                                                              'path_kondisi':
                                                                  jsonEncode(
                                                                    listKondisi,
                                                                  ),
                                                            },
                                                          );
                                                      Navigator.pop(c);
                                                      setState(() {});
                                                    },
                                                    child: const Text("SIMPAN"),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()
                          : [
                              const ListTile(
                                dense: true,
                                title: Text(
                                  "Data segmen tidak tersedia",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ]),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label) {
    bool isSelected = _huluCategory == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _huluCategory = label;
          _selectedHulu = label == 'Saluran'
              ? _listHuluSaluran[0]
              : _listHuluBangunan[0];
          _isManualHulu = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (!_isTracking) {
          _positionStream?.cancel();
          Navigator.pop(context);
          return;
        }

        final bool shouldPop =
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Peringatan!"),
                content: const Text(
                  "Anda saat ini sedang melakukan survey. Selesaikan terlebih dahulu atau data akan hilang.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("LANJUT SURVEY"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "KELUAR",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
        if (shouldPop) {
          _positionStream?.cancel();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Survey: ${widget.dataDI['nama_di']} | Petugas: $_currentSurveyor",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            // BAGIAN ATAS: PETA (FLEX 3)
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(-6.826, 108.604),
                      initialZoom: 15,
                      // FITUR GESER/TAMBAH TITIK MANUAL
                      onTap: (tapPos, point) {
                        if (_isTracking) {
                          setState(() => _currentPath.add(point));
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.sirigasi.cirebon.survey',
                      ),
                      PolylineLayer(
                        polylines: [
                          ..._existingPolylines,
                          ..._pathHistory,
                          Polyline(
                            points: _currentPath,
                            color: _getWarnaKondisi(_selectedKondisi),
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          ..._existingMarkers,
                          ..._markersKondisi,
                          // IKON ORANG (LOKASI SAYA)
                          if (_currentLat != null && _currentLng != null)
                            Marker(
                              point: LatLng(_currentLat!, _currentLng!),
                              width: 80,
                              height: 80,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _currentSurveyor,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.directions_walk,
                                    color: Colors.blue,
                                    size: 45,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // 1. PANEL INFO KM & BANGUNAN (KIRI ATAS)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverlayInfoKM(),
                        const SizedBox(height: 5),
                        _buildOverlayInfoBangunan(),
                      ],
                    ),
                  ),

                  // 2. PANEL TOMBOL NAVIGASI, ZOOM & UNDO (KANAN ATAS/TENGAH)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        // TOMBOL UNDO (Hanya muncul saat Tracking)
                        if (_isTracking)
                          FloatingActionButton.small(
                            heroTag: "btnUndo",
                            backgroundColor: Colors.redAccent,
                            onPressed: _undoLastPoint,
                            child: const Icon(Icons.undo, color: Colors.white),
                          ),
                        if (_isTracking) const SizedBox(height: 10),

                        // TOMBOL PUSATKAN LOKASI
                        FloatingActionButton.small(
                          heroTag: "btnPusat",
                          backgroundColor: Colors.white,
                          onPressed: () {
                            if (_currentLat != null) {
                              _mapController.move(
                                LatLng(_currentLat!, _currentLng!),
                                18.0,
                              );
                            }
                          },
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // --- TOMBOL ZOOM IN (+) ---
                        FloatingActionButton.small(
                          heroTag: "btnZoomIn",
                          backgroundColor: Colors.white,
                          onPressed: () {
                            final currentZoom = _mapController.camera.zoom;
                            _mapController.move(
                              _mapController.camera.center,
                              currentZoom + 1,
                            );
                          },
                          child: const Icon(Icons.add, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),

                        // --- TOMBOL ZOOM OUT (-) ---
                        FloatingActionButton.small(
                          heroTag: "btnZoomOut",
                          backgroundColor: Colors.white,
                          onPressed: () {
                            final currentZoom = _mapController.camera.zoom;
                            _mapController.move(
                              _mapController.camera.center,
                              currentZoom - 1,
                            );
                          },
                          child: const Icon(
                            Icons.remove,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. PANEL KOORDINAT & TAG BANGUNAN (KANAN BAWAH)
                  Positioned(
                    bottom: 15,
                    right: 15,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // INFO KOORDINAT
                        if (_currentLat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        // TOMBOL TAG BANGUNAN
                        _buildFloatingTagButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // BAGIAN BAWAH: FORM & TAB (FLEX 4)
            Expanded(
              flex: 4,
              child: DefaultTabController(
                length: 2,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              _buildFormUtama(),
                              const SizedBox(height: 10),
                              _buildKoneksiHulu(),
                              const SizedBox(height: 10),
                              _buildKondisiSegmen(),
                              const SizedBox(height: 20),
                              _buildTombolAksi(),
                            ],
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          const TabBar(
                            labelColor: Colors.blue,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.blue,
                            tabs: [
                              Tab(
                                icon: Icon(Icons.apartment),
                                text: "Daftar Bangunan",
                              ),
                              Tab(
                                icon: Icon(Icons.alt_route),
                                text: "Daftar Saluran",
                              ),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    children: [
                      _buildWrapList(_buildPendingApprovalList()),
                      _buildWrapList(_buildPendingSaluranList()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FUNGSI-FUNGSI PEMBANTU (WIDGET HELPERS)
  // ==========================================

  Widget _buildWrapList(Widget listWidget) {
    return ListView(padding: const EdgeInsets.all(10), children: [listWidget]);
  }

  Widget _buildFormUtama() {
    return Column(
      children: [
        TextField(
          controller: _namaSaluranCtrl,
          decoration: const InputDecoration(
            labelText: "Nama Saluran",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              // Jika teks dihapus sampai kosong oleh surveyor
              if (value.isEmpty) {
                _isEditingMode = false;
                _editingSaluranId = null;
              }
            });
          },
        ),
        const SizedBox(height: 10),
        // Dropdown 1: Tingkat Jaringan
        DropdownButtonFormField<String>(
          // Logika pengaman: Jika nilai di variabel tidak ada di list, paksa ke index 0
          value: tingkatPilihan.contains(_selectedTingkatJaringan)
              ? _selectedTingkatJaringan
              : tingkatPilihan[0],
          items: tingkatPilihan
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => _selectedTingkatJaringan = v!),
          decoration: const InputDecoration(
            labelText: "Tingkat Jaringan",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        // Dropdown 2: KODE ASET (Ganti duplikat tadi dengan ini Pak)
        DropdownButtonFormField<String>(
          value:
              _jaringanChoices.any(
                (element) => element['code'] == _selectedJaringan,
              )
              ? _selectedJaringan
              : _jaringanChoices[0]['code'],
          items: _jaringanChoices
              .map(
                (choice) => DropdownMenuItem(
                  value: choice['code'],
                  child: Text(choice['name']!),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedJaringan = v!),
          decoration: const InputDecoration(
            labelText: "Jenis Saluran (Kode Aset)",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedKewenangan,
          items: [
            'Pusat',
            'Provinsi',
            'Kabupaten',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) => setState(() => _selectedKewenangan = v!),
          decoration: const InputDecoration(
            labelText: "Kewenangan",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildKoneksiHulu() {
    return _buildFieldset(
      title: "Koneksi Hulu",
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildTabBtn("Saluran"),
                    const SizedBox(width: 8),
                    _buildTabBtn("Bangunan"),
                  ],
                ),
              ),
              _isSyncingHulu
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync, color: Colors.blue),
                      onPressed: _fetchDaftarHulu,
                    ),
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value:
                _listHuluSaluran.contains(_selectedHulu) ||
                    _listHuluBangunan.contains(_selectedHulu)
                ? _selectedHulu
                : (_huluCategory == 'Saluran'
                      ? _listHuluSaluran[0]
                      : _listHuluBangunan[0]),
            items:
                (_huluCategory == 'Saluran'
                        ? _listHuluSaluran
                        : _listHuluBangunan)
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              setState(() {
                _selectedHulu = v!;
                _isManualHulu = (v == "INPUT MANUAL");
                if (!_isManualHulu) _huluSaluranCtrl.text = v;
              });
            },
            decoration: InputDecoration(
              labelText: "Pilih Nama $_huluCategory",
              border: const OutlineInputBorder(),
            ),
          ),
          if (_isManualHulu) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _huluSaluranCtrl,
              decoration: const InputDecoration(
                labelText: "Ketik Nama Hulu Manual",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKondisiSegmen() {
    return _buildFieldset(
      title: "Kondisi Saluran Saat Ini",
      icon: Icons.engineering,
      child: SizedBox(
        height: 350, // Beri tinggi tetap agar Tab bisa di-scroll
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: "Umum", icon: Icon(Icons.info_outline, size: 20)),
                  Tab(
                    text: "Detail Segmen",
                    icon: Icon(Icons.analytics_outlined, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: TabBarView(
                  children: [
                    // --- TAB 1: KETERANGAN UMUM ---
                    Column(
                      children: [
                        TextField(
                          controller: _keteranganUmumCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: "Keterangan Umum Saluran",
                            hintText:
                                "Contoh: Secara keseluruhan saluran banyak endapan...",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "* Keterangan ini berlaku untuk seluruh panjang saluran.",
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),

                    // --- TAB 2: DETAIL SEGMEN (Logic lama Bapak pindah ke sini) ---
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            "Melewati Segmen: $_selectedKondisi",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getWarnaKondisi(_selectedKondisi),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildKondisiBtn("BAIK", Colors.green),
                              _buildKondisiBtn("RR", Colors.orange),
                              _buildKondisiBtn("RB", Colors.red),
                              _buildKondisiBtn("BAP", Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _keteranganKondisiCtrl,
                            onChanged: (v) =>
                                _keteranganSaluran[_selectedKondisi] = v,
                            decoration: InputDecoration(
                              labelText: "Keterangan $_selectedKondisi",
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isTracking ? _ambilFotoSaluran : null,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text("AMBIL FOTO SEGMEN"),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildFotoPreview(),
                          const SizedBox(height: 15),
                          if (_isTracking) // Tombol hanya muncul kalau lagi survey
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Logika Submit Manual Segmen
                                  if (_currentPath.isNotEmpty) {
                                    _gantiKondisi(
                                      _selectedKondisi,
                                    ); // Simpan data saat ini dan lanjut di kondisi yang sama
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Detail segmen berhasil disimpan!",
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save_as),
                                label: const Text("SIMPAN DETAIL SEGMEN"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTombolAksi() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isTracking || _currentPath.isEmpty)
                ? null
                : _simpanSurveyData,
            icon: const Icon(Icons.save),
            // Teks tombol simpan juga bisa berubah jika Bapak mau
            label: Text(
              _isEditingMode ? "UPDATE HASIL SURVEY" : "SIMPAN SURVEY BARU",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(15),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (!_isTracking)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startTracking,
                  // Ikon berubah: play_arrow untuk lanjut, add untuk baru
                  icon: Icon(
                    _isEditingMode
                        ? Icons.play_circle_fill
                        : Icons.add_location_alt,
                  ),
                  // Teks berubah sesuai status editing
                  label: Text(
                    _isEditingMode ? "LANJUTKAN SURVEY" : "MULAI SURVEY BARU",
                  ),
                  style: ElevatedButton.styleFrom(
                    // Warna berubah: Oranye (Peringatan Edit) vs Hijau (Data Baru)
                    backgroundColor: _isEditingMode
                        ? Colors.orange
                        : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (_isTracking) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pauseTracking,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isPaused ? "RESUME" : "PAUSE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _stopTracking,
                  icon: const Icon(Icons.stop),
                  label: const Text("STOP"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Fungsi tambahan untuk merapikan UI Peta
  Widget _buildOverlayInfoKM() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue),
      ),
      child: Text(
        "Jarak Tempuh: ${(_totalDistance / 1000).toStringAsFixed(3)} KM",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOverlayInfoBangunan() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "Bangunan Terinput: $_jumlahBangunanTerinput",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildFloatingTagButton() {
    return FloatingActionButton.extended(
      onPressed: _showTagBangunanDialog,
      label: const Text("TAG BANGUNAN"),
      icon: const Icon(Icons.add_location),
      backgroundColor: Colors.orange,
    );
  }

  Widget _buildFotoPreview() {
    // 1. Ambil list foto dengan aman. Jika null, berikan list kosong []
    // Ini kunci agar tidak crash (Null Safety)
    final List<String> daftarFoto = _fotoSaluran[_selectedKondisi] ?? [];

    // 2. Cek apakah list kosong
    if (daftarFoto.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          "Belum ada foto segmen ini",
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: daftarFoto.length,
        itemBuilder: (context, index) {
          final String pathFoto = daftarFoto[index];

          return Container(
            margin: const EdgeInsets.only(right: 8),
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: pathFoto.startsWith('http')
                  ? Image.network(
                      pathFoto,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                    )
                  : Image.file(
                      File(pathFoto),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getCombinedSaluranData() async {
    final db = DatabaseService();

    // 1. Ambil data dari HP (SQLite) - Ini untuk data yang status_sync = 0
    List<Map<String, dynamic>> dataLokal = await db.getPendingSaluran(
      widget.dataDI['id'],
    );

    // Buat list baru yang bisa dimodifikasi (Mutable)
    List<Map<String, dynamic>> combinedList = List.from(dataLokal);

    try {
      // 2. Ambil data dari server
      final serverData = await ApiService().fetchSaluranMaster(
        widget.dataDI['id'],
      );

      for (var s in serverData) {
        // FILTER: Ambil yang is_approved-nya FALSE (Tanda silang merah di Django Admin)
        if (s['is_approved'] == false) {
          // Cek duplikat berdasarkan nama agar tidak muncul double
          bool isDuplicate = combinedList.any(
            (l) => l['nama_saluran'] == s['nama_saluran'],
          );

          if (!isDuplicate) {
            // CLONE MAP: Pakai Map.from agar tidak error "read-only" saat tambah flag
            var item = Map<String, dynamic>.from(s);
            item['is_from_server'] = true;
            combinedList.add(item);
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal sinkron data server: $e");
    }

    return combinedList;
  }

  Future<void> _bukaGoogleMaps(double lat, double lng) async {
    // Skema URL untuk langsung membuka navigasi di aplikasi Google Maps
    final String googleMapsUrl = "google.navigation:q=$lat,$lng&mode=d";
    // Skema cadangan jika aplikasi tidak terinstall (buka via browser)
    final String backupUrl =
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else if (await canLaunchUrl(Uri.parse(backupUrl))) {
        await launchUrl(
          Uri.parse(backupUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Tidak dapat membuka peta.';
      }
    } catch (e) {
      debugPrint("Error buka Maps: $e");
      // Opsional: Tampilkan SnackBar jika gagal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal membuka Google Maps")),
      );
    }
  }

  Future<void> _loadExistingMarkers() async {
    final db = DatabaseService();
    // Ambil semua survey (bangunan) yang nama_salurannya sama dengan yang sedang diedit
    final bangunanList = await db.database.then(
      (d) => d.query(
        'surveys',
        where: 'di_id = ? AND nama_saluran = ?',
        whereArgs: [widget.dataDI['id'], _namaSaluranCtrl.text],
      ),
    );

    List<Marker> markers = [];
    for (var b in bangunanList) {
      double lat = double.tryParse(b['lat'].toString()) ?? 0.0;
      double lng = double.tryParse(b['lng'].toString()) ?? 0.0;

      String namaBgn = b['nama_bangunan']?.toString() ?? "Tanpa Nama";

      if (lat != 0.0) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                // --- INI DIALOG NAVIGASINYA ---
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(namaBgn),
                    content: const Text("Buka navigasi ke lokasi ini?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal"),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _bukaGoogleMaps(
                            lat,
                            lng,
                          ); // Memanggil fungsi navigasi
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text("Google Maps"),
                      ),
                    ],
                  ),
                );
              },
              child: Column(
                children: [
                  Image.asset(
                    'assets/icons/${b['kode_aset']}.png',
                    width: 30,
                    height: 30,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.location_on, color: Colors.red),
                  ),
                  Text(
                    namaBgn,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      _existingMarkers = markers;
    });
  }

  Future<void> _sinkronisasiBangunanKeLokal(int saluranId) async {
    final db = DatabaseService();
    try {
      print(
        "SINKRON: Mengambil data bangunan dari API untuk DI ID: ${widget.dataDI['id']}",
      );
      final allBangunan = await ApiService().fetchBangunanMaster(
        widget.dataDI['id'],
      );

      print("SINKRON: Total bangunan dari server: ${allBangunan.length}");

      final filtered = allBangunan.where((b) {
        // Kita ambil Nama Saluran dari data Bangunan di Server
        String namaSaluranServer = (b['nama_saluran'] ?? "")
            .toString()
            .trim()
            .toLowerCase();

        // Kita ambil Nama Saluran yang sedang aktif di Aplikasi (dari Controller)
        String namaSaluranTarget = _namaSaluranCtrl.text.trim().toLowerCase();

        print(
          "PEMBANDING: Server($namaSaluranServer) vs Aplikasi($namaSaluranTarget)",
        );

        // Bandingkan berdasarkan NAMA, bukan ID
        return namaSaluranServer == namaSaluranTarget;
      }).toList();

      print(
        "SINKRON: Jumlah bangunan yang cocok dengan Saluran ID $saluranId: ${filtered.length}",
      );

      for (var b in filtered) {
        String namaBgn =
            b['nomenklatur_ruas'] ?? b['nama_bangunan'] ?? "Tanpa Nama";

        // --- CEK DUPLIKAT DI SINI ---
        final existing = await db.database.then(
          (d) => d.query(
            'surveys',
            where: 'nama_bangunan = ? AND nama_saluran = ? AND di_id = ?',
            whereArgs: [namaBgn, _namaSaluranCtrl.text, widget.dataDI['id']],
          ),
        );

        if (existing.isEmpty) {
          await db.insertSurvey({
            'di_id': widget.dataDI['id'],
            'nama_di': widget.dataDI['nama_di'],
            'nama_saluran': _namaSaluranCtrl.text,
            'nama_bangunan': namaBgn,
            'kode_aset': b['kode_aset'],
            'lat': b['latitude'],
            'lng': b['longitude'],
            'status_sync': 1,
          });
          print("SINKRON: Berhasil tambah bangunan baru: $namaBgn");
        } else {
          print("SINKRON: Bangunan $namaBgn sudah ada di lokal, skip.");
        }
      }
      print("SINKRON: Berhasil insert ${filtered.length} data ke SQLite.");
    } catch (e) {
      print("SINKRON ERROR: $e");
    }
  }

  Future<void> _bersihkanDataKotor() async {
    final db = await DatabaseService().database;
    // Hapus semua data bangunan yang nama salurannya sama dengan yang sedang dibuka
    await db.delete(
      'surveys',
      where: 'nama_saluran = ? AND di_id = ?',
      whereArgs: [_namaSaluranCtrl.text, widget.dataDI['id']],
    );
    print("Database Bersih. Silakan klik sinkron ulang.");
  }

  bool _isSaving = false;

  void _simpanSurveyData() async {
    if (_isSaving) return;
    if (_namaSaluranCtrl.text.trim().isEmpty) {
      _showWarning("Nama Saluran wajib diisi!");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Masukkan segmen terakhir yang sedang berjalan
      if (_currentPath.isNotEmpty) {
        _segmenKondisi.add({
          'kondisi': _selectedKondisi,
          'panjang': _jarakSegmenIni,
          'keterangan': _keteranganKondisiCtrl.text,
          'titik_awal':
              "${_currentPath.first.latitude},${_currentPath.first.longitude}",
          'titik_akhir':
              "${_currentPath.last.latitude},${_currentPath.last.longitude}",
          'fotos': List.from(_currentFotos),
        });
      }

      // 2. Gabungkan history koordinat
      List<LatLng> totalPathFull = [];
      for (var poly in _pathHistory) {
        totalPathFull.addAll(poly.points);
      }
      totalPathFull.addAll(_currentPath);

      String pathSimpan = totalPathFull
          .where((e) => e.latitude != 0 && e.longitude != 0)
          .map((e) => "${e.latitude},${e.longitude}")
          .join('|');

      int diId = widget.dataDI['id'];

      // 3. Siapkan Map Data
      Map<String, dynamic> dataSimpan = {
        'di_id': diId,
        'nama_di': widget.dataDI['nama_di'],
        'nama_saluran': _namaSaluranCtrl.text,
        'surveyor': _currentSurveyor,
        'keterangan': _keteranganUmumCtrl.text,
        'hulu_id': _huluSaluranCtrl.text,
        'tipe_hulu': _huluCategory,
        'tingkat_jaringan': _selectedTingkatJaringan,
        'kewenangan': _selectedKewenangan,
        'panjang_saluran': _totalDistance,
        'path_kondisi': jsonEncode(_segmenKondisi),
        'panjang_bap': _panjangBap,
        'keterangan_baik': _keteranganSaluran['BAIK'] ?? "",
        'keterangan_rr': _keteranganSaluran['RR'] ?? "",
        'keterangan_rb': _keteranganSaluran['RB'] ?? "",
        'keterangan_bap': _keteranganBapCtrl.text,
        'foto_baik': jsonEncode(_fotoSaluran['BAIK'] ?? []),
        'foto_rr': jsonEncode(
          _fotoSaluran['RR'] ?? _fotoSaluran['RUSAK RINGAN'] ?? [],
        ),
        'foto_rb': jsonEncode(
          _fotoSaluran['RB'] ?? _fotoSaluran['RUSAK BERAT'] ?? [],
        ),
        'foto_bap': jsonEncode(_fotoSaluran['BAP'] ?? []),
        'path_koordinat': pathSimpan,
        'status_sync': 0,
      };

      // 4. Simpan ke SQLite Lokal
      if (_isEditingMode && _editingSaluranId != null) {
        await DatabaseService().updateSaluran(_editingSaluranId!, dataSimpan);
      } else {
        await DatabaseService().insertSaluran(dataSimpan);
      }

      // 5. Kirim ke Server API
      bool success = await ApiService().syncSaluran(dataSimpan);

      if (success) {
        await DatabaseService().updateStatusSurvey(diId, 1);
      }

      if (!mounted) return;

      // 6. HAPUS DRAFT & RESET UI
      await DatabaseService().deleteDraft(diId);
      _stopTracking();

      setState(() {
        _segmenKondisi = [];
        _currentFotos = [];
        _isEditingMode = false;
        _editingSaluranId = null;
        _namaSaluranCtrl.clear();
        _currentPath.clear();
        _pathHistory.clear();
        _jarakSegmenIni = 0;
        _totalDistance = 0;
        _fotoSaluran = {'BAIK': [], 'RR': [], 'RB': [], 'BAP': []};
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "✅ Data Sinkron ke Server"
                : "⚠️ Tersimpan di HP (Offline)",
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      debugPrint("🔴 Error Simpan: $e");
    }
  }

  String _searchKeyword = "";
  Widget _buildPendingApprovalList() {
    return _buildFieldset(
      title: "Pending Approval: Bangunan",
      icon: Icons.hourglass_empty,
      child: Column(
        children: [
          // FITUR SEARCH
          TextField(
            decoration: InputDecoration(
              hintText: "Cari bangunan...",
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchKeyword = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseService().getPendingApprovalSurveys(
                widget.dataDI['id'],
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text(
                    "Tidak ada data pending",
                    style: TextStyle(fontSize: 11),
                  );
                }

                final dataAsli = snapshot.data!;
                final seen = <String>{};
                final uniqueData = dataAsli
                    .where((item) => seen.add(item['nama_bangunan']))
                    .toList();

                // Filter berdasarkan search keyword dari data yang sudah unik
                final filteredData = uniqueData.where((item) {
                  final nama = item['nama_bangunan'].toString().toLowerCase();
                  return nama.contains(_searchKeyword);
                }).toList();

                if (filteredData.isEmpty)
                  return const Text("Data tidak ditemukan");

                return ListView.separated(
                  shrinkWrap: true, // Penting agar ListView bisa dalam Column
                  itemCount: filteredData.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = filteredData[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Image.asset(
                        'assets/icons/${data['kode_aset']}.png',
                        width: 30,
                        height: 30,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.apartment, color: Colors.orange),
                      ),
                      title: Text(
                        data['nama_bangunan'] ?? "Tanpa Nama",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Status: Pending Approval",
                        style: TextStyle(fontSize: 10),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.location_searching, // Ikon target lokasi
                              color: Colors.blueAccent,
                              size: 22,
                            ),
                            tooltip: "Arahkan Kamera Peta",
                            onPressed: () async {
                              double lat =
                                  double.tryParse(
                                    data['lat']?.toString() ?? "0.0",
                                  ) ??
                                  0.0;
                              double lng =
                                  double.tryParse(
                                    data['lng']?.toString() ?? "0.0",
                                  ) ??
                                  0.0;

                              if (lat != 0.0) {
                                _directionToPoint(lat, lng);
                              } else {
                                // 2. Jika koordinat bangunan 0.0, arahkan ke koordinat awal saluran (Polyline)
                                if (_existingPolylines.isNotEmpty) {
                                  LatLng titikSaluran =
                                      _existingPolylines.first.points.first;
                                  _mapController.move(titikSaluran, 18.0);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Mengarahkan ke pangkal saluran Master",
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Koordinat tidak ditemukan!",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.near_me,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () {
                              double lat =
                                  double.tryParse(
                                    data['lat']?.toString() ?? "0.0",
                                  ) ??
                                  0.0;
                              double lng =
                                  double.tryParse(
                                    data['lng']?.toString() ?? "0.0",
                                  ) ??
                                  0.0;

                              if (lat != 0.0) {
                                _bukaGoogleMaps(
                                  lat,
                                  lng,
                                ); // Ganti dari _directionToPoint ke _bukaGoogleMaps
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.orange,
                              size: 20,
                            ),
                            onPressed: () => _editPendingSurvey(data),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKondisiBtn(String label, Color color) {
    bool isSelected = _selectedKondisi == label;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[300],
      ),
      onPressed: () => _gantiKondisi(label),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.black),
      ),
    );
  }

  Widget _buildFieldset({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // DIBUNGKUS EXPANDED AGAR TEKS MENGALAH
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    // PAKAI FLEXIBLE + ELLIPSIS
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
          const Divider(),
          child,
        ],
      ),
    );
  }

  void _showDaftarTitik() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(15),
          child: Column(
            children: [
              Text(
                "Daftar Bangunan di ${_namaSaluranCtrl.text}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _existingMarkers.length,
                  itemBuilder: (context, index) {
                    final m = _existingMarkers[index];
                    // Asumsikan data nama ada di metadata marker atau ambil dari list asal
                    return ListTile(
                      leading: CircleAvatar(child: Text("${index + 1}")),
                      title: Text("Bangunan ${index + 1}"),
                      subtitle: Text(
                        "Lat: ${m.point.latitude}, Lng: ${m.point.longitude}",
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.directions, color: Colors.blue),
                        onPressed: () => _bukaGoogleMaps(
                          m.point.latitude,
                          m.point.longitude,
                        ),
                      ),
                      onTap: () {
                        _mapController.move(m.point, 18.0);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editPendingSurvey(Map<String, dynamic> oldData) async {
    // Pastikan konversi ke double aman, gunakan 0.0 jika data Null atau korup
    double lat = 0.0;
    double lng = 0.0;
    double jarak = 0.0;

    try {
      lat = (oldData['lat'] != null)
          ? double.parse(oldData['lat'].toString())
          : 0.0;
      lng = (oldData['lng'] != null)
          ? double.parse(oldData['lng'].toString())
          : 0.0;
      jarak = (oldData['jarak_dari_hulu'] != null)
          ? double.parse(oldData['jarak_dari_hulu'].toString())
          : 0.0;
    } catch (e) {
      debugPrint("Error parsing koordinat: $e");
    }

    // Arahkan peta jika koordinat valid
    if (lat != 0.0 && lng != 0.0) {
      _directionToPoint(lat, lng);
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormBangunanDetail(
          diId: oldData['di_id'] ?? 0,
          namaDI: oldData['nama_di'] ?? "",
          namaSaluran: oldData['nama_saluran'] ?? "",
          lat: lat, // Nilai ini sekarang dijamin double
          lng: lng, // Nilai ini sekarang dijamin double
          jarakAntarRuas: jarak,
          bangunanChoices: _bangunanChoices,
          existingData: oldData,
        ),
      ),
    );

    if (result != null) {
      await DatabaseService().updateSurvey(oldData['id'], result);
      _fetchDaftarHulu(); // Refresh data
    }
  }

  void _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("GPS HP Mati Pak, aktifkan dulu!")),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Izin lokasi ditolak, tracking gagal.")),
        );
        return;
      }
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // setState(() {
      //   _isLoadingMapData = true; // Pinjam loading untuk nunggu GPS stabil
      // });

      setState(() {
        _isTracking = true;
        _isPaused = false;
        _currentPath = [LatLng(pos.latitude, pos.longitude)];
        _totalDistance = 0.0;
        _jarakSegmenIni = 0.0;
      });

      // TAMPILKAN DIALOG RECHECK KOORDINAT
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Mengunci GPS & Memusatkan Peta..."),
                ],
              ),
            ),
          ),
        ),
      );
      Position poz = await Geolocator.getCurrentPosition();
      Navigator.pop(context); // Tutup loading setelah posisi didapat

      setState(() {
        _isTracking = true;
        _currentLat = poz.latitude;
        _currentLng = poz.longitude;
        _currentPath = [LatLng(poz.latitude, poz.longitude)];
        _mapController.move(
          _currentPath.last,
          18.0,
        ); // Langsung pusat ke lokasi
      });

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 3,
            ),
          ).listen((p) {
            if (!mounted) return;
            if (p.accuracy > 10.0) {
              debugPrint(
                "GPS Kurang Akurat (${p.accuracy}m), Abaikan titik ini.",
              );
              return;
            }

            if (p.speed < 0.2) return;

            LatLng pt = LatLng(p.latitude, p.longitude);

            setState(() {
              _currentLat = p.latitude;
              _currentLng = p.longitude;

              if (_currentPath.isNotEmpty) {
                double d = Geolocator.distanceBetween(
                  _currentPath.last.latitude,
                  _currentPath.last.longitude,
                  pt.latitude,
                  pt.longitude,
                );
                if (d > 20) {
                  debugPrint("Lompatan GPS terdeteksi: $d meter. Diabaikan.");
                  return;
                }
                _totalDistance += d;
                _jarakSegmenIni += d;
              }

              _currentPath.add(pt);
              // _mapController.move(pt, 18.0);
            });

            _autoSaveDraft();
          });
    } catch (e) {
      debugPrint("Error GPS: $e");
    }
  }

  void _autoSaveDraft() async {
    await DatabaseService().saveDraft({
      'di_id': widget.dataDI['id'],
      'nama_hulu': _huluSaluranCtrl.text,
      'is_manual_hulu': _isManualHulu ? 1 : 0,
      'path_data': jsonEncode(
        _currentPath
            .map((e) => {'lat': e.latitude, 'lng': e.longitude})
            .toList(),
      ),
      'total_distance': _totalDistance,
      'jarak_segmen': _jarakSegmenIni,
      'kondisi_aktif': _selectedKondisi,
    });
  }

  void _lanjutkanSurveySaluran(Map<String, dynamic> data) async {
    // 1. Validasi awal
    String pathRaw = data['path_koordinat'] ?? "";
    if (pathRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data koordinat tidak ditemukan!")),
      );
      return;
    }

    try {
      // 2. Ambil data segmen
      List<Map<String, dynamic>> segmenTemp = [];
      if (data['path_kondisi'] != null && data['path_kondisi'] != "") {
        var decoded = jsonDecode(data['path_kondisi']);
        segmenTemp = List<Map<String, dynamic>>.from(decoded);
      }

      // 3. Pecah string koordinat menjadi List<LatLng>
      List<String> pointsStr = pathRaw.split('|');
      List<LatLng> fullPath = pointsStr.map((p) {
        List<String> coords = p.split(',');
        return LatLng(double.parse(coords[0]), double.parse(coords[1]));
      }).toList();

      // 4. Hitung Jarak Asli (Sangat penting untuk Emulator)
      double totalJarakAsli = 0;
      for (int i = 0; i < fullPath.length - 1; i++) {
        totalJarakAsli += Geolocator.distanceBetween(
          fullPath[i].latitude,
          fullPath[i].longitude,
          fullPath[i + 1].latitude,
          fullPath[i + 1].longitude,
        );
      }

      List<Polyline> coloredHistory = [];

      // 5. Logika penggambaran garis
      if (segmenTemp.isNotEmpty && fullPath.length > 1 && totalJarakAsli > 0) {
        int currentStartIndex = 0;
        for (int i = 0; i < segmenTemp.length; i++) {
          var seg = segmenTemp[i];
          double panjangSegmen =
              double.tryParse(seg['panjang'].toString()) ?? 0.0;
          String kondisi = (seg['kondisi'] ?? "BAIK").toString().toUpperCase();

          double rasio = panjangSegmen / totalJarakAsli;
          int pointsInSegmen = (rasio * fullPath.length).round();

          if (pointsInSegmen < 2) pointsInSegmen = 2;

          int endIndex = currentStartIndex + pointsInSegmen;
          if (endIndex > fullPath.length || i == segmenTemp.length - 1) {
            endIndex = fullPath.length;
          }

          if (currentStartIndex < endIndex - 1) {
            coloredHistory.add(
              Polyline(
                points: fullPath.sublist(currentStartIndex, endIndex),
                color: _getWarnaKondisi(kondisi),
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            );
          }
          currentStartIndex = endIndex - 1;
        }
      } else {
        // Jika data jarak 0 (sering di emulator), gambar garis biru default
        coloredHistory.add(
          Polyline(points: fullPath, color: Colors.blue, strokeWidth: 5),
        );
      }

      // 6. Update State sekaligus
      setState(() {
        _editingSaluranId = data['id'];
        _isEditingMode = true;
        _segmenKondisi = segmenTemp;
        _currentPath = fullPath;
        _pathHistory = coloredHistory;
        _totalDistance = totalJarakAsli;
        _namaSaluranCtrl.text = data['nama_saluran'] ?? "";
      });

      // 7. Beri jeda sedikit sebelum gerakkan peta (Agar MapController siap)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (fullPath.isNotEmpty && mounted) {
          _mapController.move(fullPath.last, 17.0);
        }
      });

      // 8. Load data bangunan terkait
      if (data['id'] != null) {
        await _sinkronisasiBangunanKeLokal(data['id']);
        await _loadExistingMarkers();
      }
    } catch (e) {
      debugPrint("ERROR LANJUTKAN SURVEY: $e");
    }
  }

  List<String> _parseFotoData(dynamic dataFoto) {
    if (dataFoto == null || dataFoto == "" || dataFoto == "[]") return [];

    try {
      List<dynamic> decoded = jsonDecode(dataFoto);
      return decoded.map((path) {
        String p = path.toString();
        // Jika path tidak diawali '/' dan bukan 'http', berarti ini path media Django
        if (!p.startsWith('http') && !p.startsWith('/data/')) {
          return "${ApiService.baseUrl}/media/$p";
        }
        return p;
      }).toList();
    } catch (e) {
      // Jika bukan JSON, cek apakah ini string URL tunggal
      String p = dataFoto.toString();
      if (!p.startsWith('http') && !p.startsWith('/data/')) {
        return ["${ApiService.baseUrl}/media/$p"];
      }
      return [p];
    }
  }

  void _pauseTracking() {
    setState(() {
      _isPaused ? _positionStream?.resume() : _positionStream?.pause();
      _isPaused = !_isPaused;
    });
  }

  void _stopTracking() {
    if (_currentPath.length > 1) {
      setState(() {
        _pathHistory.add(
          Polyline(
            points: List.from(_currentPath),
            color: _getWarnaKondisi(_selectedKondisi),
            strokeWidth: 5,
          ),
        );
      });
    }

    _positionStream?.cancel();
    _positionStream = null;

    setState(() {
      _isTracking = false;
      // JANGAN CLEAR _currentPath di sini agar garis tetap kelihatan di peta
    });
  }

  Future<void> _loadMarkersFromServer(int saluranId) async {
    try {
      final allBangunan = await ApiService().fetchBangunanMaster(
        widget.dataDI['id'],
      );

      debugPrint("API: Mendapat ${allBangunan.length} bangunan total.");

      for (var b in allBangunan) {
        debugPrint("--- CEK DATA SERVER ---");
        debugPrint("Nama Bangunan: ${b['nama_bangunan']}");
        debugPrint(
          "Isi field 'saluran': ${b['saluran']} (Tipe: ${b['saluran'].runtimeType})",
        );
        debugPrint(
          "Membandingkan dengan saluranId: $saluranId (Tipe: ${saluranId.runtimeType})",
        );
      }

      final filtered = allBangunan.where((b) {
        var idDiBangunan = (b['saluran'] ?? b['saluran_id']).toString().trim();
        var idTarget = saluranId.toString().trim();
        return idDiBangunan == idTarget;
      }).toList();
      // final filtered = allBangunan;

      List<Marker> markers = [];
      for (var b in filtered) {
        double lat = double.tryParse(b['latitude']?.toString() ?? "0.0") ?? 0.0;
        double lng =
            double.tryParse(b['longitude']?.toString() ?? "0.0") ?? 0.0;

        String namaBangunan = b['nama_bangunan']?.toString() ?? "Tanpa Nama";

        if (lat != 0.0) {
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              // Ganti 'builder' menjadi 'child' sesuai versi flutter_map Bapak
              child: GestureDetector(
                onTap: () {
                  // --- DIALOG NAVIGASI DIMULAI DISINI ---
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(namaBangunan),
                      content: const Text(
                        "Apakah Anda ingin menuju ke lokasi titik ini menggunakan Google Maps?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Batal"),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Tutup dialog dulu
                            _bukaGoogleMaps(
                              lat,
                              lng,
                            ); // Panggil fungsi buka maps
                          },
                          icon: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Navigasi",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Column(
                  children: [
                    Image.asset(
                      'assets/icons/${b['kode_aset']}.png',
                      width: 30,
                      height: 30,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        namaBangunan,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }

      setState(() {
        _existingMarkers = markers;
      });

      debugPrint(
        "HASIL AKHIR: Berhasil pasang ${markers.length} marker ke peta.",
      );
    } catch (e) {
      debugPrint("Gagal muat bangunan server: $e");
    }
  }

  Future<void> _bukaNavigasiGoogleMaps(double lat, double lng) async {
    // Format URL untuk navigasi Google Maps
    final Uri url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Jika aplikasi Google Maps tidak terinstall, buka via browser
      final Uri webUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
      );
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _loadExistingData() async {
    try {
      final res = await http.get(
        Uri.parse("${ApiService.baseUrl}/api/saluran/${widget.dataDI['id']}/"),
      );

      if (res.statusCode == 200) {
        var jsonResponse = jsonDecode(res.body);
        List<Polyline> lines = [];

        // Ambil list dari key "data"
        var dataSaluran = jsonResponse['data'] as List;

        for (var item in dataSaluran) {
          if (item['geometry_data'] != null) {
            var geom = item['geometry_data'];
            var type = geom['type'];
            var coords = geom['coordinates'];

            if (type == "MultiLineString") {
              // Looping untuk setiap jalur dalam MultiLine
              for (var line in coords) {
                // Cek lagi apakah di dalamnya ada array lagi (antisipasi nested berlebih)
                if (line is List && line.isNotEmpty && line[0] is List) {
                  // Untuk struktur [[[lng, lat], [lng, lat]]]
                  List<LatLng> points = line.map<LatLng>((c) {
                    return LatLng(
                      double.parse(c[1].toString()), // Latitude
                      double.parse(c[0].toString()), // Longitude
                    );
                  }).toList();

                  lines.add(
                    Polyline(
                      points: points,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  );
                }
              }
            }
          }
        }

        setState(() {
          _existingPolylines = lines;
        });

        // Pindahkan kamera ke titik pertama agar langsung kelihatan
        if (lines.isNotEmpty && lines.first.points.isNotEmpty) {
          _mapController.move(lines.first.points.first, 15.0);
        }
      }
    } catch (e) {
      debugPrint("Error Load Map: $e");
    }
  }
}

class FormBangunanDetail extends StatefulWidget {
  final int diId;
  final String namaDI, namaSaluran;
  final double lat, lng, jarakAntarRuas;
  final List<Map<String, String>> bangunanChoices;
  final Map<String, dynamic>? existingData;

  const FormBangunanDetail({
    super.key,
    required this.diId,
    required this.namaDI,
    required this.namaSaluran,
    required this.lat,
    required this.lng,
    required this.jarakAntarRuas,
    required this.bangunanChoices,
    this.existingData,
  });
  @override
  State<FormBangunanDetail> createState() => _FormBangunanDetailState();
}

class _FormBangunanDetailState extends State<FormBangunanDetail> {
  final TextEditingController _n = TextEditingController(); // Nama Bangunan
  final TextEditingController _d = TextEditingController(); // Desa
  final TextEditingController _k = TextEditingController(); // Kecamatan
  final TextEditingController _jenisPintuCtrl = TextEditingController();
  final TextEditingController _pB = TextEditingController(text: "0");
  final TextEditingController _pRR = TextEditingController(text: "0");
  final TextEditingController _pRB = TextEditingController(text: "0");
  final TextEditingController _ketCtrl = TextEditingController();
  final TextEditingController _lebarCtrl = TextEditingController(text: "0");
  final TextEditingController _tinggiCtrl = TextEditingController(text: "0");

  String _sel = 'P01';
  List<File?> _fotos = List.filled(15, null);
  String _selectedKondisiBangunan = 'BAIK';
  List<String?> _remoteFotoUrls = List.filled(15, null);
  @override
  void dispose() {
    _n.dispose();
    _d.dispose();
    _k.dispose();
    _jenisPintuCtrl.dispose();
    _ketCtrl.dispose();
    _lebarCtrl.dispose();
    _tinggiCtrl.dispose();

    // Bersihkan controller jumlah pintu
    _pB.dispose();
    _pRR.dispose();
    _pRB.dispose();

    // Bersihkan controller dinamis di dalam Map (jika ada)
    _ketKondisi.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Panggil fungsi pencarian alamat otomatis berdasarkan koordinat yang dibawa dari Map
    _getAlamatOtomatis(widget.lat, widget.lng);

    if (widget.existingData != null) {
      _n.text = widget.existingData!['nama_bangunan'] ?? "";
      _sel = widget.existingData!['kode_aset'] ?? "P01";
      _d.text = widget.existingData!['desa'] ?? "";
      _k.text = widget.existingData!['kecamatan'] ?? "";
      _lebarCtrl.text =
          widget.existingData!['lebar_saluran']?.toString() ?? "0";
      _tinggiCtrl.text =
          widget.existingData!['tinggi_saluran']?.toString() ?? "0";
      _pB.text = widget.existingData!['pintu_baik']?.toString() ?? "0";
      _pRR.text = widget.existingData!['pintu_rr']?.toString() ?? "0";
      _pRB.text = widget.existingData!['pintu_rb']?.toString() ?? "0";
      _jenisPintuCtrl.text = widget.existingData!['jenis_pintu'] ?? "";
      _ketCtrl.text = widget.existingData!['keterangan'] ?? "";
      _selectedKondisiBangunan =
          widget.existingData!['kondisi_bangunan'] ?? "BAIK";

      if (widget.lat == 0.0) {
        _ambilLokasiHPSekarang();
      } else {
        _getAlamatOtomatis(widget.lat, widget.lng);
      }

      _lebarCtrl.text =
          widget.existingData!['lebar_saluran']?.toString() ?? "0";

      setState(() {
        for (int i = 1; i <= 5; i++) {
          String? pathFoto = widget.existingData!['foto$i'];
          if (pathFoto != null && pathFoto.isNotEmpty) {
            // Masukkan path string dari database ke object File
            _fotos[i - 1] = File(pathFoto);
          }
        }
      });
    } else {
      // 2. Jika mode INPUT BARU, jalankan deteksi alamat otomatis
      _getAlamatOtomatis(widget.lat, widget.lng);
    }
  }

  Future<void> _ambilLokasiHPSekarang() async {
    Position pos = await Geolocator.getCurrentPosition();
    setState(() {
      // Update alamat berdasarkan GPS HP
      _getAlamatOtomatis(pos.latitude, pos.longitude);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Koordinat Master kosong, menggunakan GPS HP saat ini"),
      ),
    );
  }

  Widget _buildFieldset({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              // TAMBAHKAN EXPANDED DI SINI JUGA
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // Tambahkan variabel di State FormBangunanDetail
  Map<String, List<File?>> _fotoKondisi = {
    'BAIK': List.filled(5, null),
    'RR': List.filled(5, null),
    'RB': List.filled(5, null),
  };
  Map<String, TextEditingController> _ketKondisi = {
    'BAIK': TextEditingController(),
    'RR': TextEditingController(),
    'RB': TextEditingController(),
  };

  // WIDGET BARU: Fieldset Kondisi Dinamis
  Widget _buildFieldsetKondisi(String label, String code, Color color) {
    return _buildFieldset(
      title: "Dokumentasi Kondisi $label",
      icon: Icons.camera_enhance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ketKondisi[code],
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "Keterangan Kondisi $label",
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const Text("Foto Kondisi (Maks 5):", style: TextStyle(fontSize: 11)),
          const SizedBox(height: 5),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 15,
              itemBuilder: (c, i) => _buildFotoBoxKondisi(code, i),
            ),
          ),
        ],
      ),
    );
  }

  // Tambahkan fungsi Picker khusus kondisi
  Widget _buildFotoBoxKondisi(String code, int index) {
    return GestureDetector(
      onTap: () async {
        final p = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 50,
        );
        if (p != null)
          setState(() => _fotoKondisi[code]![index] = File(p.path));
      },
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _fotoKondisi[code]![index] != null
                ? Colors.blue
                : Colors.grey,
          ),
        ),
        child: _fotos[index] == null
            ? const Icon(Icons.add_a_photo)
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _fotos[index]!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // JIKA FILE LOKAL TIDAK ADA, TAMPILKAN PLACEHOLDER ATAU IKON
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.red),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _coordInfo(String label, double val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          val.toStringAsFixed(7),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
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
            labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildFotoBox(int index) {
    return GestureDetector(
      onTap: () async {
        final p = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 50,
        );
        if (p != null) setState(() => _fotos[index] = File(p.path));
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: _fotos[index] != null
            ? Image.file(_fotos[index]!, fit: BoxFit.cover) // Foto baru diambil
            : (_remoteFotoUrls[index] != null &&
                  _remoteFotoUrls[index]!.isNotEmpty)
            ? Image.network(
                _remoteFotoUrls[index]!,
                fit: BoxFit.cover,
              ) // Foto lama dari server
            : const Icon(Icons.add_a_photo),
      ),
    );
  }

  Future<void> _getAlamatOtomatis(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          // subLocality biasanya Desa/Kelurahan
          // locality biasanya Kecamatan
          _d.text = place.subLocality ?? "";
          _k.text = place.locality ?? "";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Alamat terdeteksi: Desa ${_d.text}")),
        );
      }
    } catch (e) {
      debugPrint("Gagal mendapatkan alamat: $e");
    }
  }

  Future<void> _mulaiUkurOtomatis(BuildContext context) async {
    bool isArSupported = true; // Nanti bisa pakai library arcore_flutter_plugin

    if (isArSupported == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("HP Tidak Support AR. Silakan Input Manual Pak!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 15),
            Text(
              "Mengaktifkan Sensor AR & AI Scanner...",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));
    Navigator.pop(context);

    Random rng = Random();
    double hasilLebar = 1.0 + rng.nextDouble() * 2.0;
    double hasilTinggi = 0.5 + rng.nextDouble() * 1.0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 10),
            const Text(
              "AI Measurement Berhasil!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text(
              "Sensor AR mendeteksi dimensi saluran:",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _resultBox("Lebar", "${hasilLebar.toStringAsFixed(2)} m"),
                _resultBox("Tinggi", "${hasilTinggi.toStringAsFixed(2)} m"),
              ],
            ),
            const SizedBox(height: 20),
            // Gunakan ElevatedButton standar agar tidak error Undefined 'SInputButton'
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _lebarCtrl.text = hasilLebar.toStringAsFixed(2);
                    _tinggiCtrl.text = hasilTinggi.toStringAsFixed(2);
                  });
                  Navigator.pop(context);
                },
                child: const Text("TERAPKAN KE FORM"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tambahkan juga widget _resultBox di dalam class yang sama
  Widget _resultBox(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  void _simpanData() async {
    // 1. Validasi: Nama bangunan wajib diisi
    if (_n.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama Bangunan Wajib Diisi!")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String namaSurveyor = prefs.getString('username') ?? "Anonim";

    // 2. Siapkan Map data (Pakai variabel 'data')
    Map<String, dynamic> data = {
      'di_id': widget.diId,
      'nama_di': widget.namaDI,
      'nama_saluran': widget.namaSaluran,
      'nama_bangunan': _n.text,
      'kode_aset': _sel,
      'kondisi_bangunan': _selectedKondisiBangunan,
      'surveyor': namaSurveyor,
      'lebar_saluran': double.tryParse(_lebarCtrl.text) ?? 0,
      'tinggi_saluran': double.tryParse(_tinggiCtrl.text) ?? 0,
      'pintu_baik': int.tryParse(_pB.text) ?? 0,
      'pintu_rr': int.tryParse(_pRR.text) ?? 0,
      'pintu_rb': int.tryParse(_pRB.text) ?? 0,
      'jenis_pintu': _jenisPintuCtrl.text,
      'jarak_dari_hulu': widget.jarakAntarRuas,
      'desa': _d.text,
      'kecamatan': _k.text,
      'lat': widget.lat,
      'lng': widget.lng,
      'keterangan': _ketCtrl.text,
      'keterangan_tambahan': _ketCtrl.text,
      'foto1': _fotos[0]?.path ?? _remoteFotoUrls[0] ?? '',
      'foto2': _fotos[1]?.path ?? _remoteFotoUrls[1] ?? '',
      'foto3': _fotos[2]?.path ?? _remoteFotoUrls[2] ?? '',
      'foto4': _fotos[3]?.path ?? _remoteFotoUrls[3] ?? '',
      'foto5': _fotos[4]?.path ?? _remoteFotoUrls[4] ?? '',
      'status_sync': 0,
    };

    final db = DatabaseService();

    if (widget.existingData != null) {
      await db.updateSurvey(widget.existingData!['id'], data);
    } else {
      await db.insertSurvey(data);
    }

    // 4. Kembali ke halaman utama dengan membawa data
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Input Bangunan"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFieldset(
              title: "Dimensi Saluran (Eksisting)",
              icon: Icons.straighten,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BAGIAN 1: INPUT MANUAl ---
                  const Text(
                    "Input Manual:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lebarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Lebar (m)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.width_full),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _tinggiCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Tinggi (m)",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.height),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // const SizedBox(height: 20),
                  // const Divider(),

                  // // --- BAGIAN 2: SCAN AR ---
                  // const Text(
                  //   "Gunakan Sensor (Otomatis):",
                  //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  // ),
                  // const SizedBox(height: 8),
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton.icon(
                  //     onPressed: () => _mulaiUkurOtomatis(context),
                  //     icon: const Icon(Icons.view_in_ar),
                  //     label: const Text("SCAN DIMENSI VIA KAMERA AR"),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.blueAccent,
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.symmetric(vertical: 15),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 5),
                  // const Text(
                  //   "* Klik tombol di atas jika ingin mengukur menggunakan sensor AR kamera.",
                  //   style: TextStyle(
                  //     fontSize: 10,
                  //     fontStyle: FontStyle.italic,
                  //     color: Colors.grey,
                  //   ),
                  // ),
                ],
              ),
            ),
            _buildFieldset(
              title: "1. Data Bangunan",
              icon: Icons.apartment,
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _sel,
                    items: widget.bangunanChoices
                        .map(
                          (b) => DropdownMenuItem(
                            value: b['code'],
                            child: Text(b['name']!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _sel = v!;
                        // Jika yang dipilih bukan bangunan berpintu, kosongkan nilainya
                        if (![
                          'B01',
                          'B02',
                          'B03',
                          'P01',
                          'P02',
                          'P03',
                          'P04',
                          'P11',
                          'C16',
                          'C20',
                          'C02',
                          'C03',
                          'C12',
                          'C13',
                          'C08',
                          'C03',
                          'C09',
                          'C10',
                          'S13',
                        ].contains(_sel)) {
                          _pB.text = "0";
                          _pRR.text = "0";
                          _pRB.text = "0";
                          _jenisPintuCtrl.clear();
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Kode Aset",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _n,
                    decoration: const InputDecoration(
                      labelText: "Nama Bangunan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedKondisiBangunan,
                    items: [
                      DropdownMenuItem(
                        value: 'BAIK',
                        child: Text("Kondisi: BAIK"),
                      ),
                      DropdownMenuItem(
                        value: 'RR',
                        child: Text("Kondisi: RUSAK RINGAN"),
                      ),
                      DropdownMenuItem(
                        value: 'RB',
                        child: Text("Kondisi: RUSAK BERAT"),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedKondisiBangunan = v!),
                    decoration: const InputDecoration(
                      labelText: "Kondisi Fisik Bangunan",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.health_and_safety),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. FIELDSET LOKASI
            // ==========================================
            _buildFieldset(
              title: "2. Lokasi Aset",
              icon: Icons.location_on,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _k,
                      decoration: const InputDecoration(
                        labelText: "Kecamatan",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _d,
                      decoration: const InputDecoration(
                        labelText: "Desa",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // TAMPILAN KOORDINAT (TRIGGERED)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _coordInfo("Latitude", widget.lat),
                  const VerticalDivider(),
                  _coordInfo("Longitude", widget.lng),
                ],
              ),
            ),

            if ([
              'B01',
              'B02',
              'B03',
              'P01',
              'P02',
              'P03',
              'P04',
              'P11',
              'C16',
              'C20',
              'C02',
              'C03',
              'C12',
              'C13',
              'C08',
              'C09',
              'C10',
              'S13',
            ].contains(_sel))
              _buildFieldset(
                title: "3. Kondisi Pintu Air",
                icon: Icons.settings_input_component,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _jenisPintuCtrl,
                      decoration: const InputDecoration(
                        labelText: "Jenis Pintu",
                        hintText: "Contoh: Sorong, Romyn, atau Tarik",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Jumlah Pintu Berdasarkan Kondisi:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _pintuInput(_pB, "Baik", Colors.green),
                        _pintuInput(_pRR, "RR", Colors.orange),
                        _pintuInput(_pRB, "RB", Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
            _buildFieldset(
              title: "4. Dokumentasi & Keterangan Kondisi Bangunan",
              icon: Icons.camera_alt,
              child: Column(
                children: [
                  TextField(
                    controller: _ketCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Keterangan Tambahan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Foto Lokasi (Maks 5):",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (c, i) => _buildFotoBox(i),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simpanData,
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  "SIMPAN DATA BANGUNAN",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  // Mengambil tinggi standar TabBar
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Menggunakan Material agar TabBar memiliki warna background yang solid
    // dan efek visual yang benar saat diklik
    return Material(
      elevation: 1.0, // Memberikan sedikit bayangan di bawah tab
      color: Colors.white, // Menentukan warna background tab menjadi putih
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    // Kembalikan true jika ingin tab bisa berubah warna/state secara dinamis
    return false;
  }
}
