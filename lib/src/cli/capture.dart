import 'dart:io';

import 'output.dart';
import 'process.dart';

/// 一次被捕获的命令执行结果。
class CapturedRun {
  const CapturedRun({required this.code, required this.text});

  final int code;
  final String text;
}

/// 跑一条命令，把输出落盘，终端只留摘要。
///
/// 统一三处的重复逻辑（`BuildRunner`、`ProjectCommand`、`TaskRunner`）：
/// - `-d`：实时透传（长任务能看到进度）
/// - 默认：收集输出 → 追加写 `w_build/<logName>` → 成功返回文本供调用方提取摘要，
///   失败由调用方决定是否 `printTail`
///
/// 调用方负责在失败时调用 [captureTail]（只取末尾几行，避免刷屏）。
Future<CapturedRun> runCaptured(
  ProcessRunner runner,
  String executable,
  List<String> args, {
  String root = '.',
  required String logName,
}) async {
  if (Cli.verbose) {
    final code = await runner.start(executable, args, workingDirectory: root);
    return CapturedRun(code: code, text: '');
  }

  final result = await runner.run(executable, args, workingDirectory: root);
  final text = '${result.stdout}${result.stderr}';
  final file = File('$root/w_build/$logName');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text, mode: FileMode.append);
  return CapturedRun(code: result.exitCode, text: text);
}

/// 失败时打印末尾 [lines] 行（默认 10）
void captureTail(String text, {int lines = 10}) {
  final all = text.trimRight().split('\n');
  final start = all.length > lines ? all.length - lines : 0;
  for (final line in all.skip(start)) {
    Cli.error('    $line');
  }
}

/// 取最后一条非空行（很多工具把结论放在最后，如 build_runner）
String captureLastLine(String text) => text
    .split('\n')
    .lastWhere((line) => line.trim().isNotEmpty, orElse: () => '')
    .trim();

/// 日志文件路径（给调用方提示用）
String captureLogPath(String root, String logName) => '$root/w_build/$logName';
