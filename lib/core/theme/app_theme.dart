import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {

  static ThemeData lightTheme = ThemeData(

    primaryColor: AppColors.primary,

    scaffoldBackgroundColor: AppColors.background,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 24,
        ),
      ),
    ),

    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),

  );

}