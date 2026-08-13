import 'package:fl_clash/views/proxies/tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overflow button owns a separate non-overlapping slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: ProxyTabHeaderBoundary(
              hasOverflow: true,
              tabs: SizedBox(width: 1200, height: 46),
              moreButton: IconButton(
                onPressed: null,
                icon: Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ),
      ),
    );

    final tabsRect = tester.getRect(
      find.byKey(const ValueKey('proxy-group-tabs-clip')),
    );
    final buttonRect = tester.getRect(
      find.byKey(const ValueKey('proxy-group-more-slot')),
    );

    expect(tabsRect.right, lessThanOrEqualTo(buttonRect.left));
    expect(buttonRect.width, 50);
    expect(find.byType(ClipRect), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more button is transparent and has no elevation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProxyTabMoreButton(onPressed: () {}, icon: Icons.chevron_right),
        ),
      ),
    );

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('proxy-group-more-button')),
    );
    expect(button.style?.elevation?.resolve({}), 0);
    expect(button.style?.backgroundColor?.resolve({}), Colors.transparent);
    expect(button.style?.shadowColor?.resolve({}), Colors.transparent);
    expect(button.style?.surfaceTintColor?.resolve({}), Colors.transparent);
  });

  testWidgets('node panel owns an inset clipped frame without shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProxyNodePanel(child: SizedBox.expand())),
      ),
    );

    final panel = tester.widget<Container>(
      find.byKey(const ValueKey('proxy-node-panel')),
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(panel.margin, const EdgeInsets.fromLTRB(8, 4, 8, 8));
    expect(panel.clipBehavior, Clip.antiAlias);
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNull);
  });
}
