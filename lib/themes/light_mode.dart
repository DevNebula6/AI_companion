import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData lightmode = ThemeData(
  colorScheme: ColorScheme.light(
    surface: Colors.grey.shade300,
    primary: Colors.blue.shade500,
    secondary: Colors.grey.shade200,
    tertiary: Colors.white,
    inversePrimary: Colors.grey.shade900,
  ),
);
ThemeData getAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    cardColor: const Color(0xFF16213E),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF7358FF),
      secondary: Color(0xFF41C2FF),
      background: Color(0xFF1A1A2E),
      surface: Color(0xFF16213E),
      error: Color(0xFFF9595F),
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
  );
}