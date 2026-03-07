import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart'; // Jika ini merah, pastikan sudah 'flutter pub get'
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';

class FormDiPage extends StatefulWidget {
  const FormDiPage({super.key});

  @override
  State<FormDiPage> createState() => _FormDiPageState();
}

class _FormDiPageState extends State<FormDiPage> {
  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  final _bendungController = TextEditingController();
  final _sumberAirController = TextEditingController();
  final _luasPermenController = TextEditingController();
  final _luasOnemapController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTracking = false;
  double _totalDistance = 0.0;
  List<LatLng> _routeCoords = [];
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();

  void _updateTracking(Position position) {
    LatLng newPoint = LatLng(position.latitude, position.longitude);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    setState(() {
      if (_routeCoords.isNotEmpty) {
        final lastPoint = _routeCoords.last;
        double distance = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance;
      }
      _routeCoords.add(newPoint);
    });

    _mapController.move(newPoint, _mapController.camera.zoom);
  }

  void _toggleTracking() async {
    if (_isTracking) {
      await _positionStream?.cancel();
      setState(() => _isTracking = false);
    } else {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      setState(() {
        _isTracking = true;
        _routeCoords.clear();
        _totalDistance = 0.0;
      });

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) => _updateTracking(position));
    }
  }

  Future<void> _handleSave() async {
    if (_kodeController.text.isEmpty || _namaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kode dan Nama D.I. wajib diisi!")),
      );
      return;
    }

    Map<String, dynamic> data = {
      'kode_di': _kodeController.text,
      'nama_di': _namaController.text,
      'bendung': _bendungController.text,
      'sumber_air': _sumberAirController.text,
      'luas_permen': double.tryParse(_luasPermenController.text) ?? 0,
      'luas_onemap': double.tryParse(_luasOnemapController.text) ?? 0,
      'coordinates': jsonEncode(
        _routeCoords
            .map((e) => {'lat': e.latitude, 'lng': e.longitude})
            .toList(),
      ),
      'status_sync': 0,
    };

    await DatabaseService().insertDIFull(data);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _kodeController.dispose();
    _namaController.dispose();
    _bendungController.dispose();
    _sumberAirController.dispose();
    _luasPermenController.dispose();
    _luasOnemapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey D.I. & Tracking"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. AREA PETA
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(-6.826, 108.604),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.dsdaputr.apps_cirebon',
                      // Pastikan const FMTCStore('mapStore') sesuai dengan yang di main.dart
                      tileProvider: const FMTCStore(
                        'mapStore',
                      ).getTileProvider(),
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routeCoords,
                          color: Colors.blue,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                  ],
                ),
                // Overlay Lat/Long di Peta
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _routeCoords.isNotEmpty
                          ? "${_routeCoords.last.latitude.toStringAsFixed(6)}, ${_routeCoords.last.longitude.toStringAsFixed(6)}"
                          : "Menunggu GPS...",
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. INPUT DATA & LIST
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _kodeController,
                    decoration: const InputDecoration(
                      labelText: "Kode D.I.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      labelText: "Nama D.I.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bendungController,
                    decoration: const InputDecoration(
                      labelText: "Bendung",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sumberAirController,
                    decoration: const InputDecoration(
                      labelText: "Sumber Air",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BOX KOORDINAT
                  const Text(
                    "Riwayat Titik Koordinat:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _routeCoords.isEmpty
                        ? const Center(child: Text("Belum ada data tracking"))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _routeCoords.length,
                            itemBuilder: (context, index) {
                              final point = _routeCoords.reversed
                                  .toList()[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                title: Text(
                                  "Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}",
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _luasPermenController,
                          decoration: const InputDecoration(
                            labelText: "Luas Permen (Ha)",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _luasOnemapController,
                          decoration: const InputDecoration(
                            labelText: "Luas OneMap (Ha)",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. TOMBOL
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isTracking ? "STOP TRACKING" : "LIVE TRACKING",
                    ),
                    onPressed: _toggleTracking,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: _isTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isTracking ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("SIMPAN DATA D.I."),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
