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
              : const Color(0xFF0C111B)
        : const Color(0xFFE9EFF7);
    final scheme = baseScheme.copyWith(
      primary: isDark ? const Color(0xFF64A8FF) : const Color(0xFF0A84FF),
      onPrimary: isDark ? const Color(0xFF001A41) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF173A63)
          : const Color(0xFFD8EBFF),
      onPrimaryContainer: isDark
          ? const Color(0xFFDCE8FF)
          : const Color(0xFF082B68),
      secondary: isDark ? const Color(0xFF78D7FF) : const Color(0xFF007AFF),
      tertiary: isDark ? const Color(0xFFFFD479) : const Color(0xFFFF9F0A),
      surface: surface,
      surfaceContainerLowest: isDark
          ? pureBlack
                ? const Color(0xFF000000)
                : const Color(0xFF090E17)
          : const Color(0xFFF8FAFD),
      surfaceContainerLow: isDark
          ? pureBlack
                ? const Color(0xFF070707)
                : const Color(0xFF111823)
          : const Color(0xFFF1F5FA),
      surfaceContainer: isDark
          ? pureBlack
                ? const Color(0xFF0B0B0B)
                : const Color(0xFF17202D)
          : const Color(0xFFE5ECF5),
      surfaceContainerHigh: isDark
          ? pureBlack
                ? const Color(0xFF101010)
                : const Color(0xFF202B3A)
          : const Color(0xFFD8E2EF),
      surfaceContainerHighest: isDark
          ? pureBlack
                ? const Color(0xFF171717)
                : const Color(0xFF2A3748)
          : const Color(0xFFC9D6E6),
      onSurface: isDark ? const Color(0xFFF3F7FC) : const Color(0xFF172235),
      onSurfaceVariant: isDark
          ? const Color(0xFFB2C0D2)
          : const Color(0xFF536278),
      outline: isDark ? const Color(0xFF73849B) : const Color(0xFF69798E),
      outlineVariant: isDark
          ? const Color(0xFF334155)
          : const Color(0xFFBCC9D9),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      pageTransitionsTheme: pageTransitionsTheme,
      visualDensity: VisualDensity.compact,
    );
    final textTheme = baseTheme.textTheme
        .copyWith(
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
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final panelShape = RoundedRectangleBorder(
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
        toolbarHeight: 60,
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
          minimumSize: const Size(38, 38),
          foregroundColor: scheme.onSurfaceVariant,
          backgroundColor: scheme.surfaceContainerHigh.withAlpha(150),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outlineVariant.withAlpha(130)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerHigh.withAlpha(170),
        selectedColor: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        labelStyle: textTheme.labelMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minTileHeight: 52,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          elevation: const WidgetStatePropertyAll(3),
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
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
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}
