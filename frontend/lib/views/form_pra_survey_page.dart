import 'package:flutter/material.dart';
import 'survey_saluran_page.dart';
import '../services/database_service.dart';

class FormPraSurveyPage extends StatefulWidget {
  const FormPraSurveyPage({super.key});

  @override
  State<FormPraSurveyPage> createState() => _FormPraSurveyPageState();
}

class _FormPraSurveyPageState extends State<FormPraSurveyPage> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedDIId;
  final TextEditingController _namaSaluranCtrl = TextEditingController();
  String? _tingkatJaringan;
  String? _jenisSaluran;
  String? _kewenangan = "Kabupaten";

  List<Map<String, dynamic>> _listDI = [];
  bool _isLoadingDI = true;

  final List<String> _listTingkat = ['Teknis', 'Semi Teknis', 'Non Teknis'];
  final List<Map<String, String>> _listJenis = [
    {'code': 'S01', 'name': 'S01 - Saluran Primer'},
    {'code': 'S02', 'name': 'S02 - Saluran Sekunder'},
    {'code': 'S15', 'name': 'S15 - Saluran Tersier'},
    {'code': 'S17', 'name': 'S17 - Saluran Pembuang (Tersier)'},
  ];
  final List<String> _listKewenangan = ['Pusat', 'Provinsi', 'Kabupaten'];

  @override
  void initState() {
    super.initState();
    _loadDataDI();
  }

  Future<void> _loadDataDI() async {
    final db = DatabaseService();
    final dbClient = await db.database;
    final List<Map<String, dynamic>> rawData = await dbClient.query('daerah_irigasi');
    final Map<int, Map<String, dynamic>> uniqueData = {};
    for (var item in rawData) {
      if (item['id'] != null) {
        uniqueData[item['id'] as int] = item; // Menyimpan berdasarkan ID unik
      }
    }

    setState(() {
      _listDI = uniqueData.values.toList(); // Masukkan data yang sudah bersih ke list
      _isLoadingDI = false;
    });
  }

  void _mulaiSurvey() {
    if (_formKey.currentState!.validate()) {
      final selectedDIMap = _listDI.firstWhere((di) => di['id'] == _selectedDIId);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SurveySaluranPage(
            dataDI: selectedDIMap, // Lempar Map Utuh ke halaman peta
            namaSaluran: _namaSaluranCtrl.text,
            tingkatJaringan: _tingkatJaringan!,
            jenisSaluran: _jenisSaluran!,
            kewenangan: _kewenangan!,
          ),
        ),
      );
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Persiapan Survey"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingDI 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Lengkapi Data Saluran",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: "Pilih Daerah Irigasi (D.I.)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
                value: _selectedDIId,
                items: _listDI.map((di) => DropdownMenuItem<int>(
                  value: di['id'] as int, 
                  child: Text(di['nama_di'] ?? "Tanpa Nama", overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (val) => setState(() => _selectedDIId = val),
                validator: (val) => val == null ? "D.I. wajib dipilih" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _namaSaluranCtrl,
                decoration: const InputDecoration(
                  labelText: "Nama Saluran",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_road),
                ),
                validator: (val) => val == null || val.isEmpty ? "Nama saluran wajib diisi" : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Tingkat Jaringan",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                value: _tingkatJaringan,
                items: _listTingkat.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _tingkatJaringan = val),
                validator: (val) => val == null ? "Pilih tingkat jaringan" : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Jenis Saluran (Kode Aset)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                value: _jenisSaluran,
                items: _listJenis.map((j) => DropdownMenuItem(
                  value: j['code'], 
                  child: Text(j['name']!),
                )).toList(),
                onChanged: (val) => setState(() => _jenisSaluran = val),
                validator: (val) => val == null ? "Pilih jenis saluran" : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Kewenangan",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                value: _kewenangan,
                items: _listKewenangan.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setState(() => _kewenangan = val),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("MULAI SURVEY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _mulaiSurvey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}