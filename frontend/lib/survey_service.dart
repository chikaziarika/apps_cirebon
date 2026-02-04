import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'survey_service.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _kondisiController = TextEditingController();
  File? _imageFile;
  int _offlineCount = 0; // Untuk indikator data yang belum terkirim

  @override
  void initState() {
    super.initState();
    _updateOfflineCount();
  }

  // Fungsi cek jumlah data di SQLite
  Future<void> _updateOfflineCount() async {
    final db = await SurveyService().database;
    final List<Map<String, dynamic>> maps = await db.query('surveys');
    setState(() {
      _offlineCount = maps.length;
    });
  }

  Future<void> _ambilFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _handleSimpan() async {
    if (_imageFile == null || _lokasiController.text.isEmpty) {
      _showSnackBar("Foto dan Lokasi wajib diisi!", Colors.red);
      return;
    }

    // Tampilkan Loading
    showDialog(context: context, builder: (res) => const Center(child: CircularProgressIndicator()));

    // Simulasi Lat/Lng (Ganti dengan Geolocator asli nanti)
    double lat = -6.7; 
    double lng = 108.5;

    bool sukses = await SurveyService().prosesInputSurvey(
      lokasi: _lokasiController.text,
      kondisi: _kondisiController.text,
      lat: lat,
      lng: lng,
      foto: _imageFile!,
    );

    Navigator.pop(context); // Tutup loading

    if (sukses) {
      _showSnackBar("✅ Terkirim ke PostgreSQL", Colors.green);
      _lokasiController.clear();
      _kondisiController.clear();
      setState(() => _imageFile = null);
    } else {
      _showSnackBar("📦 Tersimpan sebagai Draft Offline", Colors.orange);
    }
    _updateOfflineCount();
  }

  void _showSnackBar(String pesan, Color warna) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Irigasi"),
        actions: [
          // Tombol Sinkronisasi di AppBar
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () async {
                  await SurveyService().sinkronkanData();
                  _updateOfflineCount();
                  _showSnackBar("Sinkronisasi Selesai", Colors.blue);
                },
              ),
              if (_offlineCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: CircleAvatar(
                    radius: 8, backgroundColor: Colors.red,
                    child: Text(_offlineCount.toString(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                )
            ],
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Preview Foto
            GestureDetector(
              onTap: _ambilFoto,
              child: Container(
                height: 200, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey)),
                child: _imageFile == null 
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50), Text("Tap untuk ambil foto")])
                  : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.with(file: _imageFile!, fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _lokasiController, decoration: const InputDecoration(labelText: "Nama Lokasi/Bangunan", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _kondisiController, maxLines: 3, decoration: const InputDecoration(labelText: "Kondisi (Catatan)", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _handleSimpan,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text("KIRIM DATA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}