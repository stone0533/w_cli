import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/cli/validators.dart';

void main() {
  group('insideExistingProject', () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('w_cli_guard');
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    test('有 pubspec.yaml 就算在工程里', () {
      File('${sandbox.path}/pubspec.yaml').writeAsStringSync('name: outer\n');
      expect(insideExistingProject(dir: sandbox.path), isTrue);
    });

    test('空目录不算', () {
      expect(insideExistingProject(dir: sandbox.path), isFalse);
    });
  });
}
