import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/version.dart';

/// `lib/src/version.dart` 由 `tool/generate_version.dart` 从 pubspec 生成，
/// 但生成是手动的——没有测试的话很容易和 pubspec 漂移（发版时忘了跑）。
void main() {
  test('version.dart 与 pubspec.yaml 一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml 里没有 version:');
    expect(version, match!.group(1));
  });
}
