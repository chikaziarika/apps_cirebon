import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class FormSaluranPage extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const FormSaluranPage({super.key, this.editData});

  @override
  State<FormSaluranPage> createState() => _FormSaluranPageState();
}

class _FormSaluranPageState extends State<FormSaluranPage> {
  final TextEditingController _namaSaluranController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();

  String _jenisKonstruksi = 'Tanah';
  double? _lat, _lng;
  bool _isLoadingGps = false;
  String? _selectedDI;
  List<Map<String, dynamic>> _diList = [];
  bool _isSyncingDI = false; // Untuk kontrol loading spinner
  String _selectedKondisi = 'Baik';

  @override
  void initState() {
    super.initState();
    _loadDI();
    if (widget.editData != null) {
      _namaSaluranController.text = widget.editData!['nama_saluran'] ?? '';
      _lebarController.text = (widget.editData!['lebar'] ?? 0).toString();
      _tinggiController.text = (widget.editData!['tinggi'] ?? 0).toString();
      _jenisKonstruksi = widget.editData!['jenis_konstruksi'] ?? 'Tanah';
      _lat = widget.editData!['lat'];
      _lng = widget.editData!['lng'];
      // Jika ada data DI lama, set ke dropdown
      _selectedDI = widget.editData!['nama_di'];
    }
  }

  Future<void> _loadDI() async {
    final list = await DatabaseService().getAllDI();
    setState(() {
      _diList = list;
    });
  }

  Future<void> _syncDIFromServer() async {
    setState(() => _isSyncingDI = true); // Munculkan Loading
    try {
      final api = ApiService();
      final db = DatabaseService();
      final data = await api.fetchDaerahIrigasi();

      for (var di in data) {
        await db.insertDI(di['nama_di']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Daftar D.I. berhasil diperbarui!")),
      );
      _loadDI();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal tarik data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncingDI = false); // Hilangkan Loading
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _isLoadingGps = false;
      });
    } catch (e) {
      setState(() => _isLoadingGps = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengambil GPS.")));
    }
  }

  Future<void> _handleSave() async {
    if (_namaSaluranController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama saluran tidak boleh kosong!")),
      );
      return;
    }

    Map<String, dynamic> data = {
      'nama_di': _selectedDI,
      'nama_saluran': _namaSaluranController.text,
      'jenis_konstruksi': _jenisKonstruksi,
      'kondisi': _selectedKondisi, // <--- Sesuaikan nama variabelnya di sini
      'lebar': double.tryParse(_lebarController.text) ?? 0,
      'tinggi': double.tryParse(_tinggiController.text) ?? 0,
      'lat': _lat,
      'lng': _lng,
      'status_sync': 0,
    };

    final db = DatabaseService();
    if (widget.editData != null) {
      final dbClient = await db.database;
      await dbClient.update(
        'saluran',
        data,
        where: 'id = ?',
        whereArgs: [widget.editData!['id']],
      );
    } else {
      await db.insertSaluran(data);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showAddDIDialog() {
    TextEditingController diController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Daerah Irigasi"),
        content: TextField(
          controller: diController,
          decoration: const InputDecoration(hintText: "Contoh: DI. CIWADO"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (diController.text.isNotEmpty) {
                await DatabaseService().insertDI(
                  diController.text.toUpperCase(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                _loadDI();
              }
            },
            child: const Text("SIMPAN"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Input Data Saluran"),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Stack(
        // Gunakan Stack untuk overlay loading
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BAGIAN PILIH DI
                const Text(
                  "Daerah Irigasi",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDI,
                        hint: const Text("Pilih D.I."),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _diList
                            .map(
                              (di) => DropdownMenuItem(
                                value: di['nama_di'].toString(),
                                child: Text(di['nama_di']),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _selectedDI = val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cloud_download,
                        color: Colors.green,
                      ),
                      onPressed: _isSyncingDI ? null : _syncDIFromServer,
                      tooltip: "Tarik data dari pusat",
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: _showAddDIDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Informasi Ruas Saluran",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _namaSaluranController,
                  decoration: const InputDecoration(
                    labelText: "Nama Saluran",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.water),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField(
                  value: _jenisKonstruksi,
                  decoration: const InputDecoration(
                    labelText: "Jenis Konstruksi",
                    border: OutlineInputBorder(),
                  ),
                  items: ['Tanah', 'Pasangan Batu', 'Beton', 'Lainnya']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _jenisKonstruksi = v as String),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lebarController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Lebar (m)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _tinggiController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Tinggi (m)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                const Text(
                  "Lokasi Geografis",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Lat: ${_lat?.toStringAsFixed(6) ?? '-'}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            "Lng: ${_lng?.toStringAsFixed(6) ?? '-'}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoadingGps ? null : _getLocation,
                        icon: const Icon(Icons.my_location, size: 18),
                        label: Text(
                          _isLoadingGps ? "Mencari..." : "Ambil Titik",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _handleSave,
                  child: const Text(
                    "SIMPAN DATA SALURAN",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LOADING SPINNER OVERLAY
          if (_isSyncingDI)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 15),
                        Text(
                          "Menarik Data D.I...",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Mohon tunggu sebentar",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
