import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/cli/process.dart';
import 'package:w_cli/src/commands/clean_command.dart';
import 'package:w_cli/src/commands/open_command.dart';
import 'package:w_cli/src/commands/project_command.dart';

/// 记录调用、按需返回退出码的假实现——命令类不再直接摸 `Process`，
/// 于是「删了哪些文件、拼了哪些参数、退出码怎么传」都能直接断言。
class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner({
    this.available = const {'flutter', 'dart', 'pod', 'open', 'xdg-open'},
    this.startExitCode = 0,
    this.runExitCode = 0,
    this.runStdout = '',
    this.onCreate,
  });

  final Set<String> available;
  final int startExitCode;
  final int runExitCode;
  final String runStdout;
  final void Function(String executable, List<String> arguments)? onCreate;

  final List<({String exe, List<String> args, String? cwd})> starts = [];
  final List<({String exe, List<String> args, String? cwd})> runs = [];
  final List<String> whichCalls = [];

  bool get startedFlutterCreate =>
      starts.any((call) => call.args.contains('create'));

  @override
  Future<int> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = true,
    Duration? timeout,
  }) async {
    starts.add((exe: executable, args: arguments, cwd: workingDirectory));
    onCreate?.call(executable, arguments);
    return startExitCode;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    runs.add((exe: executable, args: arguments, cwd: workingDirectory));
    return ProcessResult(0, runExitCode, runStdout, '');
  }

  @override
  bool which(String name) {
    whichCalls.add(name);
    return available.contains(name);
  }
}

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

  group('ProjectCommand', () {
    test('--update 升级依赖并改写 gradle wrapper', () async {
      touch('pubspec.yaml');
      touch('android/gradle/wrapper/gradle-wrapper.properties');
      File(
        '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
      ).writeAsStringSync(
        'distributionUrl=https\\://services.gradle.org/distributions/gradle-7.6.1-all.zip\n',
      );

      final runner = FakeProcessRunner(runStdout: 'Flutter 3.24.0\n');
      final code = await ProjectCommand(
        root: project.path,
        runner: runner,
      ).run(['--update']);

      expect(code, 0);
      expect(
        runner.starts.map((call) => call.args.join(' ')),
        contains('pub upgrade'),
      );
      expect(
        File(
          '${project.path}/android/gradle/wrapper/gradle-wrapper.properties',
        ).readAsStringSync(),
        contains('gradle-8.0-all.zip'),
      );
    });

    test('没有 pubspec.yaml 时退出 1', () async {
      final runner = FakeProcessRunner();
      expect(
        await ProjectCommand(
          root: project.path,
          runner: runner,
        ).run(['--update']),
        1,
      );
    });

    test('没有 android 目录只告警、仍退出 0', () async {
      touch('pubspec.yaml');
      final runner = FakeProcessRunner(runStdout: 'Flutter 3.24.0\n');
      expect(
        await ProjectCommand(
          root: project.path,
          runner: runner,
        ).run(['--update']),
        0,
      );
    });

    test('未知参数退出 2', () async {
      expect(
        await ProjectCommand(
          root: project.path,
          runner: FakeProcessRunner(),
        ).run(['--bogus']),
        2,
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
