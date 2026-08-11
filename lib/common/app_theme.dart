import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build({
    required ColorScheme baseScheme,
    required PageTransitionsTheme pageTransitionsTheme,
    bool pureBlack = false,
  }) {
    final isDark = baseScheme.brightness == Brightness.dark;
    final surface = isDark
        ? pureBlack
              ? const Color(0xFF000000)
              : const Color(0xFF080808)
        : const Color(0xFFF3F4F7);
    final scheme = baseScheme.copyWith(
      surface: surface,
      surfaceContainerLowest: isDark
          ? pureBlack
                ? const Color(0xFF000000)
                : const Color(0xFF050505)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark
          ? pureBlack
                ? const Color(0xFF070707)
                : const Color(0xFF101012)
          : const Color(0xFFFAFBFD),
      surfaceContainer: isDark
          ? pureBlack
                ? const Color(0xFF0B0B0B)
                : const Color(0xFF151517)
          : const Color(0xFFEEF0F4),
      surfaceContainerHigh: isDark
          ? pureBlack
                ? const Color(0xFF101010)
                : const Color(0xFF1B1B1E)
          : const Color(0xFFE5E8EE),
      surfaceContainerHighest: isDark
          ? pureBlack
                ? const Color(0xFF171717)
                : const Color(0xFF242429)
          : const Color(0xFFDDE4EE),
      outline: isDark ? const Color(0xFF65718A) : const Color(0xFF67728A),
      outlineVariant: isDark
          ? const Color(0xFF303036)
          : const Color(0xFFC8D0DD),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      pageTransitionsTheme: pageTransitionsTheme,
      visualDensity: VisualDensity.standard,
    );
    final textTheme = baseTheme.textTheme.copyWith(
      displaySmall: baseTheme.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTheme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(height: 1.4),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final controlShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final panelShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surface,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: panelShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withAlpha(110),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.onSurfaceVariant,
          backgroundColor: scheme.surfaceContainerHigh.withAlpha(150),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withAlpha(165),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerHigh.withAlpha(170),
        selectedColor: scheme.primaryContainer,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        minTileHeight: 58,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}
