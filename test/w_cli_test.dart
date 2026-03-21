import 'dart:io';
import 'package:test/test.dart';
import 'package:w_cli/w_cli.dart';

void main() {
  group('validateProjectName', () {
    test('should return true for valid project names', () {
      expect(validateProjectName('my_app'), isTrue);
      expect(validateProjectName('myapp123'), isTrue);
    });

    test('should return false for invalid project names', () {
      expect(validateProjectName(''), isFalse);
      expect(validateProjectName('MyApp'), isFalse);
      expect(validateProjectName('123app'), isFalse);
      expect(validateProjectName('my-app'), isFalse);
    });
  });

  group('isValidVersion', () {
    test('should return true for valid version strings', () {
      expect(isValidVersion('1.0.0'), isTrue);
      expect(isValidVersion('1.2.3'), isTrue);
      expect(isValidVersion('10.0.0'), isTrue);
    });

    test('should return false for invalid version strings', () {
      expect(isValidVersion('1.0'), isFalse);
      expect(isValidVersion('1'), isFalse);
      expect(isValidVersion('1.0.0.0'), isFalse);
      expect(isValidVersion('1.0.0-alpha'), isFalse);
    });
  });

  group('getVersionFromPubspec', () {
    test('should return a version string or unknown', () {
      final version = getVersionFromPubspec();
      expect(version, isNotNull);
      expect(version, isNotEmpty);
    });
  });

  group('scriptExists', () {
    test('should return true for existing scripts', () async {
      expect(await scriptExists('api_gen.sh'), isTrue);
      expect(await scriptExists('build.sh'), isTrue);
      expect(await scriptExists('open.sh'), isTrue);
      expect(await scriptExists('setup_project.sh'), isTrue);
    });

    test('should return false for non-existent scripts', () async {
      expect(await scriptExists('non_existent_script.sh'), isFalse);
    });
  });

  group('getScriptPath', () {
    test('should return a valid path for existing scripts', () async {
      final path = await getScriptPath('api_gen.sh');
      expect(path, isNotEmpty);
      expect(File(path).existsSync(), isTrue);
    });

    test('should throw an exception for non-existent scripts', () async {
      expect(() async => await getScriptPath('non_existent_script.sh'), throwsA(isA<FileSystemException>()));
    });
  });

  group('isValidProjectName', () {
    test('should return true for valid project names', () {
      expect(isValidProjectName('my_app'), isTrue);
      expect(isValidProjectName('myapp123'), isTrue);
    });

    test('should return false for invalid project names', () {
      expect(isValidProjectName(''), isFalse);
      expect(isValidProjectName('MyApp'), isFalse);
      expect(isValidProjectName('123app'), isFalse);
      expect(isValidProjectName('my-app'), isFalse);
    });
  });
}
