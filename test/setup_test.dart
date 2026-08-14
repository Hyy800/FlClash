import 'dart:io';

import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
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

    test('Windows installer replaces files from a running installation', () {
      final script = File(
        'windows/packaging/exe/inno_setup.iss',
      ).readAsStringSync();

      expect(script, contains('CloseApplications=force'));
      expect(script, contains('RestartApplications=no'));
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
