import 'dart:async';
import 'dart:io';

/// 外部命令的统一入口。
///
/// 之前六个模块各写一份 `Process.runSync('which', …)` 和
/// `Process.start(..., mode: inheritStdio)`，而且命令类直接摸 `Process`，
/// 只能靠起子进程 + stub 做端到端测试。抽出这一层后：
///
/// - 生产代码用 [SystemProcessRunner]（默认值）
/// - 单测可以塞一个记录调用的假实现，断言「删了哪些文件、参数怎么拼、退出码怎么传」
abstract class ProcessRunner {
  /// 启动进程并等它结束；[inheritStdio] 为真时子进程直接接管终端的 stdin/stdout/stderr。
  ///
  /// 给了 [timeout] 时，超时会先 SIGTERM、5 秒后 SIGKILL，并返回 124
  /// （与 shell 的 `timeout` 约定一致）。
  Future<int> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = true,
    Duration? timeout,
  });

  /// 启动并收集输出。
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });

  /// 命令是否在 PATH 里。
  bool which(String name);
}

class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<int> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = true,
    Duration? timeout,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
      mode: inheritStdio
          ? ProcessStartMode.inheritStdio
          : ProcessStartMode.normal,
    );

    if (timeout == null) {
      return process.exitCode;
    }

    try {
      return await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
      return 124;
    }
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );
  }

  @override
  bool which(String name) {
    try {
      return Process.runSync('which', [name], runInShell: true).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
