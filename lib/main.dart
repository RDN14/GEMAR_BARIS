import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/exam/data/exam_hive.dart';
import 'features/home/presentation/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) init Hive
  await Hive.initFlutter();

  // 2) register adapter (WAJIB semua yang dipakai)
  if (!Hive.isAdapterRegistered(ExamSessionHiveAdapter().typeId)) {
    Hive.registerAdapter(ExamSessionHiveAdapter());
  }
  if (!Hive.isAdapterRegistered(AnalysisItemHiveAdapter().typeId)) {
    Hive.registerAdapter(AnalysisItemHiveAdapter());
  }

  // 3) open box (nama box HARUS sama dgn ExamRepository)
  // PAKAI KONSTAN biar gak beda-beda
  await Hive.openBox<ExamSessionHive>(ExamHiveBoxes.sessions);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pendeteksi Plak Gigi',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE6E8EF)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const HomePage(),
    );
  }
}