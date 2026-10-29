import 'package:flutter/material.dart';

// Color Constants
const Color primaryGreen = Color(0xFF204E3B);
const Color primaryBlue = primaryGreen;
const Color accentYellow = Color(0xFFE6B968);
const Color lightGray = Color(0xFFF7F5EF);
const Color mediumGray = Color(0xFF667268);
const Color darkGray = Color(0xFF202E25);
const Color softGreen = Color(0xFFE8EEE4);
const Color warmBorder = Color(0xFFE2E5DA);
const Color warningInk = Color(0xFF8D4A20);
const Color dangerInk = Color(0xFFA23E31);

// App Theme Definition
final ThemeData appTheme = ThemeData(
  primaryColor: primaryGreen,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryGreen,
    primary: primaryGreen,
    secondary: primaryGreen,
    surface: lightGray,
    onSurface: darkGray,
    onPrimary: Colors.white,
    error: dangerInk,
  ),
  scaffoldBackgroundColor: lightGray,
  appBarTheme: const AppBarTheme(
    backgroundColor: lightGray,
    foregroundColor: darkGray,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: 24,
    toolbarHeight: 72,
    titleTextStyle: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w800,
      color: darkGray,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: warmBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: warmBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryGreen, width: 2),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: warmBorder),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 52),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
    elevation: 0,
    height: 64,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 12,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800
            : FontWeight.w500,
        color: states.contains(WidgetState.selected)
            ? primaryGreen
            : mediumGray,
      ),
    ),
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: primaryGreen,
    unselectedLabelColor: mediumGray,
    indicatorColor: primaryGreen,
    dividerColor: warmBorder,
    labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: darkGray),
    bodyMedium: TextStyle(color: darkGray),
    titleLarge: TextStyle(fontWeight: FontWeight.bold, color: darkGray),
  ),
  useMaterial3: true,
);
