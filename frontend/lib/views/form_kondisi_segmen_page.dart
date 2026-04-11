import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FormKondisiSegmenPage extends StatefulWidget {
  final String kondisiSaatIni;
  final double jarakDitempuh;

  const FormKondisiSegmenPage({
    super.key, 
    required this.kondisiSaatIni,
    required this.jarakDitempuh,
  });

  @override
  State<FormKondisiSegmenPage> createState() => _FormKondisiSegmenPageState();
}

class _FormKondisiSegmenPageState extends State<FormKondisiSegmenPage> {
  late String _kondisiBaru;
  final TextEditingController _ketCtrl = TextEditingController();
  final TextEditingController _lebarCtrl = TextEditingController(text: "0");
  final TextEditingController _tinggiCtrl = TextEditingController(text: "0");
  
  List<File?> _fotos = List.filled(5, null);

  @override
  void initState() {
    super.initState();
    _kondisiBaru = widget.kondisiSaatIni;
  }

  @override
  void dispose() {
    _ketCtrl.dispose();
    _lebarCtrl.dispose();
    _tinggiCtrl.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto(int index) async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 30, // Kompresi agar ringan
    );
    if (image != null) {
      setState(() => _fotos[index] = File(image.path));
    }
  }

  void _simpanSegmen() {
    if (!_fotos.any((f) => f != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wajib lampirkan minimal 1 foto segmen!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }
    List<String> fotoPaths = _fotos.where((f) => f != null).map((f) => f!.path).toList();
    Navigator.pop(context, {
      'keterangan': _ketCtrl.text,
      'lebar': double.tryParse(_lebarCtrl.text) ?? 0.0,
      'tinggi': double.tryParse(_tinggiCtrl.text) ?? 0.0,
      'fotos': fotoPaths,
      'kondisi_baru': _kondisiBaru, // Untuk melanjutkan segmen berikutnya
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Detail Segmen Saluran", style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Informasi Segmen Saluran:", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 5),
                  Text("Kondisi: ${widget.kondisiSaatIni}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Panjang: ${widget.jarakDitempuh.toStringAsFixed(2)} Meter"),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("Kondisi Segmen:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _kondisiBaru,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.route)),
              items: const [
                DropdownMenuItem(value: "BAIK", child: Text("BAIK (B)")),
                DropdownMenuItem(value: "RR", child: Text("RUSAK RINGAN (RR)")),
                DropdownMenuItem(value: "RB", child: Text("RUSAK BERAT (RB)")),
                DropdownMenuItem(value: "BAP", child: Text("BAP")),
              ],
              onChanged: (v) => setState(() => _kondisiBaru = v!),
            ),
            const SizedBox(height: 30),
            const Text("Dimensi Segmen (Meter):", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lebarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Lebar (m)", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _tinggiCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: "Tinggi/Kedalaman (m)", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ketCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Keterangan Kondisi", hintText: "Catatan surveyor...", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const Text("Dokumentasi Lapangan (Maks 5):", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => _ambilFoto(i),
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
            const Divider(height: 40, thickness: 1),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _simpanSegmen,
                icon: const Icon(Icons.save),
                label: const Text("SIMPAN SEGMEN", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}