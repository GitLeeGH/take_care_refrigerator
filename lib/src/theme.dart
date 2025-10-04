import 'package:flutter/material.dart';

// Color Constants
const Color primaryBlue = Color(0xFF4A90E2);
const Color primaryGreen = Color(0xFF20C997);
const Color accentYellow = Color(0xFFF8E71C);
const Color lightGray = Color(0xFFF5F5F5);
const Color mediumGray = Color(0xFF9B9B9B);
const Color darkGray = Color(0xFF4A4A4A);

// App Theme Definition
final ThemeData appTheme = ThemeData(
  primaryColor: primaryGreen,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryGreen,
    primary: primaryGreen,
    secondary: primaryGreen,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: darkGray),
    bodyMedium: TextStyle(color: darkGray),
    titleLarge: TextStyle(fontWeight: FontWeight.bold, color: darkGray),
  ),
  useMaterial3: true,
);