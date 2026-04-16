import 'package:flutter/material.dart';

import '../features/home/presentation/home_page.dart';

class DeteksiPlakApp extends StatelessWidget {
  const DeteksiPlakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deteksi Plak Gigi',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3BB273),
      ),
      home: const HomePage(),
    );
  }
}