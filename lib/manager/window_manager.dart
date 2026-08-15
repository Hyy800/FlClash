import 'dart:async';
import 'dart:io';

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
  bool _updateShutdownRequested = false;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
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
    _updateShutdownRequested =
        _updateShutdownRequested ||
        await consumeUpdateShutdownRequest(
          File(await appPath.updateShutdownRequestPath),
        );
    final systemAction = ref.read(systemActionProvider.notifier);
    if (_updateShutdownRequested) {
      await systemAction.handleExit(true);
    } else {
      await systemAction.handleClose();
    }
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

class WindowHeaderContainer extends StatelessWidget {
  final Widget child;
  final bool? windowsResizeFrame;

  const WindowHeaderContainer({
    super.key,
    required this.child,
    this.windowsResizeFrame,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, child) {
        final isMobileView = ref.watch(isMobileViewProvider);
        final version = ref.watch(versionProvider);
        if ((version <= 10 || !isMobileView) && system.isMacOS) {
          return child!;
        }
        final content = Stack(
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
        if (windowsResizeFrame ?? system.isWindows) {
          return _WindowResizeFrame(child: content);
        }
        return content;
      },
      child: child,
    );
  }
}

class _WindowResizeFrame extends StatelessWidget {
  final Widget child;

  const _WindowResizeFrame({required this.child});

  Widget _buildResizeArea(ResizeEdge edge, MouseCursor cursor, String key) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        key: ValueKey(key),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startResizing(edge),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const edgeSize = 8.0;
    const cornerSize = 12.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: edgeSize,
          child: _buildResizeArea(
            ResizeEdge.left,
            SystemMouseCursors.resizeLeft,
            'window-resize-left',
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: edgeSize,
          child: _buildResizeArea(
            ResizeEdge.right,
            SystemMouseCursors.resizeRight,
            'window-resize-right',
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: edgeSize,
          child: _buildResizeArea(
            ResizeEdge.top,
            SystemMouseCursors.resizeUp,
            'window-resize-top',
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: edgeSize,
          child: _buildResizeArea(
            ResizeEdge.bottom,
            SystemMouseCursors.resizeDown,
            'window-resize-bottom',
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeArea(
            ResizeEdge.topLeft,
            SystemMouseCursors.resizeUpLeft,
            'window-resize-top-left',
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeArea(
            ResizeEdge.topRight,
            SystemMouseCursors.resizeUpRight,
            'window-resize-top-right',
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeArea(
            ResizeEdge.bottomLeft,
            SystemMouseCursors.resizeDownLeft,
            'window-resize-bottom-left',
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeArea(
            ResizeEdge.bottomRight,
            SystemMouseCursors.resizeDownRight,
            'window-resize-bottom-right',
          ),
        ),
      ],
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
      if (system.isWindows) {
        windowExtManager.setWindowCornerPreference(round: true);
      }
    } else {
      await windowManager.maximize();
      if (system.isWindows) {
        windowExtManager.setWindowCornerPreference(round: false);
      }
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
    return Row(
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
        // const SizedBox(
        //   width: 8,
        // ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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
                color: context.colorScheme.secondary.opacity15,
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
    return Container(
      decoration: ShapeDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Transform.translate(
        offset: const Offset(0, -1),
        child: Image.asset('assets/images/icon.png', width: 34, height: 34),
      ),
    );
  }
}
