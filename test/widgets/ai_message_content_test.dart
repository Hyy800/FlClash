import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/views/ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('separates reasoning from the final response', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: AiAssistantMessageContent(
          reasoning: 'Think first',
          content: 'Final answer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-reasoning')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-response')), findsOneWidget);
    expect(find.text('Thinking process'), findsOneWidget);
    expect(find.text('Think first'), findsOneWidget);
    expect(find.text('Final answer'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('omits the reasoning panel for a normal response', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _TestApp(child: AiAssistantMessageContent(content: 'Final answer')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-reasoning')), findsNothing);
    expect(find.byKey(const ValueKey('ai-response')), findsOneWidget);
  });

  testWidgets('shows the message time', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _TestApp(child: AiMessageTimestamp(createdAt: now)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-message-time')), findsOneWidget);
    expect(find.textContaining(':'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );
  }
}
