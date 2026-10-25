import 'dart:io';

import '../cli/output.dart';

import '../cli/process.dart';

/// `.ww/tasks` 里的一条任务。
class RunTask {
  const RunTask(this.name, this.command);

  final String name;
  final String command;
}

/// 解析 `.ww/tasks`：一行一条 `名字 = 命令`，`#` 注释与空行忽略。
///
/// 纯函数，便于单测。规则：
/// - 只按**第一个** `=` 切分（命令里可以有 `=`，比如 `--define=FOO`）
/// - 名字只允许字母、数字、`_`、`-`
/// - 重名时保留第一条并报告，避免「后面的悄悄覆盖前面的」
({List<RunTask> tasks, List<String> warnings}) parseTasks(String content) {
  final tasks = <RunTask>[];
  final warnings = <String>[];
  final seen = <String>{};

  for (var i = 0; i < content.split('\n').length; i++) {
    final raw = content.split('\n')[i];
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final index = line.indexOf('=');
    if (index <= 0) {
      warnings.add('第 ${i + 1} 行缺少 `=`，已跳过: $line');
      continue;
    }

    final name = line.substring(0, index).trim();
    final command = line.substring(index + 1).trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(name)) {
      warnings.add('第 ${i + 1} 行任务名不合法，已跳过: $name');
      continue;
    }
    if (command.isEmpty) {
      warnings.add('第 ${i + 1} 行命令为空，已跳过: $name');
      continue;
    }
    if (!seen.add(name)) {
      warnings.add('任务名重复，保留第一条: $name');
      continue;
    }

    tasks.add(RunTask(name, command));
  }

  return (tasks: tasks, warnings: warnings);
}

/// `ww run`：执行 `.ww/tasks` 里声明的任务。
///
/// 为什么还要一个 `ww run`：
/// - 内置动词（`ww fmt`/`get`/`pod`/`analyze`）覆盖不了项目特有的命令
///   （`dart run w_tools_cli:map`、自定义脚本）
/// - `.ww/tasks` 可以提交到仓库，团队与 CI 共用同一套快捷键
class RunCommand {
  RunCommand({
    this.root = '.',
    this.runner = const SystemProcessRunner(),
    this.tasksPath = '.ww/tasks',
  });

  final String root;
  final ProcessRunner runner;
  final String tasksPath;

  Future<int> run(List<String> args) async {
    final file = File('$root/$tasksPath');
    final dryRun = args.contains('--dry-run');
    final names = args.where((arg) => !arg.startsWith('-')).toList();

    if (!file.existsSync()) {
      if (names.isEmpty) {
        printHelp();
        return 0;
      }
      Cli.error('未找到 $tasksPath（在项目根目录创建它，一行一条 `名字 = 命令`）');
      return 1;
    }

    final parsed = parseTasks(file.readAsStringSync());
    for (final warning in parsed.warnings) {
      Cli.error(warning);
    }

    if (names.isEmpty) {
      _list(parsed.tasks);
      return 0;
    }
    if (names.length > 1) {
      Cli.error('一次只能跑一个任务，收到: ${names.join(' ')}');
      return 2;
    }

    final name = names.single;
    final task = parsed.tasks.where((task) => task.name == name).firstOrNull;
    if (task == null) {
      Cli.error('未知任务: $name');
      _list(parsed.tasks);
      return 2;
    }

    if (dryRun) {
      Cli.info(task.command);
      return 0;
    }

    Cli.info('\$ ${task.command}');
    final (executable, arguments) = _shellFor(task.command);
    return runner.start(executable, arguments, workingDirectory: root);
  }

  /// 任务里常有 `&&`、`cd`、管道，必须过 shell
  (String, List<String>) _shellFor(String command) {
    if (Platform.isWindows) {
      return ('cmd', ['/c', command]);
    }
    return ('bash', ['-c', command]);
  }

  void _list(List<RunTask> tasks) {
    if (tasks.isEmpty) {
      Cli.info('$tasksPath 里还没有任务');
      return;
    }
    Cli.info('$tasksPath 里的任务：');
    final width = tasks
        .map((task) => task.name.length)
        .reduce((a, b) => a > b ? a : b);
    for (final task in tasks) {
      Cli.info('  ${task.name.padRight(width)}  ${task.command}');
    }
    Cli.info('');
    Cli.info('用法: ww run <任务名> [--dry-run]');
  }

  void printHelp() {
    print('''
用法: ww run [任务名] [--dry-run]

读取项目根的 $tasksPath（一行一条 `名字 = 命令`）：

  # .ww/tasks
  map = dart run w_tools_cli:map
  gen = dart run build_runner build --delete-conflicting-outputs

  ww run              列出所有任务
  ww run map          执行
  ww run map --dry-run  只打印命令，不执行

命令走 bash -c（Windows 是 cmd /c），所以 `&&`、`cd`、管道都能用。
退出码原样透传。''');
  }
}
