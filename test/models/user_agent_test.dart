import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('User-Agent preset round trips through JSON', () {
    const preset = UserAgentPreset(
      id: 'custom',
      name: 'My client',
      value: 'MyClient/1.0',
    );

    final restored = UserAgentPreset.fromJson(preset.toJson());

    expect(restored.id, preset.id);
    expect(restored.name, preset.name);
    expect(restored.value, preset.value);
  });

  test('built-in User-Agent presets have unique values', () {
    final values = builtInUserAgentPresets.map((item) => item.value).toList();

    expect(values, isNotEmpty);
    expect(values.toSet(), hasLength(values.length));
  });
}
