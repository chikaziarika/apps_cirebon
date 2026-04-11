import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../views/form_input_bangunan.dart';

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

  Future<void> _loadPendingData() async {
    setState(() => _isLoading = true);
    final db = DatabaseService();
    final dbClient = await db.database;

    final List<Map<String, dynamic>> saluranList = await dbClient.query('saluran', where: 'status_sync = ?', whereArgs: [0]);
    final List<Map<String, dynamic>> bangunanList = await db.getUnsyncedSurveys();

    List<Map<String, dynamic>> groupedData = [];

    for (var saluran in saluranList) {
      List<Map<String, dynamic>> anakBangunan = bangunanList.where((b) => b['nama_saluran'] == saluran['nama_saluran']).toList();

      groupedData.add({
        'type': 'saluran',
        'data': saluran,
        'bangunans': anakBangunan,
        'isExpanded': true,
      });
    }

    final saluranNames = saluranList.map((s) => s['nama_saluran']).toSet();
    final orphanBangunans = bangunanList.where((b) => !saluranNames.contains(b['nama_saluran'])).toList();

    if (orphanBangunans.isNotEmpty) {
      groupedData.add({
        'type': 'orphan',
        'data': {'nama_saluran': 'Bangunan Ekstra (Tanpa Induk Saluran Baru)'},
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
      bool isAllSelected = _selectedSaluranIds.length == _pendingData.where((g) => g['type'] == 'saluran').length;
      _selectedSaluranIds.clear();
      _selectedBangunanIds.clear();

      if (!isAllSelected) {
        for (var group in _pendingData) {
          if (group['type'] == 'saluran') {
            int? sId = int.tryParse(group['data']['id']?.toString() ?? "");
            if (sId != null) _selectedSaluranIds.add(sId);
          }
          for (var b in group['bangunans']) {
            int? bId = int.tryParse(b['id']?.toString() ?? "");
            if (bId != null) _selectedBangunanIds.add(bId);
          }
        }
      }
    });
  }

  void _editBangunan(Map<String, dynamic> dataLama) async {
    int diId = int.tryParse(dataLama['di_id']?.toString() ?? "0") ?? 0;
    final dbClient = await DatabaseService().database;
    final List<Map<String, dynamic>> opsiHulu = await dbClient.query('surveys', where: 'di_id = ?', whereArgs: [diId]);

    if (!mounted) return;

    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormBangunanPage(
          editData: dataLama,
          diId: diId,
          namaDI: dataLama['nama_di'] ?? "D.I.",
          namaSaluran: dataLama['nama_saluran'] ?? "Saluran",
          lat: double.tryParse(dataLama['lat']?.toString() ?? "0") ?? 0.0,
          lng: double.tryParse(dataLama['lng']?.toString() ?? "0") ?? 0.0,
          jarakDariHulu: double.tryParse(dataLama['jarak_dari_hulu']?.toString() ?? "0") ?? 0.0,
          listBangunanHulu: opsiHulu,
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
      _loadPendingData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data bangunan diperbarui!")));
    }
  }

  Future<void> _hapusDataTerpilih() async {
    if (_selectedSaluranIds.isEmpty && _selectedBangunanIds.isEmpty) return;

    bool? konfirmasi = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Permanen?"),
        content: Text("Menghapus ${_selectedSaluranIds.length} saluran dan ${_selectedBangunanIds.length} bangunan dari memori HP."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("BATAL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("HAPUS", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      setState(() => _isLoading = true);
      final dbClient = await DatabaseService().database;

      for (int id in _selectedSaluranIds) await dbClient.delete('saluran', where: 'id = ?', whereArgs: [id]);
      for (int id in _selectedBangunanIds) await dbClient.delete('surveys', where: 'id = ?', whereArgs: [id]);

      _selectedSaluranIds.clear();
      _selectedBangunanIds.clear();

      await _loadPendingData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data terpilih berhasil dihapus")));
    }
  }

  Future<void> _prosesSinkronisasiMassal() async {
    setState(() => _isLoading = true);
    int suksesCount = 0, gagalCount = 0;

    try {
      for (var group in _pendingData) {
        final listBangunan = group['bangunans'] as List<Map<String, dynamic>>;

        // SINKRON SALURAN
        if (group['type'] == 'saluran') {
          final dataSaluran = Map<String, dynamic>.from(group['data']);
          int idSaluran = int.tryParse(dataSaluran['id']?.toString() ?? "0") ?? 0;

          if (_selectedSaluranIds.contains(idSaluran)) {
            dataSaluran['surveyor'] = dataSaluran['surveyor'] ?? "Admin";
            bool saluranOk = await ApiService().syncSaluran(dataSaluran);
            if (saluranOk) {
              await DatabaseService().markSaluranAsSynced(idSaluran);
              suksesCount++;
            } else {
              gagalCount++;
            }
          }
        }

        // SINKRON BANGUNAN
        for (var b in listBangunan) {
          int idBangunan = int.tryParse(b['id']?.toString() ?? "0") ?? 0;
          if (_selectedBangunanIds.contains(idBangunan)) {
            var dataB = Map<String, dynamic>.from(b);
            dataB['surveyor'] = group['data']['surveyor'] ?? dataB['surveyor'] ?? "Admin";

            bool bangunanOk = await ApiService().syncBangunan(dataB);
            if (bangunanOk) {
              await DatabaseService().markSurveyAsSynced(idBangunan);
              suksesCount++;
            } else {
              gagalCount++;
            }
          }
        }
      }

      _selectedSaluranIds.clear();
      _selectedBangunanIds.clear();
      await _loadPendingData();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Selesai! Berhasil: $suksesCount, Gagal: $gagalCount")));
    } catch (e) {
      debugPrint("🔴 ERROR SYNC: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getRangkumanSaluran(Map<String, dynamic> saluran) {
    double pBaik = 0, pRR = 0, pRB = 0, pBAP = 0;
    List<String> fotoSaluran = [];

    try {
      if (saluran['path_kondisi'] != null && saluran['path_kondisi'].toString().length > 10) {
        String rawJson = saluran['path_kondisi'].toString();
        
        // ---- TAMBAHKAN BARIS PRINT INI ----
        debugPrint("🔍 ISI JSON ASLI DARI SQLITE: $rawJson");
        // -----------------------------------

        if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
          rawJson = jsonDecode(rawJson);
        }
        
        List<dynamic> segmenList = jsonDecode(rawJson);
        
        for (var s in segmenList) {
          String k = (s['kondisi'] ?? '').toString().toUpperCase();
          double p = double.tryParse(s['panjang']?.toString() ?? '0') ?? 0;
          
          if (k.contains('BAIK')) pBaik += p;
          else if (k.contains('RR') || k.contains('RINGAN')) pRR += p;
          else if (k.contains('RB') || k.contains('BERAT')) pRB += p;
          else if (k.contains('BAP')) pBAP += p;
        }
      }

      // 2. Ekstrak Foto Saluran (Cari langsung dari field foto_baik, foto_rr, dll)
      List<String> keys = ['foto_baik', 'foto_rr', 'foto_rb', 'foto_bap'];
      for (String key in keys) {
        if (saluran[key] != null && saluran[key].toString().length > 10) {
          try {
            // PERBAIKAN: Menangani struktur list foto yang mungkin rusak
            String rawVal = saluran[key].toString();
            if (rawVal.startsWith('"') && rawVal.endsWith('"')) {
               rawVal = jsonDecode(rawVal);
            }
            List<dynamic> parsed = jsonDecode(rawVal);
            for (var f in parsed) {
              if (f.toString().isNotEmpty) fotoSaluran.add(f.toString());
            }
          } catch (e) {
            // Jika gagal decode, bersihkan manual lalu tambahkan
            String path = saluran[key].toString().replaceAll(RegExp(r'["\[\]]'), '').trim();
            if (path.isNotEmpty) fotoSaluran.add(path);
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal ekstrak Rangkuman Saluran: $e");
    }
    
    return { 'baik': pBaik, 'rr': pRR, 'rb': pRB, 'bap': pBAP, 'fotos': fotoSaluran };
  }

  // --- LOGIKA PARSING RANGKUMAN BANGUNAN ---
  List<String> _getFotoBangunan(Map<String, dynamic> b) {
    List<String> fotos = [];
    
    // Tarik Foto Bangunan Utama
    for (int i = 1; i <= 5; i++) {
      if (b['foto$i'] != null && b['foto$i'].toString().isNotEmpty) {
        fotos.add(b['foto$i'].toString());
      }
    }
    
    // Tarik Foto Pintu
    for (int i = 1; i <= 3; i++) {
      if (b['foto_pintu$i'] != null && b['foto_pintu$i'].toString().isNotEmpty) {
        String pathPintu = b['foto_pintu$i'].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
        if (pathPintu.isNotEmpty) fotos.add(pathPintu);
      }
    }
    
    return fotos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Antrean Upload Data", style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedSaluranIds.isNotEmpty || _selectedBangunanIds.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _hapusDataTerpilih, tooltip: "Hapus Terpilih"),
          if (_pendingData.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selectedSaluranIds.length == _pendingData.where((g) => g['type'] == 'saluran').length ? "BATAL SEMUA" : "PILIH SEMUA",
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedSaluranIds.isNotEmpty || _selectedBangunanIds.isNotEmpty)
                  Container(
                    color: Colors.orange.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          "Siap kirim: ${_selectedSaluranIds.length} Saluran & ${_selectedBangunanIds.length} Bangunan",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _pendingData.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(15),
                          itemCount: _pendingData.length,
                          itemBuilder: (context, index) {
                            final group = _pendingData[index];
                            final saluran = group['data'];
                            final listBangunan = group['bangunans'] as List<Map<String, dynamic>>;
                            int idSaluran = int.tryParse(saluran['id']?.toString() ?? "0") ?? 0;
                            final bool isSaluranSelected = _selectedSaluranIds.contains(idSaluran);

                            // HITUNG RANGKUMAN
                            var rangkuman = _getRangkumanSaluran(saluran);
                            List<String> fotoSaluran = rangkuman['fotos'];

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: group['isExpanded'],
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  leading: Checkbox(
                                    value: isSaluranSelected,
                                    activeColor: const Color(0xFF0D47A1),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedSaluranIds.add(idSaluran);
                                          for (var b in listBangunan) {
                                            int bId = int.tryParse(b['id']?.toString() ?? "0") ?? 0;
                                            if (!_selectedBangunanIds.contains(bId)) _selectedBangunanIds.add(bId);
                                          }
                                        } else {
                                          _selectedSaluranIds.remove(idSaluran);
                                          for (var b in listBangunan) {
                                            int bId = int.tryParse(b['id']?.toString() ?? "0") ?? 0;
                                            _selectedBangunanIds.remove(bId);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(
                                    saluran['nama_saluran'] ?? "Saluran",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D47A1)),
                                  ),
                                  subtitle: Text("Paket Survey: ${saluran['nama_di'] ?? '-'}\nPetugas: ${saluran['surveyor'] ?? 'Admin'}", style: const TextStyle(fontSize: 11)),
                                  
                                  children: [
                                    // --- RANGKUMAN SALURAN (MUNCUL JIKA DI-EXPAND) ---
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(15),
                                      color: Colors.blue.shade50.withOpacity(0.5),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Rangkuman Hasil Survey Saluran:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildStatBadge("BAIK", rangkuman['baik'], Colors.green),
                                              _buildStatBadge("RR", rangkuman['rr'], Colors.orange),
                                              _buildStatBadge("RB", rangkuman['rb'], Colors.red),
                                              _buildStatBadge("BAP", rangkuman['bap'], Colors.grey),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          if (fotoSaluran.isNotEmpty) ...[
                                            const Text("Preview Dokumentasi Saluran:", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                            const SizedBox(height: 8),
                                            _buildPhotoRow(fotoSaluran),
                                          ]
                                        ],
                                      ),
                                    ),

                                    // --- LIST BANGUNAN (ANAK) ---
                                    Container(
                                      color: Colors.grey.shade50,
                                      padding: const EdgeInsets.only(top: 5, bottom: 10),
                                      child: Column(
                                        children: listBangunan.map((b) => _buildBangunanTile(b)).toList(),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          onPressed: (_selectedSaluranIds.isEmpty && _selectedBangunanIds.isEmpty) || _isLoading ? null : () => _prosesSinkronisasiMassal(),
          icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload),
          label: Text(
            _isLoading ? "MENGIRIM DATA..." : "KIRIM DATA KE SERVER (${_selectedSaluranIds.length + _selectedBangunanIds.length})",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // WIDGET KOTAK STATISTIK PANJANG SALURAN
  Widget _buildStatBadge(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        Container(
          margin: const EdgeInsets.only(top: 4), // <--- PERBAIKANNYA DI SINI
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(6), 
            border: Border.all(color: color.withOpacity(0.5))
          ),
          child: Text("${value.toStringAsFixed(1)} m", style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
        ),
      ],
    );
  }

  // WIDGET HORIZONTAL SCROLL UNTUK PREVIEW FOTO
  Widget _buildPhotoRow(List<String> fotoPaths) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: fotoPaths.length,
        itemBuilder: (context, idx) {
          return Container(
            width: 50,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
              image: DecorationImage(
                image: FileImage(File(fotoPaths[idx])),
                fit: BoxFit.cover,
              )
            ),
          );
        },
      ),
    );
  }

  Widget _buildBangunanTile(Map<String, dynamic> b) {
    int idB = int.tryParse(b['id']?.toString() ?? "0") ?? 0;
    final bool isSelected = _selectedBangunanIds.contains(idB);
    
    List<String> fotoBangunan = _getFotoBangunan(b);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 15, bottom: 8, top: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 5),
              leading: Checkbox(
                value: isSelected,
                activeColor: Colors.orange,
                onChanged: (val) {
                  setState(() {
                    if (val == true) _selectedBangunanIds.add(idB);
                    else _selectedBangunanIds.remove(idB);
                  });
                },
              ),
              title: Text(b['nama_bangunan'] ?? "Bangunan", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text("Aset: ${b['kode_aset']} | Pintu (B/RR/RB): ${b['pintu_baik']}/${b['pintu_rr']}/${b['pintu_rb']}", style: const TextStyle(fontSize: 10)),
              trailing: IconButton(icon: const Icon(Icons.edit_document, color: Colors.green, size: 20), onPressed: () => _editBangunan(b)),
            ),
            // MUNCULKAN PREVIEW FOTO BANGUNAN & PINTU JIKA ADA
            if (fotoBangunan.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 45, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPhotoRow(fotoBangunan),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text("Semua Data Sudah Terkirim", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16)),
          Text("Tidak ada antrean survey yang tersisa.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }
}