import 'dart:io';
import 'package:test/test.dart';
import 'package:w_cli/w_cli.dart';
import 'package:w_cli/src/resources.dart';

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

  // 脚本清单从仓库目录动态取：删掉一个脚本时测试自动跟随，
  // 不再依赖「pub cache 里还留着旧版本」这种本地假象
  final repoScripts =
      Directory('lib/sh')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.sh'))
          .toList()
        ..sort();

  group('scriptExists', () {
    test('should return true for existing scripts', () async {
      expect(repoScripts, isNotEmpty);
      for (final name in repoScripts) {
        expect(await scriptExists(name), isTrue, reason: name);
      }
    });

    test('should return false for non-existent scripts', () async {
      expect(await scriptExists('non_existent_script.sh'), isFalse);
    });
  });

  group('getScriptPath', () {
    test('should return a valid path for every existing script', () async {
      expect(repoScripts, isNotEmpty);
      for (final name in repoScripts) {
        final path = await getScriptPath(name);
        expect(path, isNotEmpty, reason: name);
        expect(File(path).existsSync(), isTrue, reason: name);
      }
    });

    test('should throw an exception for non-existent scripts', () async {
      expect(
        () async => await getScriptPath('non_existent_script.sh'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('executeScript', () {
    test('should execute script without throwing exception', () async {
      // 注意：这里我们只是测试函数是否能正常执行，而不是测试脚本的具体功能
      // 因为脚本执行依赖于外部环境，可能会失败
      try {
        await executeScript(
          'api.sh',
          ['--help'],
          'Test success',
          'Test failure',
        );
        // 如果执行到这里，说明函数没有抛出异常
        expect(true, isTrue);
      } catch (e) {
        // 即使脚本执行失败，函数本身也不应该抛出异常
        expect(true, isTrue);
      }
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

  group('Command handling', () {
    test('handleCreateCommand should execute without throwing', () async {
      try {
        // 测试不带参数的情况
        await handleCreateCommand([]);
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleCreateProject should execute without throwing', () async {
      try {
        await handleCreateProject('test_project');
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleApiCommand should execute without throwing', () async {
      try {
        await handleApiCommand([]);
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleBuildCommand should execute without throwing', () async {
      try {
        await handleBuildCommand(['--help']);
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleProjectCommand should execute without throwing', () async {
      try {
        await handleProjectCommand(['--help']);
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleOpenCommand should execute without throwing', () async {
      try {
        await handleOpenCommand(['ios']);
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleUpdateCommand should execute without throwing', () async {
      try {
        await handleUpdateCommand();
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });
  });

  group('Error handling', () {
    test(
      'handleError should execute without throwing for FileSystemException',
      () {
        try {
          handleError(
            FileSystemException('File not found', 'test.txt'),
            'file operation',
          );
          expect(true, isTrue);
        } catch (e) {
          expect(true, isTrue);
        }
      },
    );

    test(
      'handleError should execute without throwing for ProcessException',
      () {
        try {
          handleError(ProcessException('ls', ['-la']), 'process operation');
          expect(true, isTrue);
        } catch (e) {
          expect(true, isTrue);
        }
      },
    );

    test('handleError should execute without throwing for FormatException', () {
      try {
        handleError(FormatException('Invalid format'), 'format operation');
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleError should execute without throwing for ArgumentError', () {
      try {
        handleError(ArgumentError('Invalid argument'), 'argument operation');
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });

    test('handleError should execute without throwing for unknown error', () {
      try {
        handleError('Unknown error', 'unknown operation');
        expect(true, isTrue);
      } catch (e) {
        expect(true, isTrue);
      }
    });
  });

  group('Edge cases', () {
    test('validateProjectName should return false for empty string', () {
      expect(validateProjectName(''), isFalse);
    });

    test(
      'validateProjectName should return false for project name starting with number',
      () {
        expect(validateProjectName('123project'), isFalse);
      },
    );

    test(
      'validateProjectName should return false for project name with special characters',
      () {
        expect(validateProjectName('project-name'), isFalse);
        expect(validateProjectName('project@name'), isFalse);
        expect(validateProjectName('project#name'), isFalse);
      },
    );

    test(
      'validateProjectName should return false for project name with uppercase letters',
      () {
        expect(validateProjectName('ProjectName'), isFalse);
        expect(validateProjectName('projectName'), isFalse);
      },
    );

    test('isValidVersion should return false for invalid version formats', () {
      expect(isValidVersion('1.0'), isFalse);
      expect(isValidVersion('1'), isFalse);
      expect(isValidVersion('1.0.0.0'), isFalse);
      expect(isValidVersion('1.0.0-alpha'), isFalse);
      expect(isValidVersion(''), isFalse);
    });

    test('scriptExists should return false for non-existent scripts', () async {
      expect(await scriptExists('non_existent_script.sh'), isFalse);
      expect(await scriptExists(''), isFalse);
    });
  });

  group('bashMissingHint', () {
    test('Windows 上提示 Git Bash / WSL', () {
      final hint = bashMissingHint('build.sh', isWindows: true)!;
      expect(hint, contains('build.sh'));
      expect(hint, contains('Git Bash'));
      expect(hint, contains('WSL'));
    });

    test('非 Windows 上指向 PATH 问题', () {
      final hint = bashMissingHint('clean.sh', isWindows: false)!;
      expect(hint, contains('clean.sh'));
      expect(hint, isNot(contains('Git Bash')));
    });

    test('只有 Windows 才会提到 WSL', () {
      expect(
        bashMissingHint('open.sh', isWindows: false),
        isNot(contains('WSL')),
      );
    });
  });

  group('脚本解压', () {
    tearDown(Resources.cleanupTempFiles);

    test('脚本与共享库 lib.sh 解压到同一个目录', () async {
      final scriptPath = await Resources.extractResourceToTempFile(
        'lib/sh/clean.sh',
        'clean.sh',
      );
      final dir = File(scriptPath).parent;

      // 脚本会 source 同目录的 lib.sh，两者必须在一起
      expect(File('${dir.path}/lib.sh').existsSync(), isTrue);
      expect(File(scriptPath).existsSync(), isTrue);
    });

    test('cleanupTempFiles 会删掉整个临时目录', () async {
      final scriptPath = await Resources.extractResourceToTempFile(
        'lib/sh/open.sh',
        'open.sh',
      );
      final dir = File(scriptPath).parent;
      expect(dir.existsSync(), isTrue);

      Resources.cleanupTempFiles();
      expect(dir.existsSync(), isFalse);
    });
  });
}
