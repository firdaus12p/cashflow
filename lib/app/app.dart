import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CashflowApp extends StatelessWidget {
  const CashflowApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cashflow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: GoogleFonts.poppins().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFFFF0F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: const Color(0xFFFF69B4),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: home,
    );
  }
}
