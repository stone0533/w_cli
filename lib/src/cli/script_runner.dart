/// 脚本执行：把 `lib/sh/*.sh` 解压到临时目录、用 bash 跑、实时转发输出。
///
/// 目前只剩 `ww build` 走这里；其余命令都是 Dart 实现。
library;

import 'dart:convert';
import 'dart:io';

import '../resources.dart';
import '../version.dart';

/// 获取脚本文件的路径
/// 从嵌入的资源文件中提取到临时目录
/// [scriptName] - 脚本文件名称
/// 返回脚本文件的临时路径
Future<String> getScriptPath(String scriptName) async {
  try {
    // 从资源文件中提取到临时文件
    final resourcePath = 'lib/sh/$scriptName';
    final tempPath = await Resources.extractResourceToTempFile(
      resourcePath,
      scriptName,
    );
    return tempPath;
  } catch (e) {
    throw FileSystemException('Failed to extract script: $e');
  }
}

/// 找不到 bash 时的提示（纯函数，方便测试）。
///
/// 非 Windows 上 bash 本来就该有，属于环境损坏，只给一句短的；
/// Windows 上脚本命令需要 Git Bash 或 WSL，要说清楚。
String? bashMissingHint(String scriptName, {required bool isWindows}) {
  if (!isWindows) {
    return '找不到 bash，无法执行 $scriptName（macOS/Linux 自带 bash，请检查 PATH）';
  }
  return 'Windows 上执行 $scriptName 需要 bash：请安装 Git Bash 或使用 WSL，'
      '或改用不依赖脚本的命令（如 ww api）。';
}

/// 执行脚本文件并实时显示输出
/// [scriptName] - 脚本文件名称
/// [arguments] - 传递给脚本的参数
/// [successMessage] - 执行成功时显示的消息
/// [failureMessage] - 执行失败时显示的消息
/// 返回脚本的退出码（0 表示成功），由调用方决定是否向上传递
Future<int> executeScript(
  String scriptName,
  List<String> arguments,
  String successMessage,
  String failureMessage,
) async {
  try {
    // 获取脚本路径（从资源文件提取）
    final scriptPath = await getScriptPath(scriptName);
    // print(
    //   'Executing script: $scriptPath with arguments: ${arguments.join(' ')}',
    // );

    Process process;
    // 把包版本注入脚本环境，脚本的 --version 因此不再各自维护一份版本号
    final env = {...Platform.environment, 'WW_VERSION': version};
    try {
      // 所有脚本都是 bash 脚本：Windows 上同样走 bash（Git Bash / WSL），
      // 没有 bash 时会在下面的 ProcessException 分支里给出明确提示
      process = await Process.start('bash', [
        scriptPath,
        ...arguments,
      ], environment: env);
    } on ProcessException {
      final hint = bashMissingHint(scriptName, isWindows: Platform.isWindows);
      if (hint != null) {
        print(hint);
      }
      return 1;
    }

    // 实时显示标准输出
    // 用 Utf8Decoder 做流式解码：多字节字符（中文）跨 chunk 边界时不会被截断
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          final output = chunk.trimRight();
          if (output.isNotEmpty) {
            print(output);
          }
        });

    // 实时显示错误输出
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          final output = chunk.trimRight();
          if (output.isNotEmpty) {
            print('Error: $output');
          }
        });

    // 等待进程完成并获取退出码
    final exitCode = await process.exitCode;
    // 等输出流排空，避免末尾提示与脚本输出交错
    await stdoutDone;
    await stderrDone;

    if (exitCode == 0) {
      if (successMessage.isNotEmpty) {
        print('\n✅ $successMessage');
      }
    } else {
      print('\n❌ $failureMessage with exit code: $exitCode');
    }
    return exitCode;
  } catch (e) {
    print('\n❌ Error executing script: $e');
    return 1;
  }
}

/// 处理错误信息，提供更详细的错误日志
/// [error] - 错误对象
/// [context] - 错误上下文
void handleError(dynamic error, String context) {
  print('\n❌ Error in $context: $error');

  if (error is FileSystemException) {
    print('   File system error: ${error.path}');
    if (error.message.isNotEmpty) {
      print('   Message: ${error.message}');
    }
    print('   Suggestion:');
    print('   - Check if the file or directory exists');
    print('   - Verify you have permission to access it');
    print('   - Ensure the path is correct');
  } else if (error is ProcessException) {
    print('   Process error: ${error.executable} ${error.arguments.join(' ')}');
    print('   Message: ${error.message}');
    print('   Suggestion:');
    print('   - Check if the command is installed');
    print('   - Verify the command is accessible in your PATH');
    print('   - Ensure you have permission to execute the command');
  } else if (error is FormatException) {
    print('   Format error: ${error.message}');
    if (error.source != null) {
      print('   Source: ${error.source}');
    }
    print('   Suggestion:');
    print('   - Check the input format');
    print('   - Ensure all required arguments are provided');
    print('   - Refer to the help documentation for correct usage');
  } else if (error is ArgumentError) {
    print('   Argument error: ${error.name}');
    print('   Suggestion:');
    print('   - Check the command arguments');
    print('   - Ensure all required arguments are provided');
    print('   - Use --help to see the correct usage');
  } else {
    print('   Unknown error type: ${error.runtimeType}');
    print('   Suggestion:');
    print('   - Try again with different parameters');
    print('   - Check your internet connection if applicable');
    print('   - Contact the maintainer if the issue persists');
  }

  print('   Stack trace:');
  print(StackTrace.current);
}
