import 'dart:io';

import 'package:w_cli/src/cli/process.dart';

/// 记录调用、按需返回退出码的假实现——命令类不再直接摸 `Process`，
/// 于是「删了哪些文件、拼了哪些参数、退出码怎么传」都能直接断言。
class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner({
    this.available = const {'flutter', 'dart', 'pod', 'open', 'xdg-open'},
    this.startExitCode = 0,
    this.runExitCode = 0,
    this.runStdout = '',
    this.onCreate,
  });

  final Set<String> available;
  final int startExitCode;
  final int runExitCode;
  final String runStdout;
  final void Function(String executable, List<String> arguments)? onCreate;

  final List<({String exe, List<String> args, String? cwd})> starts = [];
  final List<({String exe, List<String> args, String? cwd})> runs = [];
  final List<String> whichCalls = [];

  @override
  Future<int> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool inheritStdio = true,
    Duration? timeout,
  }) async {
    starts.add((exe: executable, args: arguments, cwd: workingDirectory));
    onCreate?.call(executable, arguments);
    return startExitCode;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    runs.add((exe: executable, args: arguments, cwd: workingDirectory));
    return ProcessResult(0, runExitCode, runStdout, '');
  }

  @override
  bool which(String name) {
    whichCalls.add(name);
    return available.contains(name);
  }
}
