import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_ext/window_ext.dart';
import 'package:window_manager/window_manager.dart';

class WindowManager extends ConsumerStatefulWidget {
  final Widget child;

  const WindowManager({super.key, required this.child});

  @override
  ConsumerState<WindowManager> createState() => _WindowContainerState();
}

class _WindowContainerState extends ConsumerState<WindowManager>
    with WindowListener, WindowExtListener {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentBrightnessProvider, (_, next) {
      if (system.isWindows) {
        windowExtManager.setWindowBrightness(dark: next == Brightness.dark);
      }
    }, fireImmediately: true);
    ref.listenManual(appSettingProvider.select((state) => state.autoLaunch), (
      prev,
      next,
    ) {
      if (prev != next) {
        debouncer.call(FunctionTag.autoLaunch, () {
          autoLaunch?.updateStatus(next);
        });
      }
    });
    windowExtManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    await ref.read(systemActionProvider.notifier).handleClose();
    super.onWindowClose();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    commonPrint.log('focus');
    render?.resume();
  }

  @override
  Future<void> onShouldTerminate() async {
    await ref.read(systemActionProvider.notifier).handleExit();
    super.onShouldTerminate();
  }

  @override
  void onWindowMoved() {
    super.onWindowMoved();
    windowManager.getPosition().then((offset) {
      ref
          .read(windowSettingProvider.notifier)
          .update((state) => state.copyWith(top: offset.dy, left: offset.dx));
    });
  }

  @override
  Future<void> onWindowResized() async {
    super.onWindowResized();
    final size = await windowManager.getSize();
    ref
        .read(windowSettingProvider.notifier)
        .update(
          (state) => state.copyWith(width: size.width, height: size.height),
        );
  }

  @override
  void onWindowMinimize() async {
    ref.read(storeActionProvider.notifier).savePreferencesDebounce();
    commonPrint.log('minimize');
    render?.pause();
    super.onWindowMinimize();
  }

  @override
  void onWindowRestore() {
    commonPrint.log('restore');
    render?.resume();
    super.onWindowRestore();
  }

  @override
  Future<void> dispose() async {
    windowManager.removeListener(this);
    windowExtManager.removeListener(this);
    super.dispose();
  }
}

class WindowHeaderContainer extends StatefulWidget {
  final Widget child;

  const WindowHeaderContainer({super.key, required this.child});

  @override
  State<WindowHeaderContainer> createState() => _WindowHeaderContainerState();
}

class _WindowHeaderContainerState extends State<WindowHeaderContainer>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (system.isWindows) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((value) {
        if (mounted) setState(() => _isMaximized = value);
      });
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void dispose() {
    if (system.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Consumer(
      builder: (_, ref, child) {
        final isMobileView = ref.watch(isMobileViewProvider);
        final version = ref.watch(versionProvider);
        if ((version <= 10 || !isMobileView) && system.isMacOS) {
          return child!;
        }
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(height: kHeaderHeight),
                Expanded(flex: 1, child: child!),
              ],
            ),
            const WindowHeader(),
          ],
        );
      },
      child: widget.child,
    );
    if (!system.isWindows) return content;
    final radius = _isMaximized ? BorderRadius.zero : BorderRadius.circular(12);
    return ColoredBox(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: radius,
            border: _isMaximized
                ? null
                : Border.all(color: context.colorScheme.outlineVariant),
          ),
          child: content,
        ),
      ),
    );
  }
}

class WindowHeader extends StatefulWidget {
  const WindowHeader({super.key});

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> {
  final isMaximizedNotifier = ValueNotifier<bool>(false);
  final isPinNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _initNotifier();
  }

  Future<void> _initNotifier() async {
    isMaximizedNotifier.value = await windowManager.isMaximized();
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  @override
  void dispose() {
    isMaximizedNotifier.dispose();
    isPinNotifier.dispose();
    super.dispose();
  }

  Future<void> _updateMaximized() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    final res = await windowManager.isMaximized();
    if (mounted) {
      isMaximizedNotifier.value = res;
    }
  }

  Future<void> _updatePin() async {
    final isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
    isPinNotifier.value = await windowManager.isAlwaysOnTop();
  }

  Widget _buildActions() {
    return Theme(
      data: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: context.colorScheme.onSurfaceVariant,
            hoverColor: context.colorScheme.primary.withAlpha(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              _updatePin();
            },
            icon: ValueListenableBuilder(
              valueListenable: isPinNotifier,
              builder: (_, value, _) {
                return value
                    ? const Icon(Icons.push_pin)
                    : const Icon(Icons.push_pin_outlined);
              },
            ),
          ),
          IconButton(
            onPressed: () {
              windowManager.minimize();
            },
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            onPressed: () async {
              _updateMaximized();
            },
            icon: ValueListenableBuilder(
              valueListenable: isMaximizedNotifier,
              builder: (_, value, _) {
                return value
                    ? const Icon(Icons.filter_none, size: 20)
                    : const Icon(Icons.crop_square);
              },
            ),
          ),
          IconButton(
            onPressed: () {
              globalState.container
                  .read(systemActionProvider.notifier)
                  .handleClose();
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Positioned(
            child: GestureDetector(
              onPanStart: (_) {
                windowManager.startDragging();
              },
              onDoubleTap: () {
                _updateMaximized();
              },
              child: Container(
                color: context.colorScheme.surfaceContainerLow.withAlpha(196),
                alignment: Alignment.centerLeft,
                height: kHeaderHeight,
              ),
            ),
          ),
          if (system.isMacOS)
            const Text(appName)
          else ...[
            Positioned(right: 0, child: _buildActions()),
          ],
        ],
      ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
      ),
    );
  }
}
