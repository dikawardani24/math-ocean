import 'package:material_ui/material_ui.dart';

/// The palette and type scale for Ocean Numberland.
///
/// Deep teal water, sunlit aqua, coral and shell tones. Everything is rounded,
/// glossy and a little oversized so it reads as a toy rather than a test.
abstract final class OceanColors {
  static const abyss = Color(0xFF021C2B);
  static const deep = Color(0xFF043142);
  static const deepWater = Color(0xFF07475B);
  static const water = Color(0xFF0B6B7C);
  static const teal = Color(0xFF1196A2);
  static const aqua = Color(0xFF36D6C6);
  static const mint = Color(0xFFA8F4E2);
  static const foam = Color(0xFFE5FFF8);

  static const coral = Color(0xFFFF8768);
  static const coralDeep = Color(0xFFE05A46);
  static const sunny = Color(0xFFFFD05C);
  static const sunnyDeep = Color(0xFFF2A93B);
  static const lilac = Color(0xFF9A7BE8);
  static const lilacDeep = Color(0xFF6F52C4);
  static const shell = Color(0xFFFFF3DE);
  static const sand = Color(0xFFF6DCA6);
  static const ink = Color(0xFF07313D);
  static const inkSoft = Color(0xFF315C66);

  static const gradientWater = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF063D50), Color(0xFF0A7180), Color(0xFF042A3A)],
    stops: [0, 0.55, 1],
  );
}

ThemeData buildOceanTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Baloo2',
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: OceanColors.teal,
      primary: OceanColors.teal,
      secondary: OceanColors.coral,
      surface: OceanColors.shell,
      onSurface: OceanColors.ink,
    ),
  );

  final text = base.textTheme.apply(
    bodyColor: OceanColors.ink,
    displayColor: OceanColors.ink,
    fontFamily: 'Baloo2',
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: text.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1,
      ),
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
  );
}

extension OceanTextX on BuildContext {
  TextTheme get t => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

/// A soft, toy-like shadow used by floating cards.
List<BoxShadow> oceanShadow({double blur = 22, double y = 10}) => [
  BoxShadow(
    color: OceanColors.abyss.withValues(alpha: 0.28),
    blurRadius: blur,
    offset: Offset(0, y),
  ),
  BoxShadow(
    color: Colors.white.withValues(alpha: 0.12),
    blurRadius: 2,
    offset: const Offset(0, -1),
  ),
];
