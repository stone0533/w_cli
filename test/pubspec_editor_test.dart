import 'package:test/test.dart';
import 'package:w_cli/src/project/pubspec_editor.dart';

/// 真实 Flutter 工程的 pubspec 形状：`dependencies` 里有一个叫 flutter 的依赖，
/// 配置段也是 `flutter:`。以前按 trim 比较会把 assets 塞进 dependencies。
const _flutterPubspec = '''
name: demo
environment:
  sdk: ^3.10.0

dependencies:
  flutter:
    sdk: flutter
  retrofit: 4.9.0

dev_dependencies:
  build_runner: ^2.4.0

flutter:
  uses-material-design: true
''';

void main() {
  test('assets 进 flutter 配置段，不进 dependencies', () {
    final updated = ensureAssets(_flutterPubspec);
    final lines = updated.split('\n');

    final assetsIndex = lines.indexOf('  assets:');
    final flutterIndex = lines.indexOf('flutter:');
    final depsIndex = lines.indexOf('dependencies:');

    expect(assetsIndex, greaterThan(flutterIndex));
    expect(flutterIndex, greaterThan(depsIndex));
    expect(lines.sublist(assetsIndex + 1, assetsIndex + 4), [
      '    - .env',
      '    - assets/',
      '    - assets/images/',
    ]);

    // dependencies 段里的 flutter 依赖没被动过
    expect(updated, contains('  flutter:\n    sdk: flutter'));
    // assets 条目不能出现在 dependencies 与 flutter 配置段之间
    final firstAssetsAfterDependencies = lines
        .sublist(depsIndex, flutterIndex)
        .any((line) => line.trim().startsWith('- .env'));
    expect(firstAssetsAfterDependencies, isFalse);
  });

  test('幂等：连续调用结果一致', () {
    final once = ensureAssets(_flutterPubspec);
    expect(ensureAssets(once), once);
  });

  test('已有的 assets 段被重写且不重复', () {
    const withAssets = '''
name: demo
flutter:
  uses-material-design: true
  assets:
    - lib/
    - .env
''';
    final updated = ensureAssets(withAssets);
    expect(RegExp('assets:').allMatches(updated).length, 1);
    expect(updated, contains('    - assets/'));
    expect(updated, contains('    - assets/images/'));
    expect(updated, isNot(contains('    - lib/')));
  });

  test('没有 flutter 配置段时追加', () {
    const noFlutter = 'name: demo\n';
    final updated = ensureAssets(noFlutter);
    expect(updated, contains('flutter:\n  assets:\n    - .env'));
  });
}
