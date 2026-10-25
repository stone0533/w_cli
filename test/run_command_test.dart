import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/commands/run_command.dart';

import 'fake_process_runner.dart';

void main() {
  group('parseTasks', () {
    test('解析名字与命令，忽略注释和空行', () {
      final parsed = parseTasks('# 注释\nmap = dart run x\n\ngen = echo gen\n');
      expect(parsed.tasks.map((task) => task.name), ['map', 'gen']);
      expect(parsed.warnings, isEmpty);
    });

    test('只按第一个 = 切分，命令里可以有 =', () {
      final parsed = parseTasks('build = flutter build apk --define=FOO=1\n');
      expect(parsed.tasks.single.command, 'flutter build apk --define=FOO=1');
    });

    test('坏行跳过并给警告', () {
      final parsed = parseTasks('没有等号\n= 空名字\nx=\nabc = ok\n');
      expect(parsed.tasks.map((task) => task.name), ['abc']);
      expect(parsed.warnings, hasLength(3));
    });

    test('重名保留第一条并警告', () {
      final parsed = parseTasks('a = first\na = second\n');
      expect(parsed.tasks.single.command, 'first');
      expect(parsed.warnings.single, contains('重复'));
    });
  });

  group('RunCommand', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('w_cli_run');
    });

    tearDown(() => project.deleteSync(recursive: true));

    void writeTasks(String content) {
      Directory('${project.path}/.ww').createSync(recursive: true);
      File('${project.path}/.ww/tasks').writeAsStringSync(content);
    }

    test('列任务不发进程', () async {
      writeTasks('map = echo hi\n');
      final runner = FakeProcessRunner();
      expect(await RunCommand(root: project.path, runner: runner).run([]), 0);
      expect(runner.starts, isEmpty);
    });

    test('执行任务走 shell，工作目录是项目根', () async {
      writeTasks('map = dart run w_tools_cli:map\n');
      final runner = FakeProcessRunner();
      expect(
        await RunCommand(root: project.path, runner: runner).run(['map']),
        0,
      );
      final call = runner.starts.single;
      expect(call.exe, Platform.isWindows ? 'cmd' : 'bash');
      expect(call.args.last, 'dart run w_tools_cli:map');
      expect(call.cwd, project.path);
    });

    test('--dry-run 只打印不执行', () async {
      writeTasks('map = echo hi\n');
      final runner = FakeProcessRunner();
      expect(
        await RunCommand(
          root: project.path,
          runner: runner,
        ).run(['map', '--dry-run']),
        0,
      );
      expect(runner.starts, isEmpty);
    });

    test('未知任务退出 2', () async {
      writeTasks('map = echo hi\n');
      expect(
        await RunCommand(
          root: project.path,
          runner: FakeProcessRunner(),
        ).run(['nope']),
        2,
      );
    });

    test('一次给两个任务退出 2', () async {
      writeTasks('a = echo a\nb = echo b\n');
      expect(
        await RunCommand(
          root: project.path,
          runner: FakeProcessRunner(),
        ).run(['a', 'b']),
        2,
      );
    });

    test('没有 .ww/tasks：无名字退 0，有名字退 1', () async {
      final runner = FakeProcessRunner();
      expect(await RunCommand(root: project.path, runner: runner).run([]), 0);
      expect(
        await RunCommand(root: project.path, runner: runner).run(['x']),
        1,
      );
    });

    test('任务退出码透传', () async {
      writeTasks('boom = exit 7\n');
      final runner = FakeProcessRunner(startExitCode: 7);
      expect(
        await RunCommand(root: project.path, runner: runner).run(['boom']),
        7,
      );
    });
  });
}
