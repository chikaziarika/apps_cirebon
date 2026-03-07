import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Hapus 'const' karena constructor Bapak bukan const
    await FMTCObjectBoxBackend().initialise();

    // 2. Langsung create saja, FMTC sudah pintar,
    // kalau sudah ada dia tidak akan bikin error kok
    final store = const FMTCStore('mapStore');
    await store.manage.create();

    debugPrint("FMTC Siap Digunakan!");
  } catch (err) {
    debugPrint("FMTC Gagal: $err");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SINAR CIREBON',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}
