import 'dart:convert';
import 'dart:io';

import '../cli/output.dart';
import '../cli/script_runner.dart';
import '../version.dart';

/// 处理更新命令
Future<int> handleUpdateCommand() async {
  Cli.info('Updating w_cli...');
  try {
    // 升级到最新版本
    final process = await Process.start('dart', [
      'pub',
      'global',
      'activate',
      'w_cli',
    ]);

    // 实时显示标准输出
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          Cli.info(chunk.trimRight());
        });

    // 实时显示错误输出
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          Cli.error(chunk.trimRight());
        });

    // 等待进程完成并获取退出码
    final exitCode = await process.exitCode;
    await stdoutDone;
    await stderrDone;

    if (exitCode == 0) {
      Cli.ok('Update completed successfully');
      Cli.info('   Current version: $version');
      print(
        '   Note: You may need to restart your terminal for the changes to take effect.',
      );
    } else {
      Cli.error('Update failed with exit code: $exitCode');
      Cli.info('   Please try again or check your internet connection.');
    }
    return exitCode;
  } catch (e) {
    handleError(e, 'update');
    Cli.info('   Please try again or check your internet connection.');
    return 1;
  }
}
