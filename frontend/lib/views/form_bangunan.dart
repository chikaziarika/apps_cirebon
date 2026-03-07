import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';

class FormBangunanPage extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final bool isFromSaluran; // Flag pendeteksi asal survey

  const FormBangunanPage({
    super.key,
    this.editData,
    this.isFromSaluran = false, // Default mandiri
  });

  @override
  State<FormBangunanPage> createState() => _FormBangunanPageState();
}

class _FormBangunanPageState extends State<FormBangunanPage> {
  final TextEditingController _diController = TextEditingController();
  final TextEditingController _namaAsetController = TextEditingController();
  final TextEditingController _nomenklaturController = TextEditingController();
  final TextEditingController _surveyorController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();

  double? _lat, _lng;
  String _selectedKategori = 'Bangunan Utama';
  String _selectedKondisiAset = 'Baik';
  List<File> _images = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      _diController.text = widget.editData!['nama_di'] ?? "";
      _namaAsetController.text = widget.editData!['nama_bangunan'] ?? "";
      _nomenklaturController.text = widget.editData!['nomenklatur'] ?? "";
      _lebarController.text = widget.editData!['lebar']?.toString() ?? "";
      _tinggiController.text = widget.editData!['tinggi']?.toString() ?? "";
      _surveyorController.text = widget.editData!['surveyor'] ?? "";
      _lat = widget.editData!['lat'];
      _lng = widget.editData!['lng'];
    }
  }

  // --- FUNGSI SIMPAN KE DATABASE LOKAL ---
  Future<void> _handleSave() async {
    if (_namaAsetController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nama Aset wajib diisi!")));
      return;
    }

    setState(() => _isLoading = true);

    // 1. Tentukan Label Otomatis sesuai permintaan Bapak
    String labelOtomatis = widget.isFromSaluran
        ? "- Saluran > Bangunan"
        : "- Bangunan";

    // 2. Bungkus semua data ke Map
    final data = {
      'nama_di': _diController.text,
      'nama_bangunan': _namaAsetController.text,
      'nomenklatur': _nomenklaturController.text,
      'kategori': _selectedKategori,
      'lebar': double.tryParse(_lebarController.text) ?? 0,
      'tinggi': double.tryParse(_tinggiController.text) ?? 0,
      'kondisi': _selectedKondisiAset,
      'lat': _lat,
      'lng': _lng,
      'surveyor': _surveyorController.text,
      'status_sync': 0, // Belum sinkron
      'keterangan': labelOtomatis, // INI YANG BAPAK MINTA
    };

    try {
      final db = DatabaseService();
      if (widget.editData == null) {
        // Simpan Data Baru
        await db.insertSurvey(data);
      } else {
        // Update Data Lama (jika dari menu edit di SyncPage)
        await db.updateSurvey(widget.editData!['id'], data);
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        true,
      ); // Tutup dan kirim sinyal 'true' untuk refresh list
    } catch (e) {
      print("Gagal Simpan: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal ambil GPS.")));
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 35,
    );
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFromSaluran
              ? "Bangunan (Dari Saluran)"
              : "Inventarisasi Bangunan",
        ),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _sectionTitle("Identitas Aset"),
            _myTextField(
              _diController,
              "Nama Daerah Irigasi (D.I)",
              Icons.water,
            ),
            const SizedBox(height: 15),
            _myDropdown(),
            const SizedBox(height: 15),
            _myTextField(
              _namaAsetController,
              "Nama Aset / Lokasi",
              Icons.location_city,
            ),
            const SizedBox(height: 15),
            _myTextField(
              _nomenklaturController,
              "Nomenklatur (Kode Aset)",
              Icons.qr_code,
            ),
            const SizedBox(height: 25),
            _sectionTitle("Lokasi & Dokumentasi"),
            _locationBox(),
            const SizedBox(height: 25),
            _sectionTitle("Dimensi & Kondisi"),
            _dimensiRow(),
            const SizedBox(height: 15),
            _kondisiDropdown(),
            const SizedBox(height: 15),
            _myTextField(
              _surveyorController,
              "Nama Petugas Surveyor",
              Icons.person,
            ),
            const SizedBox(height: 30),

            // TOMBOL SIMPAN YANG SUDAH UPDATE
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _handleSave, // <--- PANGGIL FUNGSI SIMPAN
                    child: const Text(
                      "SIMPAN DATA INVENTARISASI",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS AGAR KODE BERSIH ---

  Widget _myTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _myDropdown() {
    return DropdownButtonFormField(
      value: _selectedKategori,
      decoration: const InputDecoration(
        labelText: "Kategori Aset",
        border: OutlineInputBorder(),
      ),
      items: [
        'Bangunan Utama',
        'Bangunan Bagi',
        'Bangunan Sadap',
        'Bangunan Pelengkap',
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _selectedKategori = v as String),
    );
  }

  Widget _kondisiDropdown() {
    return DropdownButtonFormField(
      value: _selectedKondisiAset,
      decoration: const InputDecoration(
        labelText: "Kondisi Fisik",
        border: OutlineInputBorder(),
      ),
      items: [
        'Baik',
        'Rusak Ringan',
        'Rusak Berat',
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _selectedKondisiAset = v as String),
    );
  }

  Widget _dimensiRow() {
    return Row(
      children: [
        Expanded(
          child: _myTextField(_lebarController, "Lebar (m)", Icons.straighten),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _myTextField(_tinggiController, "Tinggi (m)", Icons.height),
        ),
      ],
    );
  }

  Widget _locationBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Lat: ${_lat?.toStringAsFixed(6) ?? '-'}",
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              Text(
                "Lng: ${_lng?.toStringAsFixed(6) ?? '-'}",
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _getLocation,
            icon: const Icon(Icons.gps_fixed),
            label: const Text("Ambil Titik"),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange[900],
          ),
        ),
      ),
    );
  }
}
