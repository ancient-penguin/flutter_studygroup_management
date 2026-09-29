import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 디자인 캔버스에서 옮긴 컬러 토큰.
/// accent 하나만 바꾸면 화면 전체 포인트 컬러가 같이 바뀝니다.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF4F2ED);
  static const ink = Color(0xFF1C1B19);
  static const muted = Color(0xFF6B6660);
  static const mutedDark = Color(0xFF5F5B53);
  static const cardBorder = Color(0xFFE4DFD5);
  static const divider = Color(0xFFEFEBE3);
  static const dashedBorder = Color(0xFFDCD5C8);
  static const surface = Color(0xFFFFFFFF);
  static const danger = Color(0xFFB03A3A);
  static const hint = Color(0xFF9A9489);

  static const accent = Color(0xFF2F5C4A); // 딥그린 (기본)

  static const greenBg = Color(0xFFE6EEE9);
  static const greenText = Color(0xFF2A5442);

  static const clayBg = Color(0xFFF6E9E1);
  static const clayText = Color(0xFF8E4A2B);
  static const clayTextLight = Color(0xFF9E5230);
}

class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const pill = 26.0;
}

class AppText {
  AppText._();

  static TextStyle display({double size = 28, Color color = AppColors.ink}) {
    return GoogleFonts.gowunBatang(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.gothicA1(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
    fontFamily: GoogleFonts.gothicA1().fontFamily,
    textTheme: GoogleFonts.gothicA1TextTheme(),
    dividerColor: AppColors.divider,
  );
}
