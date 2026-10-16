import 'package:flutter/material.dart';

/// K.I.T.T. (Knight Industries Two Thousand) visual language.
/// Near-black cockpit surfaces, sweeping red as the primary signal,
/// amber for data readouts, monospace type with wide tracking.
class KittColors {
  static const bg = Color(0xFF060608); // cockpit void
  static const panel = Color(0xFF0D0E12);
  static const panelSoft = Color(0xFF14161C);
  static const panelFill = Color(0xE60D0E12);

  static const red = Color(0xFFFF3B30); // the scanner
  static const redBright = Color(0xFFFF6A5E);
  static const redDeep = Color(0xFF6E100C);
  static const amber = Color(0xFFFFB300); // instrument data
  static const cyan = Color(0xFF4DD9E8); // secondary readouts
  static const green = Color(0xFF3AE08A);

  static const text = Color(0xFFEDE7DA);
  static const textDim = Color(0x99EDE7DA);
  static const textFaint = Color(0x55EDE7DA);
  static const grid = Color(0x14FF3B30); // faint scan grid

  /// fixed palette for charts (replaces random colors)
  static const chart = [
    red,
    amber,
    cyan,
    Color(0xFFFF7A3C),
    Color(0xFFB3E53A),
    Color(0xFFE04DB8),
    Color(0xFF6A7BFF),
    green,
  ];

  static Color chartAt(int i) => chart[i % chart.length];
}

/// Monospace instrument lettering.
class KittStyle {
  static const mono = 'monospace';

  static TextStyle label(
          {double size = 14,
          Color color = KittColors.textDim,
          double spacing = 2}) =>
      TextStyle(
          fontFamily: mono,
          fontSize: size,
          letterSpacing: spacing,
          color: color);

  static TextStyle value({double size = 28, Color color = KittColors.text}) =>
      TextStyle(fontFamily: mono, fontSize: size, fontWeight: FontWeight.bold, color: color);

  static TextStyle glow({double size = 18, Color color = KittColors.red}) => TextStyle(
      fontFamily: mono,
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 2,
      shadows: [Shadow(color: color.withOpacity(.7), blurRadius: 12)]);

  static TextStyle body({double size = 15, Color color = KittColors.text}) =>
      TextStyle(fontFamily: mono, fontSize: size, color: color, height: 1.4);
}

ThemeData kittTheme() {
  const seed = KittColors.red;
  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    fontFamily: KittStyle.mono,
    scaffoldBackgroundColor: KittColors.bg,
    canvasColor: KittColors.bg,
    primaryColor: seed,
    colorScheme: const ColorScheme.dark(
      primary: seed,
      secondary: KittColors.amber,
      surface: KittColors.panel,
      error: seed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: KittColors.panel,
      foregroundColor: KittColors.text,
      elevation: 0,
      titleTextStyle: TextStyle(
          fontFamily: KittStyle.mono,
          fontSize: 18,
          letterSpacing: 4,
          color: KittColors.text),
      iconTheme: IconThemeData(color: KittColors.red),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontFamily: KittStyle.mono, color: KittColors.text),
      bodySmall: TextStyle(fontFamily: KittStyle.mono, color: KittColors.textDim),
      titleMedium: TextStyle(
          fontFamily: KittStyle.mono,
          color: KittColors.amber,
          letterSpacing: 2),
    ),
    dividerColor: KittColors.grid,
    cardColor: KittColors.panel,
    dialogBackgroundColor: KittColors.panel,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KittColors.panelSoft,
        foregroundColor: KittColors.text,
        side: const BorderSide(color: Color(0x66FF3B30)),
        shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
        textStyle: const TextStyle(fontFamily: KittStyle.mono, letterSpacing: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: KittColors.amber,
          textStyle: const TextStyle(fontFamily: KittStyle.mono, letterSpacing: 2)),
    ),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: KittColors.red)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? KittColors.red : Colors.grey.shade600),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? KittColors.redDeep : Colors.black38),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: KittColors.red,
      thumbColor: KittColors.redBright,
      inactiveTrackColor: KittColors.redDeep,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KittColors.red, linearTrackColor: KittColors.redDeep),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(fontFamily: KittStyle.mono, color: KittColors.textDim),
      hintStyle: const TextStyle(fontFamily: KittStyle.mono, color: KittColors.textFaint),
      enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0x40FF3B30))),
      focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: KittColors.red)),
    ),
    popupMenuTheme: const PopupMenuThemeData(color: KittColors.panel),
    snackBarTheme:
        const SnackBarThemeData(backgroundColor: KittColors.panelSoft, contentTextStyle: TextStyle(fontFamily: KittStyle.mono, color: KittColors.text)),
  );
}
