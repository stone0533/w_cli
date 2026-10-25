import 'dart:async';
import 'dart:io';

/// 统一的 `build_runner build` 入口。
///
/// 以前三处各写一份（`common.sh drbb`、`models` 生成器、`setup.sh`），
/// 超时、工具选择、失败文案都不一样。这里收成一处：
///
/// - 优先 `dart`，没有就退回 `flutter`
/// - 统一 1800s 超时，超时返回 124（与 shell 的 `timeout` 约定一致）
/// - 输出直接继承父进程 stdout/stderr，长任务能看到进度
class BuildRunner {
  BuildRunner({this.root = '.', this.timeout = const Duration(minutes: 30)});

  final String root;
  final Duration timeout;

  /// 返回进程退出码：0 成功，124 超时，其它为 build_runner 自己的退出码。
  Future<int> run({bool deleteConflicting = true}) async {
    final tool = _available('dart') ? 'dart' : 'flutter';
    if (tool == 'flutter' && !_available('flutter')) {
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

    final Process process;
    try {
      process = await Process.start(
        tool,
        args,
        workingDirectory: root,
        runInShell: true,
        mode: ProcessStartMode.inheritStdio,
      );
    } on ProcessException catch (error) {
      stderr.writeln('无法启动 $tool: $error');
      return 1;
    }

    try {
      return await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      // 给子进程一点收尾时间，仍不退出就强杀
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
      stderr.writeln('build_runner 超时（${timeout.inMinutes} 分钟）');
      return 124;
    }
  }

  static bool _available(String name) {
    try {
      return Process.runSync('which', [name], runInShell: true).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
