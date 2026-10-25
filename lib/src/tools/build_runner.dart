import 'dart:async';
import 'dart:io';

import '../cli/process.dart';

/// 统一的 `build_runner build` 入口。
///
/// 以前三处各写一份（`common.sh drbb`、`models` 生成器、`setup.sh`），
/// 超时、工具选择、失败文案都不一样。这里收成一处：
///
/// - 优先 `dart`，没有就退回 `flutter`
/// - 统一 1800s 超时，超时返回 124（与 shell 的 `timeout` 约定一致）
/// - 输出直接继承父进程 stdout/stderr，长任务能看到进度
class BuildRunner {
  BuildRunner({
    this.root = '.',
    this.timeout = const Duration(minutes: 30),
    this.runner = const SystemProcessRunner(),
  });

  final String root;
  final Duration timeout;
  final ProcessRunner runner;

  /// 返回进程退出码：0 成功，124 超时，其它为 build_runner 自己的退出码。
  Future<int> run({bool deleteConflicting = true}) async {
    final tool = runner.which('dart') ? 'dart' : 'flutter';
    if (tool == 'flutter' && !runner.which('flutter')) {
      stderr.writeln('Dart 和 Flutter 命令都不可用，无法执行 build_runner');
      return 1;
    }

    final args = <String>[
      'run',
      'build_runner',
      'build',
      if (deleteConflicting) '--delete-conflicting-outputs',
    ];

    stdout.writeln('执行 $tool ${args.join(' ')}（超时 ${timeout.inMinutes} 分钟）');

    try {
      final code = await runner.start(
        tool,
        args,
        workingDirectory: root,
        timeout: timeout,
      );
      if (code == 124) {
        stderr.writeln('build_runner 超时（${timeout.inMinutes} 分钟）');
      }
      return code;
    } on ProcessException catch (error) {
      stderr.writeln('无法启动 $tool: $error');
      return 1;
    }
  }
}
