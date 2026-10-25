import 'dart:async';
import 'dart:io';

import '../cli/output.dart';
import '../cli/capture.dart';
import '../cli/process.dart';

/// 统一的 `build_runner build` 入口。
///
/// 以前三处各写一份（`common.sh drbb`、`models` 生成器、`setup.sh`），
/// 超时、工具选择、失败文案都不一样。这里收成一处：
///
/// - 优先 `dart`，没有就退回 `flutter`
/// - 统一 1800s 超时，超时返回 124（与 shell 的 `timeout` 约定一致）
/// - 默认把 build_runner 的输出写进 `w_build/build-runner.log`，终端只留一行结果；
///   `-d` 时改为实时透传全部输出
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
      Cli.error('Dart 和 Flutter 命令都不可用，无法执行 build_runner');
      return 1;
    }

    final args = <String>[
      'run',
      'build_runner',
      'build',
      if (deleteConflicting) '--delete-conflicting-outputs',
    ];

    Cli.detail('执行 $tool ${args.join(' ')}（超时 ${timeout.inMinutes} 分钟）');

    try {
      if (Cli.verbose) {
        final code = await runner.start(
          tool,
          args,
          workingDirectory: root,
          timeout: timeout,
        );
        if (code == 124) {
          Cli.error('build_runner 超时（${timeout.inMinutes} 分钟）');
        }
        return code;
      }

      // 非 verbose：收集输出，落盘 + 只留一行结果
      final run = await runCaptured(
        runner,
        tool,
        args,
        root: root,
        logName: 'build-runner.log',
      );
      final code = run.code;

      if (code == 124) {
        Cli.error('build_runner 超时（${timeout.inMinutes} 分钟）');
        return 124;
      }
      if (code != 0) {
        Cli.error('build_runner 失败（退出码 $code），末尾输出：');
        captureTail(run.text);
        Cli.error('完整输出: ${captureLogPath(root, 'build-runner.log')}');
        return code;
      }

      final summary = captureLastLine(run.text);
      Cli.detail(summary.isEmpty ? 'build_runner 完成' : summary);
      return 0;
    } on ProcessException catch (error) {
      Cli.error('无法启动 $tool: $error');
      return 1;
    }
  }
}
