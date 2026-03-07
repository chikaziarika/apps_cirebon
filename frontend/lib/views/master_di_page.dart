import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MasterDiPage extends StatefulWidget {
  const MasterDiPage({super.key});

  @override
  State<MasterDiPage> createState() => _MasterDiPageState();
}

class _MasterDiPageState extends State<MasterDiPage> {
  List<Map<String, dynamic>> _allDI = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _refreshData();
  }

  void _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    bool isAdminMemori = prefs.getBool('is_admin') ?? false;

    setState(() {
      _isAdmin = isAdminMemori;
    });

    print("DEBUG: Status Admin di Master DI adalah -> $_isAdmin");
  }

  void _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Ambil nilai is_admin yang kita simpan saat login
      _isAdmin = prefs.getBool('is_admin') ?? false;
    });
  }

  // Ambil data terbaru dari Database
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseService().getAllDIFull();
    setState(() {
      _allDI = data;
      _isLoading = false;
    });
  }

  Future<void> _syncUnsyncedDI() async {
    setState(() => _isLoading = true);
    final db = DatabaseService();
    final allData = await db.getAllDIFull();

    // Ambil yang status_sync-nya 0
    final unsynced = allData.where((e) => e['status_sync'] == 0).toList();

    if (unsynced.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua data sudah sinkron (Aman!)")),
      );
      return;
    }

    for (var item in unsynced) {
      try {
        final response = await ApiService().syncDaerahIrigasi(item);
        if (response != null) {
          // Update ID lokal dengan ID dari server
          await db.updateDI(item['id'], {
            'id': response['id'],
            'status_sync': 1,
          });
        }
      } catch (e) {
        debugPrint("Gagal sinkron: $e");
      }
    }

    _refreshData(); // Refresh list biar status_sync-nya update di tampilan
    setState(() => _isLoading = false);
  }

  // Dialog Tambah & Edit
  void _showForm(Map<String, dynamic>? data) {
    final kodeCtrl = TextEditingController(text: data?['kode_di'] ?? "");
    final namaCtrl = TextEditingController(text: data?['nama_di'] ?? "");
    final bendungCtrl = TextEditingController(text: data?['bendung'] ?? "");
    final sumberAirCtrl = TextEditingController(
      text: data?['sumber_air'] ?? "",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data == null ? "Tambah Daerah Irigasi" : "Edit Daerah Irigasi",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: kodeCtrl,
                decoration: const InputDecoration(
                  labelText: "Kode D.I.",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: "Nama D.I.",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bendungCtrl,
                decoration: const InputDecoration(
                  labelText: "Nama Bendung",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sumberAirCtrl,
                decoration: const InputDecoration(
                  labelText: "Sumber Air",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(15),
                    backgroundColor: Colors.blueAccent,
                  ),
                  onPressed: () async {
                    if (namaCtrl.text.isEmpty) return;

                    final payload = {
                      'kode_di': kodeCtrl.text,
                      'nama_di': namaCtrl.text,
                      'bendung': bendungCtrl.text,
                      'sumber_air': sumberAirCtrl.text,
                      'status_sync': 0,
                    };

                    if (data == null) {
                      await DatabaseService().insertDIFull(payload);
                    } else {
                      await DatabaseService().updateDI(data['id'], payload);
                    }

                    if (!mounted) return;
                    Navigator.pop(context);
                    _refreshData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Data Berhasil Disimpan")),
                    );
                  },
                  child: Text(
                    data == null ? "SIMPAN BARU" : "UPDATE DATA",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pullDataFromServer() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil data dari server
      final List<dynamic> dataServer = await ApiService().fetchDaerahIrigasi();

      // 2. Bersihkan total database lokal HP
      final db = DatabaseService();
      await db.clearAllDI(); // Menghapus ID 910 dan kawan-kawannya

      // 3. Masukkan data segar (ID 899, 900, 901, 902)
      for (var di in dataServer) {
        await db.insertDIFull({
          'id': di['id'],
          'kode_di': di['kode_di'],
          'nama_di': di['nama_di'],
          'bendung': di['bendung'],
          'sumber_air': di['sumber_air'],
          'status_sync': 1,
        });
      }

      _refreshData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sinkronisasi Berhasil!")));
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDeleteDialog(dynamic id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Data?"),
        content: const Text("Data D.I. ini akan dihapus permanen dari HP."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().deleteDI(id);
      _refreshData(); // Refresh list setelah hapus
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data berhasil dihapus")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Master Daerah Irigasi"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _pullDataFromServer, // Panggil fungsi tarik data
            tooltip: "Tarik data dari server",
          ),
          IconButton(
            icon: const Icon(
              Icons.cloud_upload,
              color: Colors.yellowAccent,
            ), // Kasih warna beda biar mencolok
            onPressed:
                _syncUnsyncedDI, // Pastikan nama fungsinya sama dengan yang kita buat tadi
            tooltip: "Sinkronkan DI Baru ke server",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allDI.isEmpty
          ? const Center(child: Text("Belum ada data D.I."))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _allDI.length,
              itemBuilder: (context, index) {
                final item = _allDI[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.water_drop, color: Colors.blue),
                    ),
                    title: Text(
                      item['nama_di'] ?? "-",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Kode: ${item['kode_di'] ?? '-'}\nBendung: ${item['bendung'] ?? '-'}",
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showForm(item),
                        ),
                        if (_isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteDialog(
                              item['id'],
                            ), // Panggil fungsi di atas
                          ),
                        // if (_isAdmin)
                        //   IconButton(
                        //     icon: const Icon(Icons.delete, color: Colors.red),
                        //     onPressed: () async {
                        //       bool? confirm = await showDialog(
                        //         context: context,
                        //         builder: (ctx) => AlertDialog(
                        //           title: const Text("Hapus Data?"),
                        //           content: const Text(
                        //             "Data D.I. ini akan dihapus permanen.",
                        //           ),
                        //           actions: [
                        //             TextButton(
                        //               onPressed: () =>
                        //                   Navigator.pop(ctx, false),
                        //               child: const Text("Batal"),
                        //             ),
                        //             TextButton(
                        //               onPressed: () => Navigator.pop(ctx, true),
                        //               child: const Text(
                        //                 "Hapus",
                        //                 style: TextStyle(color: Colors.red),
                        //               ),
                        //             ),
                        //           ],
                        //         ),
                        //       );
                        //       if (confirm == true) {
                        //         await DatabaseService().deleteDI(item['id']);
                        //         _refreshData();
                        //       }
                        //     },
                        //   ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(null),
              label: const Text("Tambah D.I."),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.blueAccent,
            )
          : null,
    );
  }
}
