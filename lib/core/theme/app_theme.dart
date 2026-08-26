import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matchmaster/core/theme/app_colors.dart';

export 'package:matchmaster/core/theme/app_colors.dart';

/// Tema do MatchMaster em Material 3.
abstract final class AppTheme {
  /// Raio padrão dos cartões e caixas.
  static const double radius = 18;

  /// Raio dos controles (botões, campos).
  static const double controlRadius = 14;

  /// Espaçamento base da grade de layout.
  static const double gap = 16;

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color primary = isDark ? AppColors.clay : AppColors.clayDeep;
    final Color secondary = isDark ? AppColors.teal : AppColors.tealDeep;
    final Color background = isDark ? AppColors.ink900 : AppColors.paper;
    final Color surface = isDark ? AppColors.ink800 : AppColors.paperSurface;
    final Color onSurface =
        isDark ? const Color(0xFFE8EDF2) : const Color(0xFF151A1F);
    final Color outline = isDark
        ? Colors.white.withOpacity(0.10)
        : AppColors.ink.withOpacity(0.10);

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? AppColors.ink : Colors.white,
      primaryContainer: primary.withOpacity(isDark ? 0.18 : 0.12),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: isDark ? AppColors.ink : Colors.white,
      secondaryContainer: secondary.withOpacity(isDark ? 0.18 : 0.12),
      onSecondaryContainer: secondary,
      tertiary: isDark ? AppColors.amber : AppColors.amberDeep,
      onTertiary: AppColors.ink,
      error: isDark ? AppColors.danger : AppColors.dangerDeep,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: background,
      surfaceContainerHighest:
          isDark ? AppColors.ink700 : const Color(0xFFF1ECE6),
      outline: outline,
      outlineVariant: outline,
    );

    // O tema base resolve a tipografia (família de fonte da plataforma, por
    // exemplo). Os sub-temas abaixo partem de `base.textTheme`, e não da escala
    // crua, para que botão, diálogo e ListTile herdem a mesma fonte do resto.
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: _textTheme(onSurface),
    );
    final TextTheme text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.ink800 : Colors.white,
        hintStyle: TextStyle(color: onSurface.withOpacity(0.40)),
        labelStyle: TextStyle(color: onSurface.withOpacity(0.70)),
        floatingLabelStyle: TextStyle(color: primary),
        prefixIconColor: onSurface.withOpacity(0.55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _inputBorder(outline),
        enabledBorder: _inputBorder(outline),
        focusedBorder: _inputBorder(primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: onSurface.withOpacity(0.10),
          disabledForegroundColor: onSurface.withOpacity(0.35),
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          textStyle: text.labelLarge?.copyWith(
            fontSize: 16,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: outline),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(foregroundColor: onSurface.withOpacity(0.75)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: outline)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius),
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : onSurface.withOpacity(0.75),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? primary
                : Colors.transparent,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.ink800 : Colors.white,
        selectedColor: primary,
        checkmarkColor: scheme.onPrimary,
        side: BorderSide(color: outline),
        labelStyle: text.labelLarge?.copyWith(color: onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(isDark ? 0.20 : 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => text.labelLarge?.copyWith(
            fontSize: 11.5,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? primary
                : onSurface.withOpacity(0.60),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? primary
                : onSurface.withOpacity(0.60),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.ink700 : const Color(0xFF20272F),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.amber,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: outline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface.withOpacity(0.70),
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: onSurface.withOpacity(0.08),
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? primary
              : onSurface.withOpacity(0.45),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll<Color>(scheme.onPrimary),
        side: BorderSide(color: onSurface.withOpacity(0.40), width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Escala tipográfica com títulos apertados e números tabulares no placar.
  static TextTheme _textTheme(Color onSurface) {
    final Color muted = onSurface.withOpacity(0.65);
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 68,
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
        height: 1,
        color: onSurface,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: onSurface,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: muted,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: onSurface, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: onSurface,
      ),
    );
  }
}
