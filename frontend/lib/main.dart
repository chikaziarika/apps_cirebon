import 'package:flutter/material.dart';
import 'services/websocket_service.dart'; // Import service yang dibuat tadi

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Irigasi Cirebon Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LiveSharedPage(),
    );
  }
}

class LiveSharedPage extends StatefulWidget {
  const LiveSharedPage({super.key});

  @override
  State<LiveSharedPage> createState() => _LiveSharedPageState();
}

class _LiveSharedPageState extends State<LiveSharedPage> {
  // Inisialisasi Service
  final WebSocketService _wsService = WebSocketService();
  bool _isTracking = false;

  void _toggleTracking() {
    if (!_isTracking) {
      // GANTI DENGAN IP LAPTOP/SERVER ANDA
      _wsService.connectLiveShared("192.168.18.30"); 
      _wsService.startTracking("Surveyor_Jelita");
      setState(() => _isTracking = true);
    } else {
      _wsService.dispose();
      setState(() => _isTracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Shared Surveyor"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTracking ? Icons.location_on : Icons.location_off,
              size: 80,
              color: _isTracking ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              _isTracking ? "Status: Berbagi Lokasi Aktif" : "Status: Non-Aktif",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _toggleTracking,
              icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
              label: Text(_isTracking ? "Hentikan Live Shared" : "Mulai Live Shared"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}