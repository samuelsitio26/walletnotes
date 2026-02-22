import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() => runApp(const WalletNotesApp());

class WalletNotesApp extends StatelessWidget {
  const WalletNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WalletNotes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}
