import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_page.dart';

class DeteksiPlakApp extends StatelessWidget {
  const DeteksiPlakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deteksi Plak Gigi',
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}