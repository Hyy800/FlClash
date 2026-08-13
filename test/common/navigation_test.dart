import 'package:fl_clash/common/navigation.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI is a dedicated desktop navigation item', () {
    final items = navigation.getItems(hasProxies: true);
    final aiItem = items.singleWhere((item) => item.label == PageLabel.ai);

    expect(aiItem.modes, [NavigationItemMode.desktop]);
    expect(navigationLabel(PageLabel.ai), 'AI');
    expect(
      items.indexOf(aiItem),
      lessThan(items.indexWhere((item) => item.label == PageLabel.tools)),
    );
  });

  test('global rules is a dedicated desktop navigation item', () {
    final items = navigation.getItems(hasProxies: true);
    final globalRulesItem = items.singleWhere(
      (item) => item.label == PageLabel.globalRules,
    );

    expect(globalRulesItem.modes, [NavigationItemMode.desktop]);
    expect(
      items.indexOf(globalRulesItem),
      greaterThan(items.indexWhere((item) => item.label == PageLabel.profiles)),
    );
  });
}
