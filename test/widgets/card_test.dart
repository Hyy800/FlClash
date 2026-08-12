import 'package:animations/animations.dart' as animations;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('nested list item shares the common card surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommonCard(
            child: ListItem(title: Text('Profile information')),
          ),
        ),
      ),
    );

    expect(find.byType(CommonCard), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CommonCard),
        matching: find.byType(Material),
      ),
      findsOneWidget,
    );
  });

  testWidgets('open list item does not paint a square closed surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListItem.open(
            title: Text('Theme'),
            delegate: OpenDelegate(widget: SizedBox()),
          ),
        ),
      ),
    );

    final finder = find.byWidgetPredicate(
      (widget) => widget is animations.OpenContainer,
    );
    final openContainer = tester.widget(finder) as animations.OpenContainer;
    expect(openContainer.closedColor, Colors.transparent);
  });
}
