import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const PdfReaderApp());
}

class PdfReaderApp extends StatelessWidget {
  const PdfReaderApp({super.key});

  static const _seed = Color(0xFFE5322D);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      ),
      home: const HomePage(),
    );
  }
}
