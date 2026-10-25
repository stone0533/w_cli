import 'package:test/test.dart';
import 'package:w_cli/src/api/api_cli.dart';

void main() {
  group('resolveApiArgs', () {
    test('默认生成 client 代码', () {
      expect(resolveApiArgs([]).mode, ApiMode.generate);
    });

    test('generate / g 是显式同义写法', () {
      expect(resolveApiArgs(['generate']).mode, ApiMode.generate);
      expect(resolveApiArgs(['g']).mode, ApiMode.generate);
    });

    test('init', () {
      final invocation = resolveApiArgs(['init']);
      expect(invocation.mode, ApiMode.init);
      expect(invocation.force, isFalse);
    });

    test('models', () {
      expect(resolveApiArgs(['models']).mode, ApiMode.models);
    });

    test('models --force', () {
      final invocation = resolveApiArgs(['models', '--force']);
      expect(invocation.mode, ApiMode.models);
      expect(invocation.force, isTrue);
    });

    test('--force 与顺序无关', () {
      expect(resolveApiArgs(['--force', 'models']).force, isTrue);
    });

    test('--debug 被忽略而不是报错', () {
      expect(resolveApiArgs(['-d', 'models']).mode, ApiMode.models);
    });

    test('--force 单独用等价于 generate --force', () {
      final invocation = resolveApiArgs(['--force']);
      expect(invocation.mode, ApiMode.generate);
      expect(invocation.force, isTrue);
    });

    test('--force 不能配合 init', () {
      expect(
        () => resolveApiArgs(['init', '--force']),
        throwsA(
          isA<ApiUsageError>().having(
            (error) => error.message,
            'message',
            contains('不能配合 init'),
          ),
        ),
      );
    });

    test('未知子命令报错并列出用法', () {
      expect(
        () => resolveApiArgs(['bogus']),
        throwsA(
          isA<ApiUsageError>().having(
            (error) => error.message,
            'message',
            contains('ww api models'),
          ),
        ),
      );
    });

    test('多个子命令报错', () {
      expect(
        () => resolveApiArgs(['init', 'models']),
        throwsA(isA<ApiUsageError>()),
      );
    });

    test('旧写法被拒绝，并给出新写法', () {
      for (final entry in {
        '--init': 'ww api init',
        '--models': 'ww api models',
        '--full': 'ww api models --force',
      }.entries) {
        expect(
          () => resolveApiArgs([entry.key]),
          throwsA(
            isA<ApiUsageError>().having(
              (error) => error.message,
              'message',
              contains(entry.value),
            ),
          ),
          reason: entry.key,
        );
      }
    });
  });

  group('legacyFlagHint', () {
    test('从参数解析异常里认出旧写法', () {
      expect(
        legacyFlagHint('Could not find an option or flag "--models".'),
        contains('ww api models'),
      );
      expect(
        legacyFlagHint('Could not find an option or flag "--full".'),
        contains('ww api models --force'),
      );
    });

    test('普通错误不误判', () {
      expect(
        legacyFlagHint('Could not find an option or flag "--nope".'),
        isNull,
      );
    });
  });
}
