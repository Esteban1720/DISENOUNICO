// -----------------------------
// Archivo: lib/theme.dart
// Tema global con la paleta del Login
// -----------------------------
import 'package:flutter/material.dart';

// 🎨 Paleta alineada con los colores del Login
const Color primaryColor =
    Color(0xFF083B3D); // Color principal (antes accentTeal)
const Color scaffoldPink = Color(0xFFF6E8EA); // Fondo principal
const Color fieldFill = Color(0xFFF0F4F6); // Fondo de campos
const Color buttonFill = Color(0xFF081E23); // Fondo de botones

const Color darkText = Color(0xFF0B2B2B);
const Color secondaryColor = Color(0xFF083B3D);

// 🌈 Tema principal de la app
final ThemeData appTheme = ThemeData(
  primaryColor: primaryColor,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryColor,
    primary: primaryColor,
    secondary: secondaryColor,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: scaffoldPink,
  appBarTheme: const AppBarTheme(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: buttonFill,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: fieldFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: darkText),
    bodyLarge: TextStyle(color: darkText),
  ),
);
