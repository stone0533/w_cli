import 'dart:io';
import 'package:args/args.dart';
import 'package:w_cli/src/cli/help.dart' as cli_help;
import 'package:w_cli/src/commands/doctor_command.dart' as doctor;
import 'package:w_cli/src/commands/run_command.dart' as runcmd;
import 'package:w_cli/src/commands/task_commands.dart' as tasks;
import 'package:w_cli/w_cli.dart' as w;

/// 一个 `ww` 子命令的完整声明。
///
/// 以前「命令名 / 别名 / flag 声明 / dispatch」是四份手工清单，漂移过一次又一次：
/// `ww api -d`、`ww build --name=`、`ww clean --lock`、`ww common --debug`
/// 都是「脚本支持、ArgParser 没声明」。现在只有这一张表：
/// 注册（含别名）、flag/option 声明、参数映射、dispatch 全从这里生成。
class CommandSpec {
  const CommandSpec({
    required this.name,
    required this.usage,
    this.aliases = const [],
    this.flags = const [],
    this.options = const [],
    required this.run,
  });

  final String name;

  /// 顶层 help 里的一行说明（不含 `ww ` 前缀）
  final String usage;
  final List<String> aliases;
  final List<FlagSpec> flags;
  final List<OptionSpec> options;

  /// 参数映射 + 调 handler；返回值即进程退出码
  final Future<int> Function(ArgResults results) run;

  Iterable<String> get allNames => [name, ...aliases];
}

class FlagSpec {
  const FlagSpec(this.name, {this.abbr, this.negatable = false});

  final String name;
  final String? abbr;
  final bool negatable;

  void register(ArgParser parser) {
    parser.addFlag(name, abbr: abbr, negatable: negatable);
  }
}

class OptionSpec {
  const OptionSpec(this.name, {this.abbr});

  final String name;
  final String? abbr;

  void register(ArgParser parser) => parser.addOption(name, abbr: abbr);
}

