import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/cli/validators.dart';
import 'package:w_cli/src/project/project_creator.dart';

void main() {
  group('insideExistingProject', () {
    late Directory original;
    late Directory sandbox;

    setUp(() {
      original = Directory.current;
      sandbox = Directory.systemTemp.createTempSync('w_cli_guard');
      Directory.current = sandbox;
    });

    tearDown(() {
      Directory.current = original;
      sandbox.deleteSync(recursive: true);
    });

    test('有 pubspec.yaml 就算在工程里', () {
      File('pubspec.yaml').writeAsStringSync('name: outer\n');
      expect(insideExistingProject(), isTrue);
    });

    test('空目录不算', () {
      expect(insideExistingProject(), isFalse);
    });
  });

  group('ProjectCreator 的入口守卫', () {
    late Directory original;
    late Directory sandbox;

    setUp(() {
      original = Directory.current;
      sandbox = Directory.systemTemp.createTempSync('w_cli_guard_create');
      Directory.current = sandbox;
    });

    tearDown(() {
      Directory.current = original;
      sandbox.deleteSync(recursive: true);
    });

    test('已在工程目录里时拒绝，且不创建目标目录', () async {
      File('pubspec.yaml').writeAsStringSync('name: outer\n');

      final code = await ProjectCreator(
        name: 'nested',
        runBuildRunner: false,
        openAfterCreate: false,
      ).run();

      expect(code, 1);
      expect(Directory('nested').existsSync(), isFalse);
    });
  });
}
