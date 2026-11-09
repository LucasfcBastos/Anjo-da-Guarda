import 'package:flutter/material.dart';

/// Cores e estilos do app: tons suaves de saúde, com vermelho
/// reservado para emergências. Textos e botões grandes para idosos.
class AppColors {
  static const primary = Color(0xFF2E7D8C); // azul-petróleo suave
  static const background = Color(0xFFF4F8F8);
  static const safe = Color(0xFF2E7D32);
  static const warning = Color(0xFFEF6C00);
  static const emergency = Color(0xFFC62828);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: Colors.white,
      error: AppColors.emergency,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      // Textos 15% maiores que o padrão do Material (mais legíveis).
      textTheme: base.textTheme.merge(
        Typography.englishLike2021.apply(fontSizeFactor: 1.15),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        labelStyle: const TextStyle(fontSize: 19),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
