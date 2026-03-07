import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ArScannerPage extends StatefulWidget {
  const ArScannerPage({super.key});

  @override
  State<ArScannerPage> createState() => _ArScannerPageState();
}

class _ArScannerPageState extends State<ArScannerPage> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  List<ARNode> nodes = [];

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AR Real-Time Measure"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          const Center(
            child: Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                nodes.length == 0
                    ? "Bidik beton, lalu klik titik AWAL"
                    : "Klik titik AKHIR saluran",
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    // 1. Inisialisasi tanpa properti yang merah
    this.arSessionManager!.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      showWorldOrigin: false,
      // Jika handlePlaneTap merah, hapus saja baris itu Pak.
      // Biasanya di versi terbaru sudah include di handleTaps atau otomatis.
    );

    this.arObjectManager!.onInitialize();

    // 2. Gunakan salah satu dari dua nama ini (cek mana yang tidak merah):
    // Coba ketik 'this.arSessionManager!.' lalu lihat saran yang muncul

    // Opsi A (Paling sering di versi terbaru):
    this.arSessionManager!.onPlaneOrPointTap = _handleMeasurement;

    // Opsi B (Jika A merah):
    // this.arSessionManager!.onTapPlane = _handleMeasurement;
  }

  // 3. Fungsi Logika Ukur
  Future<void> _handleMeasurement(ARHitTestResult hit) async {
    if (hitTestResults.isEmpty) return;

    final hit = hitTestResults.first;

    // Logika ambil posisi 3D
    final vector.Vector3 position = vector.Vector3.fromFloat64List(
      hit.worldTransform.getColumn(3).storage,
    );

    // Jika sudah ada 2 titik, reset untuk pengukuran baru
    if (nodes.length >= 2) {
      for (var node in nodes) {
        arObjectManager?.removeNode(node);
      }
      nodes.clear();
      setState(() {});
    }

    // Ambil posisi 3D
    final vector.Vector3 position = vector.Vector3.fromFloat64List(
      hit.worldTransform.getColumn(3).storage,
    );

    // Buat penanda (node) agar surveyor tahu titik mana yang diklik
    final newNode = ARNode(
      type: NodeType.localGLTF2,
      uri: "", // Kosongkan saja karena tidak ada aset
      position: position,
      scale: vector.Vector3(0.05, 0.05, 0.05),
    );

    bool? didAddNode = await arObjectManager?.addNode(newNode);
    if (didAddNode == true) {
      nodes.add(newNode);
      setState(() {}); // Update teks instruksi (Langkah 1 ke Langkah 2)

      if (nodes.length == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Titik AWAL ditandai"),
            duration: Duration(milliseconds: 500),
          ),
        );
      } else if (nodes.length == 2) {
        // HITUNG JARAK MATEMATIKA 3D
        final distance = nodes[0].position.distanceTo(nodes[1].position);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Jarak Terukur: ${distance.toStringAsFixed(2)} Meter",
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Tunggu 1 detik biar surveyor lihat hasilnya, lalu balik ke form
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, distance);
        });
      }
    }
  }

  Future<void> _prosesKlik(ARHitTestResult hit) async {
    if (nodes.length >= 2) {
      for (var node in nodes) {
        arObjectManager?.removeNode(node);
      }
      nodes.clear();
    }

    final newPos = vector.Vector3.fromFloat64List(
      hit.worldTransform.getColumn(3).storage,
    );

    final newNode = ARNode(
      type: NodeType.localGLTF2,
      uri: "",
      position: newPos,
      scale: vector.Vector3(0.05, 0.05, 0.05),
    );

    bool? didAdd = await arObjectManager?.addNode(newNode);
    if (didAdd == true) {
      nodes.add(newNode);
      setState(() {}); // Update teks instruksi

      if (nodes.length == 2) {
        final dist = nodes[0].position.distanceTo(nodes[1].position);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Jarak Terukur: ${dist.toStringAsFixed(2)} meter"),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(
          const Duration(seconds: 1),
          () => Navigator.pop(context, dist),
        );
      }
    }
  }
}
