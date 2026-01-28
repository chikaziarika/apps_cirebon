import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  IOWebSocketChannel? _channel;

  // Ganti IP sesuai IP Laptop Anda (cek via 'ipconfig' di CMD)
  // Contoh: 192.168.1.5
  void connectLiveShared(String ipAddress) {
    _channel = IOWebSocketChannel.connect(Uri.parse('ws://$ipAddress:8000/ws/live/'));
    print("Terhubung ke Live Shared Irigasi");
  }

  void startTracking(String surveyorName) async {
    // 1. Cek & Minta Izin GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    // 2. Kirim koordinat setiap ada perubahan posisi
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 5, // Kirim tiap bergerak 5 meter
      ),
    ).listen((Position position) {
      if (_channel != null) {
        final data = jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'user': surveyorName,
        });
        _channel!.sink.add(data);
        print("Mengirim Lokasi: $data");
      }
    });
  }

  void dispose() {
    _channel?.sink.close();
  }
}