import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    required PageTransitionsTheme pageTransitionsTheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = isDark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    final scheme = baseScheme.copyWith(
      primary: isDark ? const Color(0xFFAFC4FF) : const Color(0xFF4B5FC6),
      onPrimary: isDark ? const Color(0xFF142552) : const Color(0xFFFFFFFF),
      primaryContainer: isDark
          ? const Color(0xFF31457B)
          : const Color(0xFFDDE4FF),
      onPrimaryContainer: isDark
          ? const Color(0xFFDFE5FF)
          : const Color(0xFF17245A),
      secondary: isDark ? const Color(0xFF83D1E1) : const Color(0xFF16798B),
      onSecondary: isDark ? const Color(0xFF00363F) : const Color(0xFFFFFFFF),
      secondaryContainer: isDark
          ? const Color(0xFF164E59)
          : const Color(0xFFBDEAF1),
      onSecondaryContainer: isDark
          ? const Color(0xFFB6EBF5)
          : const Color(0xFF0A3C46),
      tertiary: isDark ? const Color(0xFFDAB7FF) : const Color(0xFF7C4D9D),
      onTertiary: isDark ? const Color(0xFF45215D) : const Color(0xFFFFFFFF),
      tertiaryContainer: isDark
          ? const Color(0xFF57366F)
          : const Color(0xFFF0D9FF),
      onTertiaryContainer: isDark
          ? const Color(0xFFF0DAFF)
          : const Color(0xFF321342),
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: isDark ? const Color(0xFF690005) : const Color(0xFFFFFFFF),
      errorContainer: isDark
          ? const Color(0xFF93000A)
          : const Color(0xFFFFDAD6),
      onErrorContainer: isDark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF410002),
      surface: isDark ? const Color(0xFF08111F) : const Color(0xFFDDE5F0),
      surfaceDim: isDark ? const Color(0xFF08111F) : const Color(0xFFC6D1E0),
      surfaceBright: isDark ? const Color(0xFF2D3D57) : const Color(0xFFF6F8FC),
      surfaceContainerLowest: isDark
          ? const Color(0xFF050C17)
          : const Color(0xFFF8FAFD),
      surfaceContainerLow: isDark
          ? const Color(0xFF0D1727)
          : const Color(0xFFEDF2F8),
      surfaceContainer: isDark
          ? const Color(0xFF121E30)
          : const Color(0xFFE4EAF3),
      surfaceContainerHigh: isDark
          ? const Color(0xFF19263A)
          : const Color(0xFFD7E0EB),
      surfaceContainerHighest: isDark
          ? const Color(0xFF223149)
          : const Color(0xFFC8D4E2),
      onSurface: isDark ? const Color(0xFFE7ECF5) : const Color(0xFF172033),
      onSurfaceVariant: isDark
          ? const Color(0xFFBAC4D7)
          : const Color(0xFF4D5D73),
      outline: isDark ? const Color(0xFF8491A8) : const Color(0xFF64758B),
      outlineVariant: isDark
          ? const Color(0xFF394760)
          : const Color(0xFFAEBCCD),
      surfaceTint: isDark ? const Color(0xFFAFC4FF) : const Color(0xFF4B5FC6),
      inverseSurface: isDark
          ? const Color(0xFFE7ECF5)
          : const Color(0xFF263246),
      onInverseSurface: isDark
          ? const Color(0xFF263246)
          : const Color(0xFFF2F5FB),
      inversePrimary: isDark
          ? const Color(0xFF4B5FC6)
          : const Color(0xFFAFC4FF),
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
