// 演示如何在自家脚本里复用 w_cli 的零件：统一的进程封装 + 输出约定。
//
// 运行：
//   dart run example/example.dart dart --version
//   dart run example/example.dart -d dart analyze      # -d 显示明细
import 'dart:io';

import 'package:w_cli/w_cli.dart';

Future<void> main(List<String> args) async {
  if (args.contains('-d') || args.contains('--debug')) {
    Cli.verbose = true;
    args = args.where((arg) => arg != '-d' && arg != '--debug').toList();
  }

  if (args.isEmpty) {
    Cli.error('用法: dart run example/example.dart [-d] <命令> [参数...]');
    exit(2);
  }

  final executable = args.first;
  final arguments = args.skip(1).toList();

  // 1. 统一的命令探测（内部是 `which`，失败不抛异常）
  const runner = SystemProcessRunner();
  if (!runner.which(executable)) {
    Cli.error('找不到命令: $executable');
    exit(1);
  }

  // 2. 统一的输出约定：绿色横幅 + 结束时刻，失败时红色
  Cli.begin('$executable ${arguments.join(' ')}'.trim());
  final result = await runner.run(executable, arguments);

  // 3. 输出收集起来，只有 -d 才显示（避免刷屏）
  final output = '${result.stdout}${result.stderr}'.trim();
  if (output.isNotEmpty) {
    Cli.detail(output);
  }

  if (result.exitCode == 0) {
    Cli.ok('$executable 执行成功');
  } else {
    Cli.error('$executable 退出码 ${result.exitCode}');
  }
  Cli.end(code: result.exitCode);
  exit(result.exitCode);
}
