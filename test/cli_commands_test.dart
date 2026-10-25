import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/commands/clean_command.dart';
import 'package:w_cli/src/commands/open_command.dart';
import 'package:w_cli/src/commands/project_command.dart';
import 'package:w_cli/src/commands/task_commands.dart';

import 'fake_process_runner.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('w_cli_cmd');
  });

  tearDown(() => project.deleteSync(recursive: true));

  void touch(String relative) {
    final file = File('${project.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('x\n');
  }

  group('CleanCommand', () {
    test('--lock 只删当前平台的锁文件', () async {
      touch('pubspec.yaml');
      touch('pubspec.lock');
      touch('ios/Podfile.lock');

      final runner = FakeProcessRunner();
      final code = await CleanCommand(
        root: project.path,
        runner: runner,
      ).run(['android', '--lock']);

      expect(code, 0);
      expect(File('${project.path}/pubspec.lock').existsSync(), isFalse);
      expect(File('${project.path}/ios/Podfile.lock').existsSync(), isTrue);
      expect(
        runner.starts.map((call) => call.args),
        containsAll([
          equals(['clean']),
          equals(['pub', 'get']),
        ]),
      );
    });

    test('ios --pod 删 Pods 并跑 pod update', () async {
      touch('pubspec.yaml');
      Directory('${project.path}/ios/Pods').createSync(recursive: true);
      touch('ios/Podfile.lock');

      final runner = FakeProcessRunner();
      final code = await CleanCommand(
        root: project.path,
        runner: runner,
      ).run(['ios', '--pod']);

      expect(code, 0);
      expect(Directory('${project.path}/ios/Pods').existsSync(), isFalse);
      expect(File('${project.path}/ios/Podfile.lock').existsSync(), isFalse);
      expect(
        runner.starts.any(
          (call) => call.exe == 'pod' && call.args.join(' ') == 'update',
        ),
        isTrue,
      );
    });

    test('--pod 配 android 是用法错误，不启动任何进程', () async {
      final runner = FakeProcessRunner();
      final code = await CleanCommand(
        root: project.path,
        runner: runner,
      ).run(['--pod', 'android']);

      expect(code, 2);
      expect(runner.starts, isEmpty);
    });

    test('未知参数退出 2', () async {
      final runner = FakeProcessRunner();
      expect(
        await CleanCommand(root: project.path, runner: runner).run(['bogus']),
        2,
      );
    });

    test('flutter 不可用退出 1', () async {
      final runner = FakeProcessRunner(available: {'dart'});
      expect(
        await CleanCommand(root: project.path, runner: runner).run(['all']),
        1,
      );
      expect(runner.starts, isEmpty);
    });
  });

  group('ProjectCommand：deps upgrade', () {
    test('只跑 pub upgrade，不动 gradle-wrapper', () async {
      touch('pubspec.yaml');
      File(
        '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
      ).createSync(recursive: true);
      File(
        '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
      ).writeAsStringSync(
        'distributionUrl=https\\://services.gradle.org/distributions/gradle-9.1.0-all.zip\n',
      );

      final runner = FakeProcessRunner(
        runStdout: '> dio 5.9.0 (was 5.8.0)\n> retrofit 5.0.0 (was 4.9.0)\n',
      );
      final code = await ProjectCommand(
        root: project.path,
        runner: runner,
      ).pubUpgrade();

      expect(code, 0);
      expect(
        runner.runs.map((call) => call.args.join(' ')),
        contains('pub upgrade'),
      );
      // Gradle 不能再被顺手改掉（Flutter 3.4x 的工程是 9.1.0，改成 8.0 就是降级）
      expect(
        File(
          '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync(),
        contains('gradle-9.1.0-all.zip'),
      );
    });

    test('--major 透传 --major-versions', () async {
      touch('pubspec.yaml');
      final runner = FakeProcessRunner();
      await ProjectCommand(
        root: project.path,
        runner: runner,
      ).pubUpgrade(major: true);
      expect(
        runner.runs.map((call) => call.args.join(' ')),
        contains('pub upgrade --major-versions'),
      );
    });

    test('--dry-run 只跑 pub outdated', () async {
      touch('pubspec.yaml');
      final runner = FakeProcessRunner(
        runStdout: 'Showing outdated packages\n',
      );
      expect(
        await ProjectCommand(
          root: project.path,
          runner: runner,
        ).pubUpgrade(dryRun: true),
        0,
      );
      expect(
        runner.runs.map((call) => call.args.join(' ')),
        contains('pub outdated'),
      );
      expect(
        runner.runs.map((call) => call.args.join(' ')),
        isNot(contains('pub upgrade')),
      );
    });

    test('没有 pubspec.yaml 时退出 1', () async {
      final runner = FakeProcessRunner();
      expect(
        await ProjectCommand(root: project.path, runner: runner).pubUpgrade(),
        1,
      );
    });

    test('flutter 不可用退出 1', () async {
      touch('pubspec.yaml');
      final runner = FakeProcessRunner(available: {'dart'});
      expect(
        await ProjectCommand(root: project.path, runner: runner).pubUpgrade(),
        1,
      );
    });
  });

  group('ProjectCommand：deps gradle', () {
    void writeWrapper(String url) {
      final file = File(
        '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('distributionUrl=$url\n');
    }

    test('默认只报告，不写文件', () async {
      writeWrapper(
        'https\\://services.gradle.org/distributions/gradle-8.0-all.zip',
      );
      final code = await ProjectCommand(
        root: project.path,
        runner: FakeProcessRunner(),
      ).gradle();
      expect(code, 0);
      expect(
        File(
          '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync(),
        contains('gradle-8.0-all.zip'),
      );
    });

    test('--to 升级并保留 all 类型', () async {
      writeWrapper(
        'https\\://services.gradle.org/distributions/gradle-8.0-all.zip',
      );
      final code = await ProjectCommand(
        root: project.path,
        runner: FakeProcessRunner(),
      ).gradle(to: '9.1.0');
      expect(code, 0);
      expect(
        File(
          '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync(),
        contains('gradle-9.1.0-all.zip'),
      );
    });

    test('--to 保留 bin 类型', () async {
      writeWrapper(
        'https\\://services.gradle.org/distributions/gradle-8.0-bin.zip',
      );
      await ProjectCommand(
        root: project.path,
        runner: FakeProcessRunner(),
      ).gradle(to: '9.1.0');
      expect(
        File(
          '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync(),
        contains('gradle-9.1.0-bin.zip'),
      );
    });

    test('降级被拒绝（除非 --force）', () async {
      writeWrapper(
        'https\\://services.gradle.org/distributions/gradle-9.1.0-all.zip',
      );
      final command = ProjectCommand(
        root: project.path,
        runner: FakeProcessRunner(),
      );
      expect(await command.gradle(to: '8.0'), 1);
      expect(await command.gradle(to: '8.0', force: true), 0);
      expect(
        File(
          '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync(),
        contains('gradle-8.0-all.zip'),
      );
    });

    test('没有 android 目录时跳过（退出 0）', () async {
      expect(
        await ProjectCommand(
          root: project.path,
          runner: FakeProcessRunner(),
        ).gradle(to: '9.1.0'),
        0,
      );
    });
  });

  group('TaskRunner', () {
    test('fmt 跑 dart format .，工作目录是项目根', () async {
      final runner = FakeProcessRunner();
      final code = await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('fmt')!);

      expect(code, 0);
      expect(runner.starts.single.exe, 'dart');
      expect(runner.starts.single.args.join(' '), 'format .');
      expect(runner.starts.single.cwd, project.path);
    });

    test('get 跑 flutter pub get', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('get')!);
      expect(runner.starts.single.exe, 'flutter');
      expect(runner.starts.single.args.join(' '), 'pub get');
    });

    test('pod 用 --project-directory，不 cd', () async {
      Directory('${project.path}/ios').createSync();
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('pod')!);
      expect(
        runner.starts.single.args.join(' '),
        'install --project-directory=ios',
      );
    });

    test('工具不可用时退出 1 且不启动进程', () async {
      final runner = FakeProcessRunner(available: {'flutter'});
      expect(
        await TaskRunner(
          root: project.path,
          runner: runner,
        ).run(builtinTask('fmt')!),
        1,
      );
      expect(runner.starts, isEmpty);
    });

    test('位置参数替换默认目标', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('fmt')!, extra: ['lib/app']);
      expect(runner.starts.single.args.join(' '), 'format lib/app');
    });

    test('flag 追加在最后', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('analyze')!, extra: ['--fatal-infos']);
      expect(runner.starts.single.args.join(' '), 'analyze --fatal-infos');
    });

    test('gen 走 capture：输出落盘、不直连终端', () async {
      final runner = FakeProcessRunner(
        runStdout: 'Built with build_runner in 2s; wrote 0 outputs.\n',
      );
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('gen')!);

      final call = runner.runs.single;
      expect(call.exe, 'dart');
      expect(
        call.args.join(' '),
        'run build_runner build --delete-conflicting-outputs',
      );
      expect(runner.starts, isEmpty, reason: 'capture 模式不走 inheritStdio');
      expect(
        File('${project.path}/w_build/gen.log').readAsStringSync(),
        contains('Built with build_runner'),
      );
    });

    test('pod 在没有 ios 目录时直接失败', () async {
      final runner = FakeProcessRunner();
      expect(
        await TaskRunner(
          root: project.path,
          runner: runner,
        ).run(builtinTask('pod')!),
        1,
      );
      expect(runner.starts, isEmpty);
    });

    test('fmt --check 不改文件（--output=none --set-exit-if-changed）', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('fmt')!, check: true);
      expect(
        runner.starts.single.args.join(' '),
        'format --output=none --set-exit-if-changed .',
      );
    });

    test('fmt --check 带路径时保留路径', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('fmt')!, extra: ['lib'], check: true);
      expect(
        runner.starts.single.args.join(' '),
        'format --output=none --set-exit-if-changed lib',
      );
    });

    test('test / l10n / outdated 的 argv', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('test')!, extra: ['test/foo_test.dart']);
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('l10n')!);
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(builtinTask('outdated')!);
      expect(runner.starts.map((c) => '${c.exe} ${c.args.join(' ')}'), [
        'flutter test test/foo_test.dart',
        'flutter gen-l10n',
        'flutter pub outdated',
      ]);
    });

    test('进程失败时退出码透传', () async {
      final runner = FakeProcessRunner(startExitCode: 3);
      expect(
        await TaskRunner(
          root: project.path,
          runner: runner,
        ).run(builtinTask('analyze')!),
        3,
      );
    });
  });

  group('OpenCommand', () {
    test('build 目录不存在时退出 1，且不调用打开命令', () async {
      final runner = FakeProcessRunner();
      expect(
        await OpenCommand(root: project.path, runner: runner).run(['build']),
        1,
      );
      expect(runner.runs, isEmpty);
    });

    test('root 存在时调用系统打开命令', () async {
      final runner = FakeProcessRunner();
      expect(
        await OpenCommand(root: project.path, runner: runner).run(['r']),
        0,
      );
      final expected = Platform.isMacOS ? 'open' : 'xdg-open';
      expect(runner.runs.single.exe, expected);
      expect(runner.runs.single.args, [project.path]);
    });

    test('ios 在非 macOS 上退出 1', () async {
      Directory(
        '${project.path}/ios/Runner.xcworkspace',
      ).createSync(recursive: true);
      final runner = FakeProcessRunner();
      final code = await OpenCommand(
        root: project.path,
        runner: runner,
      ).run(['ios']);
      expect(code, Platform.isMacOS ? 0 : 1);
    });

    test('未知目标退出 2', () async {
      expect(
        await OpenCommand(
          root: project.path,
          runner: FakeProcessRunner(),
        ).run(['bogus']),
        2,
      );
    });
  });
}
