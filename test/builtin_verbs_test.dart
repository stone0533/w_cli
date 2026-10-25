import 'dart:io';

import 'package:test/test.dart';
import 'package:w_cli/src/cli/help.dart';
import 'package:w_cli/src/commands/doctor_command.dart';
import 'package:w_cli/src/commands/task_commands.dart';

import 'fake_process_runner.dart';

void main() {
  group('内置动词的元数据', () {
    test('每个动词都有 help 文本', () {
      for (final task in builtinTasks) {
        expect(commandHelp(task.name), isNotNull, reason: task.name);
      }
    });

    test('名字唯一且不与其他命令冲突', () {
      final names = builtinTasks.map((task) => task.name).toList();
      expect(names.toSet().length, names.length);
      // 这几个名字被其他命令占用，内置动词不能重名
      expect(names, isNot(contains('run')));
      expect(names, isNot(contains('build')));
      expect(names, isNot(contains('clean')));
    });

    test('每个动词都要有可执行的 executable', () {
      for (final task in builtinTasks) {
        expect(task.executable, isNotEmpty, reason: task.name);
        expect(task.usage, contains('ww ${task.name}'), reason: task.name);
      }
    });
  });

  group('TaskRunner（新动词）', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('w_cli_verbs');
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    });

    tearDown(() => project.deleteSync(recursive: true));

    BuiltinTask task(String name) => builtinTask(name)!;

    test('add 透传包名', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(task('add'), extra: ['dio', 'retrofit']);
      expect(runner.starts.single.args.join(' '), 'pub add dio retrofit');
    });

    test('add --dev 改写成 dev: 前缀', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(
        root: project.path,
        runner: runner,
      ).run(task('add'), extra: ['build_runner'], flags: {'dev'});
      expect(runner.starts.single.args.join(' '), 'pub add dev:build_runner');
    });

    test('add 不给包名是用法错误', () async {
      final runner = FakeProcessRunner();
      expect(
        await TaskRunner(root: project.path, runner: runner).run(task('add')),
        2,
      );
      expect(runner.starts, isEmpty);
    });

    test('watch 不限时（长驻进程不会被 10 分钟杀掉）', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(root: project.path, runner: runner).run(task('watch'));
      expect(
        runner.starts.single.args.join(' '),
        'run build_runner watch --delete-conflicting-outputs',
      );
      expect(runner.lastTimeout, isNull);
    });

    test('fix 跑 dart fix --apply', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(root: project.path, runner: runner).run(task('fix'));
      expect(runner.starts.single.args.join(' '), 'fix --apply');
    });

    test('默认超时是 10 分钟', () async {
      final runner = FakeProcessRunner();
      await TaskRunner(root: project.path, runner: runner).run(task('analyze'));
      expect(runner.lastTimeout, const Duration(minutes: 10));
    });
  });

  group('DoctorCommand', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('w_cli_doctor');
    });

    tearDown(() => project.deleteSync(recursive: true));

    test('缺 pubspec.yaml 时退出 1', () async {
      final runner = FakeProcessRunner(available: {'flutter', 'dart'});
      expect(await DoctorCommand(root: project.path, runner: runner).run(), 1);
    });

    test('flutter 缺失时退出 1', () async {
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      final runner = FakeProcessRunner(available: {'dart'});
      expect(await DoctorCommand(root: project.path, runner: runner).run(), 1);
    });

    test('报告 iOS 签名来源：零配置（pbxproj 有 team）', () async {
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      Directory(
        '${project.path}/ios/Runner.xcodeproj',
      ).createSync(recursive: true);
      File(
        '${project.path}/ios/Runner.xcodeproj/project.pbxproj',
      ).writeAsStringSync('DEVELOPMENT_TEAM = ABC123DEF4;\n');

      final runner = FakeProcessRunner(available: {'flutter', 'dart'});
      expect(await DoctorCommand(root: project.path, runner: runner).run(), 0);
    });

    test('报告 iOS 签名来源：配置文件存在时优先', () async {
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      Directory('${project.path}/ios').createSync(recursive: true);
      File(
        '${project.path}/ios/ExportOptions.plist',
      ).writeAsStringSync('<plist/>\n');

      final runner = FakeProcessRunner(available: {'flutter', 'dart'});
      expect(await DoctorCommand(root: project.path, runner: runner).run(), 0);
    });

    test('核心项齐全时退出 0（pod / ios 可以缺）', () async {
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      final runner = FakeProcessRunner(available: {'flutter', 'dart'});
      expect(await DoctorCommand(root: project.path, runner: runner).run(), 0);
    });
  });
}
