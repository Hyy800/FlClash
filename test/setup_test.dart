import 'dart:io';

import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('defaults to the stable application environment', () {
      final results = setup.createSetupArgParser().parse([]);

      expect(results['env'], 'stable');
    });

    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('accepts dev application environment', () {
      final results = setup.createSetupArgParser().parse([
        'android',
        '--env',
        'dev',
      ]);

      expect(results['env'], 'dev');
    });

    test('Flutter build environment does not depend on Core SHA256', () {
      expect(setup.createBuildEnvironment('dev'), {'APP_ENV': 'dev'});
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('Windows distributor command preserves batch exit codes', () {
      final command = setup.createDistributorCommand([
        'package',
        '--targets',
        'zip',
      ], isWindows: true);

      expect(command.$1, 'cmd.exe');
      expect(command.$2, [
        '/d',
        '/c',
        'call',
        'flutter_distributor.bat',
        'package',
        '--targets',
        'zip',
      ]);
    });

    test('non-Windows distributor command runs the executable directly', () {
      final command = setup.createDistributorCommand([
        'package',
      ], isWindows: false);

      expect(command.$1, 'flutter_distributor');
      expect(command.$2, ['package']);
    });

    test(
      'installed distributor is reused without network activation',
      () async {
        expect(await setup.ensureDistributorAvailable(), 0);
      },
    );

    test('Windows packaging disables broken MSBuild file tracking', () {
      expect(setup.createDistributorEnvironment(isWindows: true), {
        'TrackFileAccess': 'false',
      });
    });

    test('Android packaging preserves the requested architecture', () {
      expect(
        setup.createDistributorEnvironment(
          isWindows: false,
          androidArch: 'arm64',
        ),
        {'ANDROID_ARCH': 'arm64'},
      );
    });

    test('Windows installer replaces files from a running installation', () {
      final script = File(
        'windows/packaging/exe/inno_setup.iss',
      ).readAsStringSync();

      expect(script, contains('CloseApplications=yes'));
      expect(script, isNot(contains('CloseApplications=force')));
      expect(script, contains('RestartApplications=no'));
      expect(
        script,
        contains(r'{userappdata}\com.follow\clash\update.shutdown'),
      );
      expect(script, contains('RequestGracefulShutdown()'));
      expect(script, contains(r'SendMessage(WindowHandle, $0010, 0, 0);'));
      expect(script, contains("FindWindowByWindowName('FlClash')"));
      expect(script, contains("Processes := ['FlClashCore.exe',"));
      expect(script, isNot(contains("Processes := ['FlClash.exe',")));
      expect(script, contains("ExpandConstant('{sys}\\taskkill.exe')"));
      expect(script, contains('/f /t /im'));
    });

    test('Windows frameless style remains resizable', () {
      final source = File(
        'plugins/window_ext/windows/window_ext_plugin.cpp',
      ).readAsStringSync();

      expect(source, contains('style &= ~WS_CAPTION;'));
      expect(source, contains('style |= WS_THICKFRAME'));
      expect(source, isNot(contains('~(WS_CAPTION | WS_THICKFRAME)')));
    });
  });
}
