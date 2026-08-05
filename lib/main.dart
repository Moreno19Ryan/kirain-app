import 'package:flutter/material.dart';

void main() {
  runApp(const KirainApp());
}

class KirainApp extends StatelessWidget {
  const KirainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KIRAIN',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'KIRAIN',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
