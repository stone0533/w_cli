import 'dart:io';

import '../cli/process.dart';

/// 内置的「短命令」：把常用但难记的长命令收成 `ww <动词>`。
///
/// 设计取舍：
/// - 只放**每个 Flutter 工程都会用到**的几条；项目特有的命令走 `.ww/tasks` + `ww run`
/// - 每条都打印展开后的命令行（不做黑魔法），`--debug` 只影响日志
/// - 退出码原样透传，和 `ww build` 一致
class BuiltinTask {
  const BuiltinTask({
    required this.name,
    required this.usage,
    required this.executable,
    required this.arguments,
    this.availableOnAllPlatforms = true,
  });

  final String name;
  final String usage;
  final String executable;
  final List<String> arguments;

  /// `pod` 只在 macOS/Linux 上有意义
  final bool availableOnAllPlatforms;

  String get commandLine => '$executable ${arguments.join(' ')}';
}

const List<BuiltinTask> builtinTasks = [
  BuiltinTask(
    name: 'fmt',
    usage: 'ww fmt          # dart format .',
    executable: 'dart',
    arguments: ['format', '.'],
  ),
  BuiltinTask(
    name: 'get',
    usage: 'ww get          # flutter pub get',
    executable: 'flutter',
    arguments: ['pub', 'get'],
  ),
  BuiltinTask(
    name: 'pod',
    usage: 'ww pod          # pod install --project-directory=ios',
    executable: 'pod',
    arguments: ['install', '--project-directory=ios'],
  ),
  BuiltinTask(
    name: 'analyze',
    usage: 'ww analyze      # flutter analyze',
    executable: 'flutter',
    arguments: ['analyze'],
  ),
];

BuiltinTask? builtinTask(String name) {
  for (final task in builtinTasks) {
    if (task.name == name) {
      return task;
    }
  }
  return null;
}

class TaskRunner {
  TaskRunner({this.root = '.', this.runner = const SystemProcessRunner()});

  final String root;
  final ProcessRunner runner;

  /// 返回进程退出码（0 成功、1 工具不可用、其余透传）。
  Future<int> run(BuiltinTask task) async {
    if (!runner.which(task.executable)) {
      stderr.writeln('找不到 ${task.executable}，无法执行 ww ${task.name}');
      stderr.writeln('  命令: ${task.commandLine}');
      return 1;
    }
    if (!task.availableOnAllPlatforms && Platform.isWindows) {
      stderr.writeln('ww ${task.name} 在 Windows 上不可用');
      return 1;
    }

    stdout.writeln('\$ ${task.commandLine}');
    return runner.start(
      task.executable,
      task.arguments,
      workingDirectory: root,
    );
  }
}