/// 全部命令。加命令只改这里。
List<CommandSpec> commandSpecs() => [
  CommandSpec(
    name: 'create',
    aliases: const ['c'],
    usage: 'ww create|c [project|p] <name>   # 新建 Flutter 工程',
    flags: const [FlagSpec('force')],
    run: (results) =>
        w.handleCreateCommand(results.rest, force: _flag(results, 'force')),
  ),
  CommandSpec(
    name: 'api',
    aliases: const ['a'],
    usage: 'ww api|a [generate|init|models]  # API 代码 / 模型生成',
    flags: const [
      FlagSpec('force'),
      FlagSpec('debug', abbr: 'd'),
    ],
    run: (results) => w.handleApiCommand([
      ...results.rest,
      if (_flag(results, 'force')) '--force',
    ], debug: _flag(results, 'debug')),
  ),
  CommandSpec(
    name: 'build',
    aliases: const ['b'],
    usage: 'ww build|b [apk|aab|ios]...      # 打包（bash 脚本）',
    flags: const [
      FlagSpec('uat', abbr: 'u'),
      FlagSpec('fresh'),
      FlagSpec('automatic'),
      FlagSpec('manual'),
      FlagSpec('show-config'),
      FlagSpec('clean', abbr: 'c'),
      FlagSpec('open', abbr: 'o'),
      FlagSpec('debug', abbr: 'd'),
    ],
    options: const [
      OptionSpec('name'),
      OptionSpec('export-options'),
      OptionSpec('method'),
      OptionSpec('team'),
      OptionSpec('bundle-id'),
      OptionSpec('cert'),
      OptionSpec('profile'),
    ],
    run: (results) {
      if (_flag(results, 'clean') && !_flag(results, 'fresh')) {
        stderr.writeln('提示：`--clean` 已更名为 `--fresh`（清输出目录），旧名将在下个版本移除');
      }
      return w.handleBuildCommand([
        ...results.rest.where(
          (arg) => arg == 'apk' || arg == 'aab' || arg == 'ios',
        ),
        if (_flag(results, 'uat')) '--uat',
        if (_flag(results, 'fresh')) '--clean',
        if (_flag(results, 'clean')) '--clean',
        if (_flag(results, 'open')) '--open',
        if (_flag(results, 'debug')) '--debug',
        if (results['name'] != null) '--name=${results['name']}',
        if (results['export-options'] != null)
          '--export-options=${results['export-options']}',
        if (results['method'] != null) '--method=${results['method']}',
        if (results['team'] != null) '--team=${results['team']}',
        if (results['bundle-id'] != null) '--bundle-id=${results['bundle-id']}',
        if (results['cert'] != null) '--cert=${results['cert']}',
        if (results['profile'] != null) '--profile=${results['profile']}',
        if (_flag(results, 'show-config')) '--show-config',
        if (_flag(results, 'automatic')) '--automatic',
        if (_flag(results, 'manual')) '--manual',
      ]);
    },
  ),
  CommandSpec(
    name: 'clean',
    aliases: const ['cl'],
    usage: 'ww clean|cl [android|ios|all]    # 清理构建产物',
    flags: const [
      FlagSpec('lock'),
      FlagSpec('pod'),
      FlagSpec('debug', abbr: 'd'),
    ],
    run: (results) => w.handleCleanCommand([
      ...results.rest,
      if (_flag(results, 'lock')) '--lock',
      if (_flag(results, 'pod')) '--pod',
      if (_flag(results, 'debug')) '--debug',
    ]),
  ),
  CommandSpec(
    name: 'open',
    aliases: const ['o'],
    usage: 'ww open|o [ios|android|build|root] # 打开 IDE / 目录',
    run: (results) => w.handleOpenCommand(results.rest),
  ),
  CommandSpec(
    name: 'project',
    aliases: const ['p'],
    usage: 'ww project|p --update             # 升级依赖与 Gradle',
    flags: const [FlagSpec('update')],
    run: (results) => w.handleProjectCommand([
      ...results.rest,
      if (_flag(results, 'update')) '--update',
    ]),
  ),
  CommandSpec(
    name: 'self-update',
    aliases: const ['su'],
    usage: 'ww self-update|su                # 升级 w_cli 自身',
    run: (results) => w.handleUpdateCommand(),
  ),
  CommandSpec(
    name: 'update',
    aliases: const ['u'],
    usage: 'ww update|u                       # 同上（旧名，请改用 self-update）',
    run: (results) => _deprecated(
      'update',
      '自升级',
      'ww self-update',
      () => w.handleUpdateCommand(),
    ),
  ),
  CommandSpec(
    name: 'deps',
    usage: 'ww deps upgrade                   # 升级项目依赖与 Gradle',
    run: (results) => _deps(results),
  ),
  // 内置短命令：把常用长命令收成 ww <动词>
  for (final task in tasks.builtinTasks)
    CommandSpec(
      name: task.name,
      usage: task.usage,
      flags: [for (final flag in task.flagNames) FlagSpec(flag)],
      run: (results) => tasks.TaskRunner().run(
        task,
        extra: results.rest,
        flags: {
          for (final flag in task.flagNames)
            if (_flag(results, flag)) flag,
        },
        check: _flag(results, 'check'),
      ),
    ),
  CommandSpec(
    name: 'doctor',
    usage:
        'ww doctor                       # 检查环境（flutter / dart / pod / 工程文件）',
    run: (results) => doctor.DoctorCommand().run(),
  ),
  CommandSpec(
    name: 'run',
    usage: 'ww run [任务名]                   # 执行 .ww/tasks 里的任务',
    flags: const [FlagSpec('dry-run')],
    run: (results) => runcmd.RunCommand().run([
      ...results.rest,
      if (_flag(results, 'dry-run')) '--dry-run',
    ]),
  ),
];

Future<int> _deps(ArgResults results) async {
  if (results.rest.isEmpty) {
    final help = cli_help.commandHelp('deps');
    if (help != null) {
      print(help);
    }
    return 0;
  }
  if (results.rest.first != 'upgrade') {
    stderr.writeln('未知子命令: ${results.rest.first}');
    stderr.writeln('用法: ww deps upgrade');
    return 2;
  }
  return w.handleProjectCommand(['--update']);
}

/// 旧命令名：跑完提醒一次新写法。
Future<int> _deprecated(
  String oldName,
  String what,
  String replacement,
  Future<int> Function() run,
) async {
  stderr.writeln('提示：`ww $oldName` 已更名为 `$replacement`（$what），旧名将在下个版本移除');
  return run();
}

/// 读取已声明的 flag；未声明时返回 false（而不是让 args 包抛 ArgumentError）
bool _flag(ArgResults results, String name) =>
    results.options.contains(name) && results[name] == true;
