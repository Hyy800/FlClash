import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = ref.read(isStartProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(isStartProvider, (prev, next) {
      if (next != isStart) {
        isStart = next;
        updateController();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    updateController();
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.container
          .read(setupActionProvider.notifier)
          .updateStatus(isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  void updateController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStart && mounted) {
        _controller?.forward();
      } else {
        _controller?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return const SizedBox.shrink();
    }
    final suspend = ref.watch(suspendProvider);
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller!.view,
        builder: (_, child) {
          final progress = _animation.value.clamp(0.0, 1.0).toDouble();
          final activeColor = suspend
              ? colorScheme.tertiary
              : const Color(0xFF16866F);
          final accentColor = Color.lerp(
            colorScheme.primary,
            activeColor,
            progress,
          )!;
          final foregroundColor = Color.lerp(
            colorScheme.onPrimaryContainer,
            Colors.white,
            progress,
          )!;
          final shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          );
          return Semantics(
            button: true,
            toggled: isStart,
            child: SizedBox(
              height: 50,
              child: AnimatedContainer(
                duration: midDuration,
                curve: Curves.easeOutCubic,
                decoration: ShapeDecoration(
                  color: accentColor,
                  shape: shape.copyWith(
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: handleSwitchStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(35),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: Colors.white.withAlpha(40),
                              ),
                            ),
                            child: IconTheme(
                              data: IconThemeData(color: foregroundColor),
                              child: AnimatedIcon(
                                icon: AnimatedIcons.play_pause,
                                progress: _animation,
                              ),
                            ),
                          ),
                          ClipRect(
                            child: Align(
                              widthFactor: progress,
                              child: Opacity(
                                opacity: progress,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 8,
                                  ),
                                  child: DefaultTextStyle(
                                    style: context.textTheme.titleMedium!
                                        .copyWith(
                                          color: foregroundColor,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                    child: child!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: suspend
            ? Text(
                appLocalizations.suspended,
                maxLines: 1,
                overflow: TextOverflow.visible,
              )
            : Consumer(
                builder: (_, ref, _) {
                  final runTime = ref.watch(runTimeProvider);
                  return Text(
                    utils.getTimeText(runTime),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  );
                },
              ),
      ),
    );
  }
}
