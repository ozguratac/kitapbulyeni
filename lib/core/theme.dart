import 'package:flutter/material.dart';

/// Marka rengi geçici; eski uygulamanın renk paletine göre güncellenecek.
const Color _seed = Color(0xFF3F51B5);

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  );
}
