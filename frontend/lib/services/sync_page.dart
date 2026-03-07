import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../views/survey_saluran_page.dart'; // Pastikan import ke FormBangunanDetail benar
import 'dart:io';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  List<Map<String, dynamic>> _pendingData = [];
  bool _isLoading = true;
  List<int> _selectedSaluranIds = [];
  List<int> _selectedBangunanIds = [];

  @override
  void initState() {
    super.initState();
    _loadPendingData();
  }

  // --- LOGIKA LOAD DATA HIRARKI ---
  Future<void> _loadPendingData() async {
    setState(() => _isLoading = true);
    final db = DatabaseService();
    final dbClient = await db.database;

    final List<Map<String, dynamic>> saluranList = await dbClient.query(
      'saluran',
      where: 'status_sync = ?',
      whereArgs: [0],
    );
    final List<Map<String, dynamic>> bangunanList = await db
        .getUnsyncedSurveys();

    List<Map<String, dynamic>> groupedData = [];

    for (var saluran in saluranList) {
      List<Map<String, dynamic>> anakBangunan = bangunanList
          .where((b) => b['nama_saluran'] == saluran['nama_saluran'])
          .toList();

      groupedData.add({
        'type': 'saluran',
        'data': saluran,
        'bangunans': anakBangunan,
        'isExpanded': true,
      });
    }

    final saluranNames = saluranList.map((s) => s['nama_saluran']).toSet();
    final orphanBangunans = bangunanList
        .where((b) => !saluranNames.contains(b['nama_saluran']))
        .toList();

    if (orphanBangunans.isNotEmpty) {
      groupedData.add({
        'type': 'orphan',
        'data': {'nama_saluran': 'Bangunan Tanpa Induk Saluran'},
        'bangunans': orphanBangunans,
        'isExpanded': true,
      });
    }

    setState(() {
      _pendingData = groupedData;
      _isLoading = false;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      // Cek apakah semua sudah terpilih
      bool isAllSelected =
          _selectedSaluranIds.length ==
          _pendingData.where((g) => g['type'] == 'saluran').length;

      if (isAllSelected) {
        _selectedSaluranIds.clear();
        _selectedBangunanIds.clear();
      } else {
        _selectedSaluranIds = [];
        _selectedBangunanIds = [];
        for (var group in _pendingData) {
          if (group['type'] == 'saluran') {
            _selectedSaluranIds.add(group['data']['id']);
          }
          for (var b in group['bangunans']) {
            _selectedBangunanIds.add(b['id']);
          }
        }
      }
    });
  }

  // --- FITUR EDIT ---
  void _editBangunan(Map<String, dynamic> dataLama) async {
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormBangunanDetail(
          diId: dataLama['di_id'],
          namaDI: dataLama['nama_di'] ?? "D.I. Garut",
          namaSaluran: dataLama['nama_saluran'],
          lat: dataLama['lat'],
          lng: dataLama['lng'],
          jarakAntarRuas: dataLama['jarak_dari_hulu'] ?? 0.0,
          bangunanChoices: const [
            {'code': 'B01', 'name': 'B01 - Bendung'},
            {'code': 'P01', 'name': 'P01 - Bagi'},
            {'code': 'P02', 'name': 'P02 - Bagi Sadap'},
            {'code': 'P03', 'name': 'P03 - Sadap'},
            {'code': 'C03', 'name': 'C03 - Gorong-gorong'},
          ],
        ),
      ),
    );

    if (result != null) {
      await DatabaseService().updateSurvey(dataLama['id'], result);
      _loadPendingData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data diperbarui!")));
    }
  }

  Future<void> _hapusDataTerpilih() async {
    if (_selectedSaluranIds.isEmpty && _selectedBangunanIds.isEmpty) return;

    // Konfirmasi dulu Pak biar nggak salah hapus
    bool? konfirmasi = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Terpilih?"),
        content: Text(
          "Anda akan menghapus ${_selectedSaluranIds.length} saluran dan ${_selectedBangunanIds.length} bangunan secara permanen.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "HAPUS SEMUA",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      setState(() => _isLoading = true);
      final db = DatabaseService();
      final dbClient = await db.database;

      // Hapus Saluran yang dicentang
      for (int id in _selectedSaluranIds) {
        await dbClient.delete('saluran', where: 'id = ?', whereArgs: [id]);
      }

      // Hapus Bangunan yang dicentang
      for (int id in _selectedBangunanIds) {
        await dbClient.delete('surveys', where: 'id = ?', whereArgs: [id]);
      }

      // Bersihkan daftar pilihan
      _selectedSaluranIds.clear();
      _selectedBangunanIds.clear();

      await _loadPendingData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data terpilih berhasil dihapus")),
        );
      }
    }
  }

  Future<void> _prosesSinkronisasiMassal() async {
    setState(() => _isLoading = true);
    int suksesCount = 0;
    int gagalCount = 0;

    try {
      for (var group in _pendingData) {
        final listBangunan = group['bangunans'] as List<Map<String, dynamic>>;

        // --- LOGIKA 1: PROSES SALURAN (INDUK) ---
        if (group['type'] == 'saluran') {
          final dataSaluran = Map<String, dynamic>.from(group['data']);

          // HANYA PROSES JIKA SALURAN DICENTANG
          if (_selectedSaluranIds.contains(dataSaluran['id'])) {
            String userName = dataSaluran['surveyor'] ?? "Admin";
            dataSaluran['surveyor'] = userName;

            bool saluranOk = await ApiService().syncSaluran(dataSaluran);
            if (saluranOk) {
              await DatabaseService().markSaluranAsSynced(dataSaluran['id']);
              suksesCount++;
            } else {
              gagalCount++;
            }
          }
        }

        // --- LOGIKA 2: PROSES BANGUNAN (ANAK / ORPHAN) ---
        for (var b in listBangunan) {
          // HANYA PROSES JIKA BANGUNAN DICENTANG
          if (_selectedBangunanIds.contains(b['id'])) {
            var dataB = Map<String, dynamic>.from(b);
            // Ambil nama surveyor dari induknya jika ada, atau dari datanya sendiri
            dataB['surveyor'] =
                group['data']['surveyor'] ?? dataB['surveyor'] ?? "Admin";

            bool bangunanOk = await ApiService().syncBangunan(dataB);
            if (bangunanOk) {
              await DatabaseService().markSurveyAsSynced(b['id']);
              suksesCount++;
            } else {
              gagalCount++;
            }
          }
        }
      }

      // Reset pilihan setelah selesai sinkron
      _selectedSaluranIds.clear();
      _selectedBangunanIds.clear();

      await _loadPendingData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Sinkronisasi Selesai! Berhasil: $suksesCount, Gagal: $gagalCount",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("🔴 ERROR SYNC: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _lihatDetail(Map<String, dynamic> data, String tipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tipe == 'saluran' ? "Detail Saluran" : "Detail Bangunan",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const Divider(),
              if (tipe == 'saluran') ...[
                _rowDetail("Nama Saluran", data['nama_saluran']),
                _rowDetail("DI", data['nama_di']),
                _rowDetail("Tingkat Jaringan", data['tingkat_jaringan']),
                _rowDetail("Kewenangan", data['kewenangan']),
                _rowDetail(
                  "Panjang",
                  "${data['panjang_saluran']?.toStringAsFixed(2)} m",
                ),
              ] else ...[
                _rowDetail("Nama Bangunan", data['nama_bangunan']),
                _rowDetail("Kode Aset", data['kode_aset']),
                _rowDetail(
                  "Desa/Kec",
                  "${data['desa']} / ${data['kecamatan']}",
                ),
                _rowDetail(
                  "Kondisi Pintu B/RR/RB",
                  "${data['pintu_baik']} / ${data['pintu_rr']} / ${data['pintu_rb']}",
                ),
                _rowDetail("Keterangan", data['keterangan'] ?? "-"),
              ],
              const SizedBox(height: 20),
              _rowDetail("Surveyor", data['surveyor'] ?? "admin"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value ?? "-",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String table, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Data?"),
        content: const Text("Data yang dihapus tidak bisa dikembalikan Pak."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final db = await DatabaseService().database;
              await db.delete(table, where: 'id = ?', whereArgs: [id]);
              Navigator.pop(context);
              _loadPendingData();
            },
            child: const Text("HAPUS", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- TAMPILAN UTAMA (CUMA ADA SATU BUILD) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Antrean Sinkronisasi"),
        backgroundColor: Colors.purple,
        actions: [
          // TOMBOL HAPUS TERPILIH (Hanya muncul kalau ada yang dicentang)
          if (_selectedSaluranIds.isNotEmpty || _selectedBangunanIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _hapusDataTerpilih,
              tooltip: "Hapus Terpilih",
            ),
          if (_pendingData.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selectedSaluranIds.length ==
                        _pendingData.where((g) => g['type'] == 'saluran').length
                    ? "DESELECT ALL"
                    : "SELECT ALL",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Panel Info yang muncul saat ada data terpilih
                if (_selectedSaluranIds.isNotEmpty ||
                    _selectedBangunanIds.isNotEmpty)
                  Container(
                    color: Colors.purple.shade50,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 15,
                    ),
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_selectedSaluranIds.length} Saluran & ${_selectedBangunanIds.length} Bangunan terpilih",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _pendingData.isEmpty
                      ? const Center(child: Text("Antrean Kosong"))
                      : ListView.builder(
                          itemCount: _pendingData.length,
                          itemBuilder: (context, index) {
                            final group = _pendingData[index];
                            final saluran = group['data'];
                            final listBangunan =
                                group['bangunans']
                                    as List<Map<String, dynamic>>;
                            final bool isSaluranSelected = _selectedSaluranIds
                                .contains(saluran['id']);

                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ExpansionTile(
                                initiallyExpanded: group['isExpanded'],
                                // CHECKBOX UNTUK SALURAN (INDUK)
                                leading: Checkbox(
                                  value: isSaluranSelected,
                                  activeColor: Colors.purple,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedSaluranIds.add(saluran['id']);
                                        for (var b in listBangunan) {
                                          if (!_selectedBangunanIds.contains(
                                            b['id'],
                                          )) {
                                            _selectedBangunanIds.add(b['id']);
                                          }
                                        }
                                      } else {
                                        _selectedSaluranIds.remove(
                                          saluran['id'],
                                        );
                                        for (var b in listBangunan) {
                                          _selectedBangunanIds.remove(b['id']);
                                        }
                                      }
                                    });
                                  },
                                ),
                                title: Text(
                                  saluran['nama_saluran'] ?? "Saluran",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "Surveyor: ${saluran['surveyor'] ?? 'admin'} | ${listBangunan.length} Bangunan",
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmDelete(
                                    'saluran',
                                    saluran['id'] ?? 0,
                                  ),
                                ),
                                children: listBangunan
                                    .map((b) => _buildBangunanTile(b))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(15),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            padding: const EdgeInsets.all(15),
            disabledBackgroundColor: Colors.grey,
          ),
          // Tombol hanya aktif jika ada yang dipilih
          onPressed:
              (_selectedSaluranIds.isEmpty && _selectedBangunanIds.isEmpty) ||
                  _isLoading
              ? null
              : () => _prosesSinkronisasiMassal(),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  "SINKRONKAN DATA TERPILIH (${_selectedSaluranIds.length + _selectedBangunanIds.length})",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBangunanTile(Map<String, dynamic> b) {
    final bool isSelected = _selectedBangunanIds.contains(b['id']);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 10),
      // CHECKBOX UNTUK BANGUNAN (ANAK)
      leading: Checkbox(
        value: isSelected,
        activeColor: Colors.orange,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _selectedBangunanIds.add(b['id']);
            } else {
              _selectedBangunanIds.remove(b['id']);
            }
          });
        },
      ),
      title: Text(b['nama_bangunan'] ?? "Bangunan"),
      subtitle: Text("Kode: ${b['kode_aset']} | Desa: ${b['desa']}"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blue, size: 20),
            onPressed: () => _lihatDetail(b, 'bangunan'),
          ),
          // 2. EDIT BANGUNAN
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.green, size: 20),
            onPressed: () => _editBangunan(b),
          ),
          // 3. HAPUS SATU BANGUNAN
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmDelete('surveys', b['id']),
          ),
        ],
      ),
    );
  }

  Widget _boxKondisi(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 5, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
