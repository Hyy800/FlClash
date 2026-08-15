import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/widgets/app_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const transitions = PageTransitionsTheme();

  test('only light and dark theme modes remain available', () {
    expect(supportedThemeModes, [ThemeMode.light, ThemeMode.dark]);
  });

  test('light palette is tinted and keeps distinct surface layers', () {
    final scheme = AppTheme.build(
      brightness: Brightness.light,
      pageTransitionsTheme: transitions,
    ).colorScheme;

    expect(scheme.surface, isNot(Colors.white));
    expect({
      scheme.surface,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    }, hasLength(6));
  });

  testWidgets('theme screen exposes no automatic or custom palette controls', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _ThemeTestApp(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_mode), findsNothing);
    expect(find.byIcon(Icons.palette), findsNothing);
    expect(find.byIcon(Icons.contrast), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} theme renders linear and radial gradients',
      (tester) async {
        final theme = AppTheme.build(
          brightness: brightness,
          pageTransitionsTheme: transitions,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const AppBackdrop(child: SizedBox.expand()),
          ),
        );

        final gradients = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>()
            .map((decoration) => decoration.gradient)
            .whereType<Gradient>()
            .toList();
        expect(gradients.whereType<LinearGradient>(), isNotEmpty);
        expect(gradients.whereType<RadialGradient>(), isNotEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ThemeTestApp extends StatelessWidget {
  const _ThemeTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: AppTheme.build(
        brightness: Brightness.light,
        pageTransitionsTheme: const PageTransitionsTheme(),
      ),
      builder: (context, child) {
        globalState.measure = Measure.of(context, 1);
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: const ThemeView(),
    );
  }
}
