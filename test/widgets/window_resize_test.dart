import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows frame starts native resizing from the left edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('window_manager');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'isMaximized' || 'isAlwaysOnTop' || 'isFullScreen' => false,
            'startResizing' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [versionProvider.overrideWithBuild((_, _) => 15)],
        child: const MaterialApp(
          home: WindowHeaderContainer(
            windowsResizeFrame: true,
            child: ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final edge in [
      'left',
      'right',
      'top',
      'bottom',
      'top-left',
      'top-right',
      'bottom-left',
      'bottom-right',
    ]) {
      expect(find.byKey(ValueKey('window-resize-$edge')), findsOneWidget);
    }

    final leftEdge = find.byKey(const ValueKey('window-resize-left'));
    expect(leftEdge, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(leftEdge));
    await gesture.moveBy(const Offset(12, 0));
    await tester.pumpAndSettle();
    await gesture.up();

    final resizeCall = calls.lastWhere(
      (call) => call.method == 'startResizing',
    );
    expect(resizeCall.arguments['resizeEdge'], 'left');
    expect(resizeCall.arguments['left'], isTrue);
  });

  testWidgets('Windows scrollbar stays clear of the resize frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [versionProvider.overrideWithBuild((_, _) => 15)],
        child: MaterialApp(
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          theme: ThemeData(platform: TargetPlatform.windows),
          home: WindowHeaderContainer(
            windowsResizeFrame: true,
            child: CommonScrollBar(
              controller: controller,
              thumbVisibility: true,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemExtent: 40,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scrollbarTheme = tester.widget<ScrollbarTheme>(
      find.byType(ScrollbarTheme),
    );
    final rightResizeArea = find.byKey(const ValueKey('window-resize-right'));
    expect(
      scrollbarTheme.data.crossAxisMargin,
      greaterThan(tester.getSize(rightResizeArea).width),
    );

    final scrollbarRight =
        tester.getTopRight(find.byType(Scrollbar)).dx -
        scrollbarTheme.data.crossAxisMargin!;
    final resizeAreaLeft = tester.getTopLeft(rightResizeArea).dx;
    expect(scrollbarRight, lessThan(resizeAreaLeft));
  });
}
