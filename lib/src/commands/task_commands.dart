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
    this.acceptsTarget = false,
    this.timeout = const Duration(minutes: 10),
    this.availableOnAllPlatforms = true,
    this.requiresDirectory,
  });

  final String name;
  final String usage;
  final String executable;
  final List<String> arguments;

  /// 是否接受位置参数替换默认目标：`ww fmt lib/app` → `dart format lib/app`
  final bool acceptsTarget;
  final Duration timeout;

  /// `pod` 只在 macOS/Linux 上有意义
  final bool availableOnAllPlatforms;

  /// 需要的目录（相对项目根）；不存在时直接给中文提示
  final String? requiresDirectory;

  String get commandLine => '$executable ${arguments.join(' ')}';
}

const List<BuiltinTask> builtinTasks = [
  BuiltinTask(
    name: 'fmt',
    usage: 'ww fmt [路径...]   # dart format（默认 .）',
    executable: 'dart',
    arguments: ['format', '.'],
    acceptsTarget: true,
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
    requiresDirectory: 'ios',
  ),
  BuiltinTask(
    name: 'analyze',
    usage: 'ww analyze [-- <flags>]  # flutter analyze',
    executable: 'flutter',
    arguments: ['analyze'],
  ),
  BuiltinTask(
    name: 'gen',
    usage: 'ww gen [-- <flags>]      # 跑 build_runner',
    executable: 'dart',
    arguments: ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    timeout: Duration(minutes: 30),
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
  Future<int> run(BuiltinTask task, {List<String> extra = const []}) async {
    final required = task.requiresDirectory;
    if (required != null && !Directory('$root/$required').existsSync()) {
      stderr.writeln('当前项目没有 $required 目录，ww ${task.name} 不适用');
      return 1;
    }
    if (!runner.which(task.executable)) {
      stderr.writeln('找不到 ${task.executable}，无法执行 ww ${task.name}');
      stderr.writeln('  命令: ${task.commandLine}');
      return 1;
    }
    if (!task.availableOnAllPlatforms && Platform.isWindows) {
      stderr.writeln('ww ${task.name} 在 Windows 上不可用');
      return 1;
    }

    final args = _argsFor(task, extra);
    stdout.writeln('\$ ${task.executable} ${args.join(' ')}');
    return runner.start(
      task.executable,
      args,
      workingDirectory: root,
      timeout: _timeoutFor(task),
    );
  }

  /// 位置参数替换默认目标（`ww fmt lib`、`ww test test/foo_test.dart`），
  /// flag 形式的额外参数追加在最后（需要写在 `--` 之后）。
  List<String> _argsFor(BuiltinTask task, List<String> extra) {
    final positionals = extra.where((arg) => !arg.startsWith('-')).toList();
    final flags = extra.where((arg) => arg.startsWith('-')).toList();

    final args = [...task.arguments];
    if (positionals.isNotEmpty) {
      if (task.acceptsTarget && args.isNotEmpty) {
        args.removeLast();
      }
      args.addAll(positionals);
    }
    args.addAll(flags);
    return args;
  }

  /// `WW_TASK_TIMEOUT`（秒）可覆盖默认超时
  Duration _timeoutFor(BuiltinTask task) {
    final override = int.tryParse(
      Platform.environment['WW_TASK_TIMEOUT'] ?? '',
    );
    if (override != null && override > 0) {
      return Duration(seconds: override);
    }
    return task.timeout;
  }
}
