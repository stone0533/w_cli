import 'dart:io';

import '../cli/process.dart';

/// 内置的「短命令」：把常用但难记的长命令收成 `ww <动词>`。
///
/// 设计取舍：
/// - 只放**每个 Flutter 工程都会用到**、高频、且原命令够长的几条；
///   项目特有的命令走 `.ww/tasks` + `ww run`
/// - 每条都打印展开后的命令行（不做黑魔法）
/// - 退出码原样透传，和 `ww build` 一致
class BuiltinTask {
  const BuiltinTask({
    required this.name,
    required this.usage,
    required this.executable,
    required this.arguments,
    this.replaceLastArg = false,
    this.flagNames = const [],
    this.timeout = const Duration(minutes: 10),
    this.availableOnAllPlatforms = true,
    this.requiresDirectory,
    this.transform,
  });

  final String name;
  final String usage;
  final String executable;
  final List<String> arguments;

  /// 位置参数是否替换最后一个默认参数（`ww fmt lib` → `dart format lib`）。
  /// 为 false 时位置参数追加在末尾（`ww test test/foo.dart` → `flutter test test/foo.dart`）。
  final bool replaceLastArg;

  /// 该动词自己支持的 flag（`fmt --check`、`add --dev`）
  final List<String> flagNames;

  /// null 表示不限时（`ww watch` 这种长驻进程）
  final Duration? timeout;

  /// `pod` 只在 macOS/Linux 上有意义
  final bool availableOnAllPlatforms;

  /// 需要的目录（相对项目根）；不存在时直接给中文提示
  final String? requiresDirectory;

  /// 参数改写：`ww add --dev x` 要变成 `dev:x`
  final List<String> Function(List<String> positionals, Set<String> flags)?
  transform;

  String get commandLine => '$executable ${arguments.join(' ')}';
}

const List<BuiltinTask> builtinTasks = [
  BuiltinTask(
    name: 'fmt',
    usage: 'ww fmt [路径...] [--check]   # dart format（默认 .）',
    executable: 'dart',
    arguments: ['format', '.'],
    replaceLastArg: true,
    flagNames: ['check'],
  ),
  BuiltinTask(
    name: 'get',
    usage: 'ww get                       # flutter pub get',
    executable: 'flutter',
    arguments: ['pub', 'get'],
  ),
  BuiltinTask(
    name: 'add',
    usage: 'ww add <包>... [--dev]       # flutter pub add',
    executable: 'flutter',
    arguments: ['pub', 'add'],
    flagNames: ['dev'],
    transform: _addArgs,
  ),
  BuiltinTask(
    name: 'pod',
    usage: 'ww pod                       # pod install --project-directory=ios',
    executable: 'pod',
    arguments: ['install', '--project-directory=ios'],
    requiresDirectory: 'ios',
  ),
  BuiltinTask(
    name: 'analyze',
    usage: 'ww analyze [-- <flags>]      # flutter analyze',
    executable: 'flutter',
    arguments: ['analyze'],
  ),
  BuiltinTask(
    name: 'fix',
    usage: 'ww fix                       # dart fix --apply',
    executable: 'dart',
    arguments: ['fix', '--apply'],
  ),
  BuiltinTask(
    name: 'test',
    usage: 'ww test [目标...]            # flutter test',
    executable: 'flutter',
    arguments: ['test'],
  ),
  BuiltinTask(
    name: 'l10n',
    usage: 'ww l10n                      # flutter gen-l10n',
    executable: 'flutter',
    arguments: ['gen-l10n'],
  ),
  BuiltinTask(
    name: 'outdated',
    usage: 'ww outdated                  # flutter pub outdated',
    executable: 'flutter',
    arguments: ['pub', 'outdated'],
  ),
  BuiltinTask(
    name: 'gen',
    usage: 'ww gen [-- <flags>]          # 跑 build_runner（30 分钟超时）',
    executable: 'dart',
    arguments: ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    timeout: Duration(minutes: 30),
  ),
  BuiltinTask(
    name: 'watch',
    usage: 'ww watch                     # build_runner watch（长驻，Ctrl+C 退出）',
    executable: 'dart',
    arguments: ['run', 'build_runner', 'watch', '--delete-conflicting-outputs'],
    timeout: null,
  ),
];

/// `dart pub add dev:foo`（Dart 3.x 的语法；`--dev` 已从 pub 移除）
List<String> _addArgs(List<String> positionals, Set<String> flags) {
  if (!flags.contains('dev')) {
    return positionals;
  }
  return [
    for (final package in positionals)
      package.startsWith('dev:') ? package : 'dev:$package',
  ];
}

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

  /// 返回进程退出码（0 成功、1 工具不可用 / 缺依赖、2 用法错误，其余透传）。
  Future<int> run(
    BuiltinTask task, {
    List<String> extra = const [],
    Set<String> flags = const {},
    bool check = false,
  }) async {
    if (!task.availableOnAllPlatforms && Platform.isWindows) {
      stderr.writeln('ww ${task.name} 在 Windows 上不可用');
      return 1;
    }

    final positionals = extra.where((arg) => !arg.startsWith('-')).toList();
    final passThrough = extra.where((arg) => arg.startsWith('-')).toList();

    final required = task.requiresDirectory;
    if (required != null && !Directory('$root/$required').existsSync()) {
      stderr.writeln('当前项目没有 $required 目录，ww ${task.name} 不适用');
      return 1;
    }
    if (positionals.isEmpty && _requiresPackage(task)) {
      stderr.writeln('用法: ww ${task.name} <包名>...');
      return 2;
    }
    if (!runner.which(task.executable)) {
      stderr.writeln('找不到 ${task.executable}，无法执行 ww ${task.name}');
      stderr.writeln('  命令: ${task.commandLine}');
      return 1;
    }

    var args = _argsFor(task, positionals, passThrough, flags);
    if (check && task.name == 'fmt') {
      args = [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        ...args.skip(1),
      ];
    }

    stdout.writeln('\$ ${task.executable} ${args.join(' ')}');
    return runner.start(
      task.executable,
      args,
      workingDirectory: root,
      timeout: _timeoutFor(task),
    );
  }

  bool _requiresPackage(BuiltinTask task) => task.name == 'add';

  /// 位置参数替换默认目标（`ww fmt lib`），flag 追加在最后（需要写在 `--` 之后）
  List<String> _argsFor(
    BuiltinTask task,
    List<String> positionals,
    List<String> passThrough,
    Set<String> flags,
  ) {
    final args = [...task.arguments];
    if (positionals.isNotEmpty) {
      final target = task.transform?.call(positionals, flags) ?? positionals;
      if (task.replaceLastArg && args.isNotEmpty) {
        args.removeLast();
      }
      args.addAll(target);
    }
    args.addAll(passThrough);
    return args;
  }

  /// `WW_TASK_TIMEOUT`（秒）可覆盖默认超时；`0` 表示不限时
  Duration? _timeoutFor(BuiltinTask task) {
    final raw = Platform.environment['WW_TASK_TIMEOUT'];
    final override = int.tryParse(raw ?? '');
    if (override != null) {
      return override <= 0 ? null : Duration(seconds: override);
    }
    return task.timeout;
  }
}
