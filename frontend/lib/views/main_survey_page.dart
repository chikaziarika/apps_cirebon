import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'survey_saluran_page.dart';
import '../services/database_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class MainSurveyPage extends StatefulWidget {
  const MainSurveyPage({super.key});

  @override
  State<MainSurveyPage> createState() => _MainSurveyPageState();
}

class _MainSurveyPageState extends State<MainSurveyPage> {
  final MapController _mapController = MapController();

  // State Data Master
  List<Map<String, dynamic>> _listDI = [];
  int? _selectedIdDI;

  // State Peta (Preview Keseluruhan)
  List<Polyline> _savedPolylines = [];
  List<Marker> _savedMarkers = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // Di dalam class _MainSurveyPageState
  bool _isDownloadingHulu = false;

  Future<void> _unduhDataHulu() async {
    if (_selectedIdDI == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih D.I. terlebih dahulu Pak!")),
      );
      return;
    }

    setState(() => _isDownloadingHulu = true);

    try {
      // 1. Ambil data dari server via ApiService
      final List<dynamic> dataHulu = await ApiService().fetchMasterHulu(
        _selectedIdDI!,
      );

      // 2. Simpan ke database lokal saluran
      final db = DatabaseService();
      for (var item in dataHulu) {
        await db.insertSaluran({
          'di_id': _selectedIdDI,
          'nama_saluran': item['nama_saluran'],
          'tipe_hulu': item['tipe_hulu'] ?? 'Saluran',
          'status_sync': 1, // Tandai ini data master (bukan hasil survey baru)
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Data Hulu Berhasil Diunduh ke HP")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isDownloadingHulu = false);
    }
  }

  Future<void> _startSurvey() async {
    // 1. Tampilkan loading agar user tahu sedang ngecek GPS
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Cek apakah layanan GPS nyala
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Navigator.pop(context); // Tutup loading
        _showError("GPS Anda mati, silakan nyalakan dulu Pak.");
        return;
      }

      // 3. Cek akurasi (Cari sinyal sampai akurasinya di bawah 20 meter)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Tunggu maksimal 10 detik
      );

      Navigator.pop(context); // Tutup loading

      if (position.accuracy > 30) {
        _showError(
          "Sinyal GPS lemah (Akurasi: ${position.accuracy.toStringAsFixed(1)}m). Cari tempat terbuka dulu Pak.",
        );
        return;
      }

      // 4. Jika oke, baru pindah halaman
      final selectedData = _listDI.firstWhere((e) => e['id'] == _selectedIdDI);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SurveySaluranPage(dataDI: selectedData),
        ),
      ).then((_) => _refreshData());
    } catch (e) {
      Navigator.pop(context);
      _showError("Gagal mengunci GPS: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  bool _isSyncing = false;

  Future<void> _downloadDataPendukung() async {
    if (_selectedIdDI == null) return;

    setState(() => _isSyncing = true);
    try {
      final api = ApiService();
      final db = DatabaseService();

      // 1. Tarik Saluran
      final dataSaluran = await api.fetchSaluranMaster(_selectedIdDI!);
      for (var s in dataSaluran) {
        await db.insertSaluran({
          'di_id': _selectedIdDI,
          'nama_saluran': s['nama_saluran'],
          'status_sync': 1, // Tandai data server
        });
      }

      // 2. Tarik Bangunan (Bapak pakai DetailLayananBangunanSerializer)
      final dataBangunan = await api.fetchBangunanMaster(_selectedIdDI!);
      for (var b in dataBangunan) {
        await db.insertSurvey({
          'di_id': _selectedIdDI,
          'nama_bangunan':
              b['nama_aset_manual'], // Sesuaikan key dari serializer Django bapak
          'status_sync': 1,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Data Hulu Berhasil Diperbarui")),
      );
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  // Fungsi untuk load data dari SQLite ke Peta
  Future<void> _refreshData() async {
    try {
      final db = DatabaseService();
      final diData = await db.getAllDIFull();
      final bangunanData = await db.getAllSurveys();

      // Mapping Bangunan ke Marker Merah
      List<Marker> markers = bangunanData.map((b) {
        return Marker(
          point: LatLng(b['lat'] ?? 0, b['lng'] ?? 0),
          width: 30,
          height: 30,
          child: const Icon(Icons.location_on, color: Colors.red, size: 25),
        );
      }).toList();

      // Mapping Semua Jalur Saluran yang sudah tersimpan
      List<Polyline> polylines = [];
      for (var j in diData) {
        if (j['coordinates'] != null && j['coordinates'].isNotEmpty) {
          try {
            List<dynamic> coordsJson = jsonDecode(j['coordinates']);
            List<LatLng> points = coordsJson
                .map((c) => LatLng(c['lat'], c['lng']))
                .toList();
            if (points.isNotEmpty) {
              polylines.add(
                Polyline(
                  points: points,
                  color: Colors.blue.withOpacity(0.6),
                  strokeWidth: 4,
                ),
              );
            }
          } catch (e) {
            debugPrint("Error parsing koordinat: $e");
          }
        }
      }

      setState(() {
        _listDI = diData;
        _savedMarkers = markers;
        _savedPolylines = polylines;

        // Reset pilihan jika ID sudah tidak ada di list baru
        if (_selectedIdDI != null &&
            !_listDI.any((e) => e['id'] == _selectedIdDI)) {
          _selectedIdDI = null;
        }
      });
    } catch (e) {
      debugPrint("Error Refresh: $e");
    }
  }

  void _showDiDialog({Map<String, dynamic>? data}) {
    final kodeCtrl = TextEditingController(text: data?['kode_di'] ?? "");
    final namaCtrl = TextEditingController(text: data?['nama_di'] ?? "");
    final bendungCtrl = TextEditingController(text: data?['bendung'] ?? "");
    final sumberAirCtrl = TextEditingController(
      text: data?['sumber_air'] ?? "",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data == null ? "Tambah D.I." : "Edit D.I."),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kodeCtrl,
                decoration: const InputDecoration(labelText: "Kode"),
              ),
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(labelText: "Nama D.I."),
              ),
              TextField(
                controller: bendungCtrl,
                decoration: const InputDecoration(labelText: "Bendung"),
              ),
              TextField(
                controller: sumberAirCtrl,
                decoration: const InputDecoration(labelText: "Sumber Air"),
              ),
            ],
          ),
        ),
        actions: [
          if (data != null)
            TextButton(
              onPressed: () async {
                await DatabaseService().deleteDI(data['id']);
                if (!mounted) return;
                Navigator.pop(context);
                _refreshData();
              },
              child: const Text("HAPUS", style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: _selectedIdDI == null ? null : _startSurvey,
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Saluran"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
          // IconButton(
          //   icon: const Icon(
          //     Icons.add_location_alt_sharp,
          //     color: Colors.blueAccent,
          //     size: 28,
          //   ),
          //   onPressed: () => _showDiDialog(),
          // ),
        ],
      ),
      body: Column(
        children: [
          // 1. PREVIEW MAP
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-6.826, 108.604),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  tileProvider: const FMTCStore('mapStore').getTileProvider(),
                ),
                PolylineLayer(polylines: _savedPolylines),
                MarkerLayer(markers: _savedMarkers),
              ],
            ),
          ),

          // 2. PANEL PEMILIHAN
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          // 1. Nilai yang sedang dipilih
                          value: _selectedIdDI,

                          // 2. Daftar Item (WAJIB ADA)
                          items: _listDI.map((di) {
                            return DropdownMenuItem<int>(
                              value: di['id'],
                              child: Text(di['nama_di'] ?? "-"),
                            );
                          }).toList(),

                          // 3. Aksi saat dipilih (WAJIB ADA)
                          onChanged: (val) {
                            setState(() {
                              _selectedIdDI = val;
                            });
                          },

                          decoration: const InputDecoration(
                            labelText: "Pilih Daerah Irigasi",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Logika tombol download
                      // _isSyncing
                      //     ? const SizedBox(
                      //         width: 25,
                      //         height: 25,
                      //         child: CircularProgressIndicator(strokeWidth: 2),
                      //       )
                      //     : IconButton.filledTonal(
                      //         onPressed:
                      //             _downloadDataPendukung, // Fungsi yang kita buat sebelumnya
                      //         icon: const Icon(
                      //           Icons.cloud_download,
                      //           color: Colors.green,
                      //         ),
                      //         tooltip: "Tarik Data Master",
                      //       ),
                      // const SizedBox(width: 8),
                      // _isDownloadingHulu
                      //     ? const CircularProgressIndicator()
                      //     : IconButton.filledTonal(
                      //         onPressed: _unduhDataHulu,
                      //         icon: const Icon(
                      //           Icons.download_for_offline,
                      //           color: Colors.green,
                      //         ),
                      //         tooltip: "Tarik Data Saluran/Bangunan Server",
                      //       ),
                      // IconButton.filledTonal(
                      //   onPressed: () {
                      //     if (_selectedIdDI != null) {
                      //       final data = _listDI.firstWhere(
                      //         (e) => e['id'] == _selectedIdDI,
                      //       );
                      //       _showDiDialog(data: data);
                      //     }
                      //   },
                      //   icon: const Icon(Icons.edit_note),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedIdDI != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () {
                          final selectedData = _listDI.firstWhere(
                            (e) => e['id'] == _selectedIdDI,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SurveySaluranPage(dataDI: selectedData),
                            ),
                          ).then((_) => _refreshData());
                        },
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text("MULAI SURVEY LAPANGAN"),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
